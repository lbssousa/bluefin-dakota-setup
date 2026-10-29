#!/usr/bin/env bash
# `just configure`: escolha, com o gum, quais features este setup aplica
# para você. O catálogo é features.yml (docs/features.md); as escolhas vão
# para ~/.config/bluefin-dakota-setup/features.yml, que `just setup`,
# `just system` e `just user` aplicam. Parte das suas escolhas atuais (ou
# dos defaults do catálogo), mostra o que mudaria e oferece aplicar na hora.
#
# Administradores escolhem todas as features; os demais usuários só as que
# têm fase de usuário (o resto é da máquina, escolhido por um administrador).
#
# Com omarchy-keybindings ligada, segue-se uma etapa por grupo de atalhos
# (catálogo: playbooks/files/omarchy-keybindings.vars.yml), para escolher
# um a um quais aplicar. `scripts/configure.sh keybindings` (`just
# configure-keybindings`) pula as features e vai direto a essa etapa.
#
# Uso: scripts/configure.sh [keybindings]
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."

menu() { scripts/python scripts/features.py menu "$@"; }

admin=0
id -nG | tr ' ' '\n' | grep -qx wheel && admin=1

# O gum choose devolve ids (rótulo|id, --label-delimiter); --selected casa
# rótulos.
choose_many() { # cabeçalho; linhas "rótulo|id" no stdin; pré-seleção em $selected
    local header=$1
    gum choose --no-limit --height=15 --header="$header" --label-delimiter='|' \
        --selected="$selected" || true
}

only_keys=0
[[ ${1:-} == keybindings ]] && only_keys=1

declare -A feature_on key_on

# As features, grupo a grupo.
choose_features() {
    gum style --border=rounded --padding="0 2" --margin="1 0" \
        "bluefin-dakota-setup — o que aplicar" \
        "Espaço marca/desmarca, Enter confirma. ⟲ marca as features" \
        "cujas mudanças são desfeitas quando desmarcadas."

    # As listas são lidas em arrays antes: um laço lendo de um pipe dividiria o
    # stdin com o gum, que comeria o resto da lista.
    mapfile -t groups < <(menu groups)
    for group_line in "${groups[@]}"; do
        IFS=$'\t' read -r group title <<<"$group_line"
        options=() selected="" rows=()
        mapfile -t feature_lines < <(menu features "$group" "$admin")
        for feature_line in "${feature_lines[@]}"; do
            IFS=$'\t' read -r id label on effect <<<"$feature_line"
            options+=("$label|$id")
            rows+=("| $label | $effect |")
            [[ $on == 1 ]] && selected+="${selected:+,}$label"
        done
        [[ ${#options[@]} -gt 0 ]] || continue
        printf '%s\n' "## $title" "" "| Feature | Efeito |" "|---|---|" "${rows[@]}" | gum format >&2
        picked=$(printf '%s\n' "${options[@]}" | choose_many "$title — quais aplicar?")
        for opt in "${options[@]}"; do
            id=${opt##*|}
            if printf '%s\n' "$picked" | grep -qx "$id"; then feature_on[$id]=true; else feature_on[$id]=false; fi
        done
    done
}

if [[ $only_keys == 1 ]]; then
    feature_on[omarchy-keybindings]=true
else
    choose_features
fi

# Atalhos no estilo Omarchy, um a um. Desmarcar um atalho já aplicado
# devolve as chaves que ele mudou ao valor original.
if [[ ${feature_on[omarchy-keybindings]:-false} == true ]]; then
    gum style --border=rounded --padding="0 2" --margin="1 0" \
        "Atalhos no estilo Omarchy — quais aplicar" \
        "Cada atalho escolhido sai de qualquer outra ação que o usasse;" \
        "desmarcar um já aplicado devolve o que ele mudou ao original." \
        "Comparação completa: docs/omarchy-keybindings.md."
    mapfile -t key_groups < <(menu key-groups)
    for group_line in "${key_groups[@]}"; do
        IFS=$'\t' read -r group title <<<"$group_line"
        options=() selected="" rows=()
        mapfile -t key_lines < <(menu keys "$group")
        for key_line in "${key_lines[@]}"; do
            IFS=$'\t' read -r id label on effect <<<"$key_line"
            options+=("$label|$id")
            rows+=("| $label | $effect |")
            [[ $on == 1 ]] && selected+="${selected:+,}$label"
        done
        [[ ${#options[@]} -gt 0 ]] || continue
        printf '%s\n' "## Atalhos: $title" "" "| Atalho | Efeito |" "|---|---|" "${rows[@]}" | gum format >&2
        picked=$(printf '%s\n' "${options[@]}" | choose_many "$title — quais atalhos aplicar?")
        for opt in "${options[@]}"; do
            id=${opt##*|}
            if printf '%s\n' "$picked" | grep -qx "$id"; then key_on[$id]=true; else key_on[$id]=false; fi
        done
    done
fi

json=$(
    {
        for id in "${!feature_on[@]}"; do printf 'features\t%s\t%s\n' "$id" "${feature_on[$id]}"; done
        for id in "${!key_on[@]}"; do printf 'omarchy-keybindings\t%s\t%s\n' "$id" "${key_on[$id]}"; done
    } | scripts/python -c '
import json, sys
out = {"features": {}, "omarchy-keybindings": {}}
for line in sys.stdin.read().splitlines():
    section, key, value = line.split("\t")
    out[section][key] = value == "true"
print(json.dumps(out))
'
)

changes=$(menu summary <<<"$json")
if [[ -z $changes ]]; then
    gum style "Nada muda."
else
    printf '%s\n' "## Mudanças" "" "$changes" | gum format
fi

if ! errors=$(menu save <<<"$json" 2>&1); then
    gum style --foreground=1 "Não gravado — estas escolhas não combinam:" "$errors"
    echo "Rode \`just configure\` de novo." >&2
    exit 1
fi
gum style "Gravado em ${XDG_CONFIG_HOME:-$HOME/.config}/bluefin-dakota-setup/features.yml."

if gum confirm "Aplicar agora?"; then
    if [[ $only_keys == 1 ]]; then
        scripts/run-phase.sh user user.yml --tags always,omarchy-keybindings
    elif [[ $admin == 1 ]]; then
        just system user
    else
        just user
    fi
fi
