#!/usr/bin/env bash
# Confere a fronteira entre as duas fases (veja system.yml / user.yml):
#
#   playbooks/user/    nunca vira root nem instala software (Flatpak de
#                      sistema, snap, Homebrew — o prefixo do Homebrew é do
#                      administrador), para que um usuário fora do wheel
#                      consiga rodá-lo
#   playbooks/system/  nunca fala com uma sessão de usuário (systemctl
#                      --user, gsettings/dconf), que a execução de um
#                      administrador só alcança para a própria conta
#
# Comentários são ignorados.
#
# Uso: scripts/check-phases.sh
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

status=0
report() {
    local rule=$1
    shift
    if [[ -n $* ]]; then
        echo "$rule:"
        printf '  %s\n' "$@"
        status=1
    fi
}

code() {
    # arquivo:linha:texto das linhas que não são comentário e casam $1 em $2...
    local pattern=$1
    shift
    grep -nHE "$pattern" "$@" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'
}

mapfile -t hits < <(code 'become: *(true|yes)' playbooks/user/*.yml)
report "playbooks/user/ não pode virar root" "${hits[@]}"

mapfile -t hits < <(code 'community\.general\.(homebrew|snap|flatpak)\b|brew install|snap install' playbooks/user/*.yml)
report "playbooks/user/ não pode instalar software" "${hits[@]}"

mapfile -t hits < <(code 'systemctl +--user|scope: *user|gsettings|\bdconf\b' playbooks/system/*.yml)
report "playbooks/system/ não pode falar com uma sessão de usuário" "${hits[@]}"

if (( status == 0 )); then
    echo "Fronteiras entre as fases OK."
fi
exit "$status"
