# Configurações por usuário

Um `<login>.yml` por pessoa, carregado por `scripts/run-phase.sh` (toda
receita do `just`) como extra vars — sobrepõe `group_vars/all/*` só para
esse usuário. Quais features se aplicam é escolhido à parte, com
`just configure` (gravado em `~/.config/bluefin-dakota-setup/features.yml`).
Tudo é opcional; quem não tiver arquivo fica com os padrões. Chaves
típicas:

| Chave | O quê |
|---|---|
| `emacs_font_family`, `emacs_font_size` | fonte do Emacs |
| `emacs_packages` | pacotes Emacs instalados pelo package.el |
| `proton_pass_ssh_agent_wait_seconds` | espera pelo agente SSH antes de injetar as chaves do Proton Pass |

Dados pessoais ficam fora do repositório, em
`~/.config/bluefin-dakota-setup/local.yml`, carregado depois deste arquivo:
a conta do rclone (`rclone_gdrive_email`) e, para o administrador, as
contas adicionais (`extra_users`). Modelo: `local.example.yml`.
