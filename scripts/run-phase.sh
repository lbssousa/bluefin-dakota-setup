#!/usr/bin/env bash
# Roda um playbook numa das duas fases, com as configurações de quem chama.
#
#   system  suas tasks precisam de root: recusado se você não for
#           administrador (wheel); roda sob run-empowered.sh (uma
#           autenticação polkit no início).
#   user    roda como você, nunca sob run0: recusado como root ou dentro de
#           um processo empowered. A maioria das plays precisa da sua
#           sessão gráfica.
#
# As duas carregam users/$USER.yml (suas configurações, se o arquivo
# existir), ~/.config/bluefin-dakota-setup/local.yml (dados locais da
# máquina, se houver) e a seleção de features resolvida (scripts/features.py)
# como extra vars, e rodam as tags das features escolhidas, a menos que os
# argumentos tragam as suas.
#
# Uso: scripts/run-phase.sh system|user <playbook> [args do ansible-playbook]
set -euo pipefail

phase=${1:-}
playbook=${2:-}
[[ $phase == system || $phase == user ]] && [[ -n $playbook ]] || {
    sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "$0"
    exit 2
}
shift 2

cd "$(dirname "$(readlink -f "$0")")/.."

extra=()
[[ -f users/$USER.yml ]] && extra+=(-e "@users/$USER.yml")
local_vars=${XDG_CONFIG_HOME:-$HOME/.config}/bluefin-dakota-setup/local.yml
[[ -f $local_vars ]] && extra+=(-e "@$local_vars")

# A seleção de features (features.yml + as escolhas de `just configure`),
# como extra vars, e as --tags que a acompanham — a menos que quem chama
# tenha escolhido as próprias tags (ex.: `just users`).
selection=${XDG_CACHE_HOME:-$HOME/.cache}/bluefin-dakota-setup/selection-$phase.json
tags=$(scripts/python scripts/features.py resolve "$phase" "$selection")
extra+=(-e "@$selection")
caller_tags=false
for arg in "$@"; do
    [[ $arg == --tags || $arg == --tags=* || $arg == -t ]] && caller_tags=true
done
$caller_tags || extra+=(--tags "$tags")

case $phase in
    system)
        if ! id -nG | tr ' ' '\n' | grep -qx wheel; then
            echo "A fase de sistema é para administradores (wheel). Peça a um que rode \`just system\`; a sua parte é \`just user\`." >&2
            exit 1
        fi
        exec ./run-empowered.sh ansible-playbook "$playbook" "${extra[@]}" "$@"
        ;;
    user)
        if (( EUID == 0 )) || id -nG | tr ' ' '\n' | grep -qx empower; then
            echo "Rode a fase de usuário como você mesmo (\`just user\`), não como root nem sob run-empowered.sh." >&2
            exit 1
        fi
        exec ansible-playbook "$playbook" "${extra[@]}" "$@"
        ;;
esac
