#!/usr/bin/env bash
# Contém as enxurradas de gdm-session-worker que deixam a tela de bloqueio do
# GNOME sem o prompt de senha. Cada worker de reautenticação é root e segura
# uma conexão no barramento de sistema; acumulados, esgotam o limite do
# dbus-daemon para o UID 0 (max_connections_per_user=256) e os workers novos,
# os que deveriam mostrar o prompt, não conseguem mais falar com o
# accountsservice (LimitsExceeded no journal).
#
# Nunca mata o líder de uma sessão: ele tem o mesmo nome dos outros workers e
# está no mesmo cgroup (session-N.scope), mas levaria a sessão junto. Os
# líderes vêm de /run/systemd/sessions, não do loginctl: com o barramento
# esgotado, o loginctl falharia justamente quando este serviço é necessário.
# Sem nenhum líder conhecido, não mata nada.
#
# Dos demais, fica o mais novo de cada serviço PAM em cada sessão, o que o
# prompt deve estar usando. A partir de saturation não fica nenhum e não se
# espera outra leitura: cada worker usa cerca de 2 conexões, então o limite
# chega em uns 115 workers, a rajada anda a uns 20 por segundo e os mais novos
# logo nascem sem barramento, sem servir para mostrar o prompt.
#
# Para depurar depois: o journal da unidade traz a subida da contagem e cada
# ação; cada enxurrada grava, ANTES de matar, um diretório em log_dir:
#   summary.txt   decisão, versões, nascimentos por minuto e por serviço
#   workers.tsv   cada worker: destino, idade, sessão, fds, wchan, cgroup
#   processes.txt árvore de processos do GDM, do shell e vizinhos
#   sessions.txt  estado do logind; bloqueio e ociosidade vêm pelo barramento
#                 (falha se esgotado)
#   dbus.txt      conexões no barramento de sistema (falha se esgotado)
#   journal.txt   journal recente de gdm, shell, dbus, logind, fprintd...
#   after.txt     after_delay segundos depois: quantos voltaram e o journal
# O diretório é só de root: o journal do GDM registra o tamanho da senha.
set -uo pipefail

max_surplus=${GDM_WORKER_WATCHDOG_MAX_SURPLUS:-16}
saturation=${GDM_WORKER_WATCHDOG_SATURATION:-60}
interval=${GDM_WORKER_WATCHDOG_INTERVAL:-2}
term_grace=${GDM_WORKER_WATCHDOG_TERM_GRACE:-3}
dry_run=${GDM_WORKER_WATCHDOG_DRY_RUN:-0}
sessions_dir=${GDM_WORKER_WATCHDOG_SESSIONS_DIR:-/run/systemd/sessions}
watch_above=${GDM_WORKER_WATCHDOG_WATCH_ABOVE:-6}
log_dir=${GDM_WORKER_WATCHDOG_LOG_DIR:-${LOGS_DIRECTORY:-/var/log/gdm-worker-watchdog}}
snapshot_keep=${GDM_WORKER_WATCHDOG_SNAPSHOT_KEEP:-30}
snapshot_every=${GDM_WORKER_WATCHDOG_SNAPSHOT_EVERY:-300}
journal_minutes=${GDM_WORKER_WATCHDOG_JOURNAL_MINUTES:-30}
after_delay=${GDM_WORKER_WATCHDOG_AFTER_DELAY:-30}

boot_time=$(awk '/^btime/ {print $2}' /proc/stat)
clock_ticks=$(getconf CLK_TCK)
journal_matches=(_COMM=gdm-session-wor + _COMM=gdm + _COMM=gnome-shell + _COMM=dbus-daemon
    + _COMM=systemd-logind + _COMM=accounts-daemon + _COMM=fprintd)

# O comm vem entre parênteses e pode ter espaços: os campos contam depois
# dele. O starttime é o 22º campo de /proc/PID/stat.
stat_fields() {
    local stat
    stat=$(<"/proc/$1/stat") || return 1
    read -ra fields <<<"${stat##*) }"
}

start_time() {
    local -a fields
    stat_fields "$1" || return 1
    echo "${fields[19]}"
}

list_workers() {
    pgrep -u 0 -f '^gdm-(session|password)-worker'
}

# Os PIDs que não podem morrer, um por chave de `protected`.
declare -A protected
load_leaders() {
    local file line
    protected=()
    for file in "$sessions_dir"/*; do
        [[ -f $file && $file != *.ref ]] || continue
        while IFS= read -r line; do
            [[ $line == LEADER=* ]] && protected[${line#LEADER=}]=1
        done <"$file"
    done
    ((${#protected[@]} > 0))
}

# Uma linha por worker dispensável: "starttime PID sessão comando", do mais
# novo para o mais velho.
surplus_workers() {
    local pid start session command
    for pid in "$@"; do
        [[ -z ${protected[$pid]:-} ]] || continue
        pgrep -P "$pid" -f '^(/usr/libexec/)?gdm-(wayland|x)-session' >/dev/null && continue
        start=$(start_time "$pid" 2>/dev/null) || continue
        session=$(<"/proc/$pid/sessionid") 2>/dev/null || continue
        command=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null) || continue
        echo "$start $pid $session $command"
    done | sort -rn
}

terminate() {
    local entry pid start
    local -a victims=("$@")
    for entry in "${victims[@]}"; do
        kill -TERM "${entry#* }" 2>/dev/null
    done
    sleep "$term_grace"
    for entry in "${victims[@]}"; do
        start=${entry%% *} pid=${entry#* }
        # O PID ainda é do mesmo processo, não de um que o reaproveitou.
        if [[ $(start_time "$pid" 2>/dev/null) == "$start" ]]; then
            echo "PID $pid ignorou o SIGTERM; enviando SIGKILL"
            kill -KILL "$pid" 2>/dev/null
        fi
    done
}

# Uma linha por worker. fds e wchan pedem CAP_SYS_PTRACE (veja a unidade).
write_worker_table() {
    local pid born session loginuid fds wchan cgroup command
    local -a fields fd_list
    printf 'pid\tdestino\tppid\testado\tthreads\tnascido\tidade_s\tsessão\tloginuid\tfds\twchan\tcgroup\tcomando\n'
    for pid in "$@"; do
        stat_fields "$pid" 2>/dev/null || continue
        born=$((boot_time + fields[19] / clock_ticks))
        session=$(<"/proc/$pid/sessionid") 2>/dev/null
        loginuid=$(<"/proc/$pid/loginuid") 2>/dev/null
        wchan=$(<"/proc/$pid/wchan") 2>/dev/null
        cgroup=$(<"/proc/$pid/cgroup") 2>/dev/null
        command=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)
        fds='?'
        if [[ -r /proc/$pid/fd ]]; then
            fd_list=("/proc/$pid/fd"/*)
            fds=${#fd_list[@]}
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%(%F %T)T\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$pid" "${fate[$pid]:--}" "${fields[1]}" "${fields[0]}" "${fields[17]}" "$born" \
            "$((EPOCHSECONDS - born))" "$session" "$loginuid" "$fds" "$wchan" "${cgroup#0::}" "$command"
    done
}

# Nascimentos por minuto dizem se foi rajada ou acúmulo lento; por serviço,
# qual conversa do prompt se repete.
write_summary() {
    local table=$1
    echo "Quando: $(date --iso-8601=seconds)"
    echo "Decisão: ${#workers[@]} workers, ${#surplus[@]} dispensáveis, ${#victims[@]} a matar, ${#kept[@]} mantidos, simulação=$dry_run"
    echo "Limites: max_surplus=$max_surplus saturation=$saturation interval=$interval"
    echo "Enxurradas desde o início do serviço: $event_count"
    echo "Sessões protegidas (líderes): ${!protected[*]}"
    echo "Kernel: $(uname -r)"
    echo "Versões: $(gdm --version 2>&1) / $(gnome-shell --version 2>&1)"
    echo
    echo "Nascimentos por minuto:"
    awk -F'\t' 'NR > 1 {print substr($6, 1, 16)}' "$table" | sort | uniq -c
    echo
    echo "Workers por comando:"
    awk -F'\t' 'NR > 1 {print $13}' "$table" | sort | uniq -c | sort -rn
    echo
    echo "Workers por wchan:"
    awk -F'\t' 'NR > 1 {print $11}' "$table" | sort | uniq -c | sort -rn
}

recent_journal() {
    timeout 30 journalctl --no-pager -o short-iso-precise -n 20000 --since "$1" "${journal_matches[@]}" 2>&1
}

write_snapshot() {
    local dir=$1 file
    mkdir -p "$dir" || return 1
    write_worker_table "${workers[@]}" >"$dir/workers.tsv" 2>&1
    write_summary "$dir/workers.tsv" >"$dir/summary.txt" 2>&1
    timeout 15 ps -eo pid,ppid,user,etimes,stat,wchan:24,args --forest 2>&1 |
        grep -E '^ *PID|gdm|gnome-shell|gnome-session|accounts-daemon|fprintd|dbus' >"$dir/processes.txt"
    for file in "$sessions_dir"/*; do
        [[ -f $file && $file != *.ref ]] || continue
        echo "--- $file"
        cat "$file"
        timeout 5 loginctl show-session "${file##*/}" -p LockedHint -p IdleHint -p IdleSinceHint
    done >"$dir/sessions.txt" 2>&1
    {
        echo "Conexões de root contam contra max_connections_per_user. Se falhar abaixo, o barramento está esgotado:"
        timeout 10 busctl --system --no-pager --unique list 2>&1
    } >"$dir/dbus.txt"
    recent_journal "-$journal_minutes min" >"$dir/journal.txt"
}

write_after() {
    local -a now
    mapfile -t now < <(list_workers)
    {
        echo "${after_delay}s depois: ${#now[@]} workers"
        echo
        write_worker_table "${now[@]}"
        echo
        recent_journal "@$pending_since"
    } >"$pending_dir/after.txt" 2>&1
    echo "${after_delay}s depois da enxurrada: ${#now[@]} workers ($pending_dir/after.txt)"
}

prune_snapshots() {
    local -a old
    mapfile -t old < <(ls -1dt "$log_dir"/20* 2>/dev/null | tail -n +"$((snapshot_keep + 1))")
    ((${#old[@]} == 0)) || rm -rf -- "${old[@]}"
}

over=0
event_count=0
last_snapshot=0
last_count=0
pending_dir=
pending_since=0
while true; do
    sleep "$interval"

    if [[ -n $pending_dir ]] && ((EPOCHSECONDS - pending_since >= after_delay)); then
        write_after
        pending_dir=
    fi

    mapfile -t workers < <(list_workers)

    # A subida antes do limite também importa: mostra o ritmo do acúmulo.
    if ((${#workers[@]} != last_count && (${#workers[@]} > watch_above || last_count > watch_above))); then
        echo "Workers: $last_count -> ${#workers[@]}"
    fi
    last_count=${#workers[@]}

    if ((${#workers[@]} <= max_surplus)); then
        over=0
        continue
    fi
    if ! load_leaders; then
        echo "${#workers[@]} workers, mas nenhum líder de sessão em $sessions_dir; nada será morto"
        continue
    fi

    mapfile -t surplus < <(surplus_workers "${workers[@]}")
    if ((${#surplus[@]} <= max_surplus)); then
        over=0
        continue
    fi
    # Um pico de uma só leitura não é enxurrada, a não ser que já seja grande.
    if ((${#surplus[@]} < saturation && ++over < 2)); then
        continue
    fi
    over=0
    ((++event_count))

    declare -A kept=() fate=()
    victims=()
    for line in "${surplus[@]}"; do
        read -r start pid session command <<<"$line"
        if ((${#surplus[@]} < saturation)) && [[ -z ${kept["$session $command"]:-} ]]; then
            kept["$session $command"]=$pid
            fate[$pid]=mantido
        else
            victims+=("$start $pid")
            fate[$pid]=morto
        fi
    done
    for pid in "${workers[@]}"; do
        [[ -n ${fate[$pid]:-} ]] && continue
        if [[ -n ${protected[$pid]:-} ]]; then fate[$pid]=líder; else fate[$pid]=dono-de-sessão; fi
    done

    echo "Enxurrada nº $event_count: ${#workers[@]} workers, ${#surplus[@]} fora dos líderes de sessão; matando ${#victims[@]}, mantendo ${#kept[@]}"

    # Uma enxurrada que volta a cada poucos segundos não pode encher o disco
    # nem atrasar a contenção: o journal registra todas, o diretório não.
    if ((EPOCHSECONDS - last_snapshot >= snapshot_every)); then
        printf -v event_dir '%s/%(%Y%m%d-%H%M%S)T' "$log_dir" "$EPOCHSECONDS"
        if write_snapshot "$event_dir"; then
            echo "Detalhes em $event_dir"
            last_snapshot=$EPOCHSECONDS
            pending_dir=$event_dir
            pending_since=$EPOCHSECONDS
            prune_snapshots
        else
            echo "Não consegui gravar em $event_dir; contendo mesmo assim"
        fi
    fi

    if ((dry_run)); then
        echo "Simulação; seriam mortos os PIDs: ${victims[*]#* }"
        continue
    fi
    terminate "${victims[@]}"
done
