set shell := ["bash", "-uc"]

# Duas fases (veja system.yml e user.yml), as duas por
# scripts/run-phase.sh: a de sistema sob `run0 --empower` (veja
# run-empowered.sh: uma autenticação polkit no início, e o run0 de cada task
# `become: true` passa sem perguntar de novo), só para administradores; a de
# usuário como ansible-playbook comum, para cada pessoa na própria sessão.
# As duas aplicam as features escolhidas com `just configure` (catálogo:
# features.yml, docs/features.md).

brew := "/home/linuxbrew/.linuxbrew/bin/brew"

default:
    @just --list

# Instala o ansible pelo Homebrew se ele não estiver no PATH.
_ensure-ansible:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v ansible-playbook >/dev/null; then
        echo "ansible-playbook não encontrado; instalando pelo Homebrew..."
        {{ brew }} install ansible
    fi

# Instala as collections que os playbooks usam (community.general).
_ensure-collections: _ensure-ansible
    ansible-galaxy collection install -r requirements.yml

# O gum desenha o menu de `just configure`.
_ensure-gum:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v gum >/dev/null; then
        echo "gum não encontrado; instalando pelo Homebrew..."
        {{ brew }} install gum
    fi

# Escolher as features a aplicar (menu do gum); grava em
# ~/.config/bluefin-dakota-setup/features.yml e oferece aplicar em seguida.
configure: _ensure-gum _ensure-collections
    scripts/configure.sh

# Só os atalhos no estilo Omarchy, um a um (liga a feature
# omarchy-keybindings); oferece aplicá-los em seguida.
configure-keybindings: _ensure-gum _ensure-collections
    scripts/configure.sh keybindings

# Tudo para a sua conta: a fase de sistema (precisa de um administrador;
# autentique uma vez, no diálogo do polkit que aparece no início) e depois a
# sua fase de usuário. Pergunta as suas escolhas antes, se você nunca fez.
setup: _ensure-collections
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -f ${XDG_CONFIG_HOME:-$HOME/.config}/bluefin-dakota-setup/features.yml ]]; then
        just configure
    else
        just system user
    fi

# A fase de sistema: /etc, PAM, udev, serviços, Flatpaks de sistema, snaps,
# Homebrew, contas. Só administradores (wheel).
system: _ensure-collections
    scripts/run-phase.sh system system.yml

# A sua fase de usuário: ~/.config, serviços da sessão, gsettings. Rode-a
# como você mesmo, na sua sessão gráfica; os outros usuários rodam só esta,
# de um clone deste repositório.
user: _ensure-collections
    scripts/run-phase.sh user user.yml

# Aplicar só as features dadas (ids de features.yml), nas duas fases (a
# metade de sistema precisa de um administrador), mesmo as desligadas nas
# suas escolhas. Ex.: `just apply capslock`, `just apply printer`.
apply +IDS: _ensure-collections
    #!/usr/bin/env bash
    set -euo pipefail
    ids="{{IDS}}"
    tags="always,${ids// /,}"
    export BLUEFIN_DAKOTA_SETUP_ENABLE="$ids"
    if id -nG | tr ' ' '\n' | grep -qx wheel; then
        scripts/run-phase.sh system system.yml --tags "$tags"
    else
        echo "Pulando a metade de sistema (só administradores)."
    fi
    scripts/run-phase.sh user user.yml --tags "$tags"

# Criar/atualizar as contas de extra_users (do seu local.yml). Cada conta
# nova define a própria senha no primeiro login, no GDM.
users: _ensure-collections
    BLUEFIN_DAKOTA_SETUP_ENABLE=users scripts/run-phase.sh system system.yml --tags always,users

# Mostrar o que os atalhos no estilo Omarchy escolhidos mudariam, sem
# gravar nada.
omarchy-keybindings-dry-run: _ensure-collections
    BLUEFIN_DAKOTA_SETUP_ENABLE=omarchy-keybindings scripts/run-phase.sh user user.yml --tags always,omarchy-keybindings -e omarchy_dry_run=true

# Conferir a sintaxe de cada ponto de entrada, a fronteira entre as fases,
# o catálogo contra as tags das plays e o docs/features.md.
check: _ensure-collections
    #!/usr/bin/env bash
    set -euo pipefail
    ansible-playbook --syntax-check site.yml >/dev/null
    for p in playbooks/system/*.yml playbooks/user/*.yml; do
        ansible-playbook --syntax-check "$p" >/dev/null
    done
    echo "Sintaxe OK."
    scripts/check-phases.sh
    scripts/python scripts/features.py check
    if ! diff -q <(scripts/python scripts/features.py doc) docs/features.md >/dev/null; then
        echo "docs/features.md está desatualizado: rode \`just docs\`." >&2
        exit 1
    fi
    echo "docs/features.md em dia."

# Regerar o docs/features.md a partir do features.yml.
docs:
    scripts/python scripts/features.py doc > docs/features.md
