# Features

<!-- Gerado a partir de features.yml por `just docs`. Não edite à mão. -->

O que cada automação faz num Bluefin Dakota de fábrica e se vem ligada
até você escolher outra coisa com `just configure`. **Reverte**: desligar
desfaz na próxima execução; senão, desligar só para de gerenciar.

## Contas

| Feature | Tag | Efeito | Fases | Padrão | Reverte |
|---|---|---|---|---|---|
| Contas adicionais | `users` | adds as contas de extra_users (local.yml do administrador), com definição de senha no primeiro login (accountsservice PasswordMode=1) | system | ligada | não |

## Autenticação e YubiKey

| Feature | Tag | Efeito | Fases | Padrão | Reverte |
|---|---|---|---|---|---|
| YubiKey no PAM | `yubikey-pam` | modifies /etc/pam.d/system-auth (pam_u2f depois do pam_fprintd — digital, YubiKey, senha) e o sandbox do polkit-agent-helper; adds o registro da YubiKey em ~/.config/Yubico/u2f_keys | system, user | ligada | não |
| pcscd enxergando a YubiKey | `yubikey-pcscd` | adds um drop-in do pcscd (udevadm settle no boot) e uma regra udev que o reinicia quando a YubiKey é conectada | system | ligada | não |
| Chave GPG da YubiKey | `gpg-yubikey` | adds a chave pública OpenPGP do cartão ao keyring; modifies ~/.gitconfig (user.signingkey, commit/tag.gpgsign) | user | desligada | não |
| Trava do KeePassXC ao remover a YubiKey | `keepassxc-yubikey-lock` | adds uma regra udev e um script que trancam o KeePassXC de cada sessão aberta quando a YubiKey sai da porta USB | system | ligada | sim |
| ssh-askpass gráfico | `ssh-askpass` | adds SSH_ASKPASS e SSH_ASKPASS_REQUIRE=prefer em ~/.config/environment.d (PIN/toque da chave FIDO2 sem terminal) | user | ligada | sim |

## Gerenciadores de senha

| Feature | Tag | Efeito | Fases | Padrão | Reverte |
|---|---|---|---|---|---|
| Bitwarden | `bitwarden` | adds o Flatpak, a polkit action do desbloqueio biométrico e o agente SSH da sessão; modifies gcr-ssh-agent (mascarado) | system, user | desligada | não |
| Proton Pass CLI | `proton-pass` | adds pass-cli (Homebrew) e um serviço systemd --user que injeta as chaves SSH do cofre no agente ativo | system, user | desligada | sim |
| KeePassXC | `keepassxc` | adds o KeePassXC 2.8.0+ do jeito escolhido em seguida — Flatpak de sistema (Flathub), snap, AppImage oficial em /usr/local ou um distrobox Debian sid de cada usuário; trocar de método não remove o anterior (avisa) | system, user | ligada | não |
| KeePassXC-Browser nos navegadores Flatpak | `keepassxc-browser` | adds o manifesto de native messaging e um wrapper flatpak-spawn (para o keepassxc-proxy da instalação encontrada) em cada navegador Flatpak instalado; modifies o override do navegador (talk-name org.freedesktop.Flatpak) | user | ligada | sim |
| KeePassXC no login | `keepassxc-autostart` | adds ~/.config/autostart/org.keepassxc.KeePassXC.desktop | user | ligada | sim |

## Desktop

| Feature | Tag | Efeito | Fases | Padrão | Reverte |
|---|---|---|---|---|---|
| Caps Lock via kanata | `capslock` | adds kanata (Homebrew) como serviço de sistema com /etc/kanata/kanata.kbd (toque = Esc, segurar = Ctrl, Shift+Caps Lock = Caps Lock) | system | ligada | sim |
| Atalhos no estilo Omarchy | `omarchy-keybindings` | modifies atalhos do GNOME para janelas, apps e utilitários (gsettings), escolhidos um a um em seguida (just configure-keybindings); desmarcar um atalho, ou desligar, devolve o que ele mudou ao original | user | desligada | sim |

## Shell

| Feature | Tag | Efeito | Fases | Padrão | Reverte |
|---|---|---|---|---|---|
| Readline estilo Fish | `bash-completion` | modifies ~/.inputrc (completion case-insensitive, busca no histórico pelas setas) | user | ligada | não |
| ble.sh | `blesh` | adds make/gawk (Homebrew) e o ble.sh em ~/.local (syntax highlighting, autosuggestions); modifies ~/.bashrc | system, user | ligada | não |

## Editores e desenvolvimento

| Feature | Tag | Efeito | Fases | Padrão | Reverte |
|---|---|---|---|---|---|
| VSCode (snap) | `vscode` | adds o snap code (classic); pula se não houver snapd | system | ligada | não |
| Emacs (snap) | `emacs` | adds o snap emacs (classic), AUCTeX, yasnippet, lsp-mode e o tema classic; modifies ~/.config/emacs/init.el (um bloco gerenciado) | system, user | ligada | não |
| Neovim + LazyVim | `neovim` | adds o Neovim (Homebrew), o starter do LazyVim (se ~/.config/nvim não existir), o extra de LaTeX e o gregorio.nvim | system, user | ligada | não |
| Zed com Podman | `zed` | adds ~/.config/zed/settings.json com use_podman (só se o arquivo ainda não existir) | user | ligada | não |

## Boot e hardware

| Feature | Tag | Efeito | Fases | Padrão | Reverte |
|---|---|---|---|---|---|
| systemd-boot sem menu | `systemd-boot` | modifies o loader.conf da ESP (timeout 0, console-mode keep, editor no); removes a variável EFI LoaderConfigTimeout | system | ligada | não |
| Impressora EPSON L4160 | `printer` | adds a fila CUPS driverless da L4160 como impressora padrão | system | desligada | não |

## Extras (opt-in)

| Feature | Tag | Efeito | Fases | Padrão | Reverte |
|---|---|---|---|---|---|
| Google Drive (rclone) | `rclone-gdrive` | adds rclone (Homebrew) e montagens do Google Drive (systemd --user) | system, user | desligada | não |

## Escolhas

Features com alternativas, escolhidas em `just configure` logo depois das features.

| Feature | Pergunta | Escolhas | Padrão | Variável |
|---|---|---|---|---|
| KeePassXC | Como instalar o KeePassXC? | `flatpak`: Flatpak de sistema (Flathub)<br>`snap`: snap (strict; precisa do snapd)<br>`appimage`: AppImage oficial em /usr/local (atualizado a cada execução)<br>`distrobox`: distrobox Debian sid (keepassxc-full) de cada usuário | `flatpak` | `keepassxc_install_method` |
