# bluefin-dakota-setup

Automação (Ansible) do setup inicial de um
[Bluefin Dakota](https://docs.projectbluefin.io/dakota/) recém-instalado,
com um menu para escolher o que aplicar.

O Dakota é GNOME OS compilado com BuildStream e publicado como imagem
`bootc` sobre composefs-oci: **sem RPMs, sem `rpm-ostree`, sem
`authselect`**. Nada aqui mexe na imagem: só Flatpak, snap, Homebrew e
arquivos graváveis (`/etc`, `/usr/local` → `/var/usrlocal`, `~`).

Este repositório é o recorte Dakota do
[bluefin-initial-setup](https://github.com/lbssousa/bluefin-initial-setup)
(que também cobre o Bluefin clássico, sobre Fedora Atomic), reorganizado
como o [omarchy-setup](https://github.com/lbssousa/omarchy-setup): um
catálogo de features, duas fases (sistema e usuário) e `just configure`.

## Escolhendo o que aplicar

Tudo o que o repositório faz está em [`features.yml`](features.yml), o
catálogo, documentado em [docs/features.md](docs/features.md) (gerado a
partir dele): o que cada feature adiciona, modifica ou remove num Dakota de
fábrica, se vem ligada e se desligá-la desfaz o que ela fez.

```bash
just configure   # menu do gum: escolha as features; oferece aplicá-las
```

As escolhas ficam em `~/.config/bluefin-dakota-setup/features.yml`; o que
você nunca escolheu segue o padrão do catálogo. Cada usuário escolhe as
features da própria fase de usuário; a fase de sistema segue as do
administrador.

Algumas features têm alternativas, perguntadas logo depois das features
(tabela *Escolhas* em [docs/features.md](docs/features.md)). Hoje, só o
**KeePassXC** (2.8.0 ou posterior), que pode vir como:

| Escolha | Onde | Notas |
|---|---|---|
| `flatpak` (padrão) | Flatpak de sistema, do Flathub | um para todos os usuários |
| `snap` | snap `keepassxc` (strict) | precisa do snapd provisionado |
| `appimage` | AppImage oficial em `/usr/local/opt/keepassxc`, links em `/usr/local/bin` | conferido pelo `.DIGEST`; atualizado para a release nova a cada `just system` |
| `distrobox` | container `keepassxc` (Debian sid, `keepassxc-full`) de cada usuário, exportado para `~/.local` | a menor imagem que já traz o 2.8.0 e passa pelo init do distrobox; atualize com `distrobox upgrade keepassxc` |

A trava da YubiKey, o KeePassXC-Browser, o autostart e o atalho
`Super+Shift+/` usam o que estiver instalado (primeiro o método escolhido).
Trocar de método não remove a instalação anterior: a execução avisa e mostra
o comando para removê-la. Cada método guarda as configurações do KeePassXC
num lugar diferente (as bases `.kdbx` ficam onde estão).

## Duas fases

Cada automação se divide numa **fase de sistema** (`/etc`, PAM, udev,
serviços de sistema, Flatpaks de sistema, snaps, fórmulas do Homebrew,
contas — rodada por um administrador) e numa **fase de usuário** (o
`~/.config`, os serviços da sessão, o dconf de cada pessoa — rodada por
cada usuário, como ele mesmo, na própria sessão). `just check` garante a
fronteira: nada na fase de usuário vira root ou instala software (a exceção
é o container distrobox rootless do KeePassXC, que é da pessoa), nada na de
sistema fala com uma sessão de usuário.

O Homebrew do Dakota pertence ao primeiro usuário (o administrador) e não
se divide entre contas: as fórmulas (kanata, Neovim, rclone, pass-cli,
make/gawk) entram na fase de sistema, rodando como esse administrador, e
ficam no PATH de todo mundo.

## Pré-requisitos

- Um Bluefin Dakota com sessão GNOME.
- `run0` (systemd) e, para a fase de sistema, um usuário no grupo `wheel`
  que seja o dono do Homebrew (`/home/linuxbrew`).
- `just` e o Homebrew, que vêm na imagem. O `ansible`, a collection
  `community.general` e o `gum` são instalados pelo `just` quando faltam.
- Para o VSCode e o Emacs: o snapd já provisionado (o Dakota não o traz; sem
  ele, essas features avisam e pulam).

### Privilégio: run0 --empower

A fase de sistema roda o `ansible-playbook` por
[`run-empowered.sh`](run-empowered.sh), sob `run0 --empower`: o playbook
continua sendo você (mesmo `$HOME`), mas com todas as capabilities e o
grupo `empower`, para o qual a regra polkit de fábrica do systemd libera
qualquer ação. Você autentica **uma vez**, no diálogo do polkit do GNOME
(digital, YubiKey ou senha), e o `run0` de cada task `become: true` passa
sem perguntar de novo. Nada persiste: nenhuma regra polkit de root sem
senha é instalada. Enquanto ela roda, outros processos seus têm poder sobre
o processo empowered (run0(1)) — não rode com software não confiável na
sessão. Se a autenticação do polkit estiver quebrada (ex.: um problema no
pam_u2f), `EMPOWER_WITH=sudo just system` escala cada task pelo sudo.

## Uso

Como administrador, na sua conta:

```bash
git clone https://github.com/lbssousa/bluefin-dakota-setup.git
cd bluefin-dakota-setup
just setup       # o menu na primeira vez, depois a fase de sistema e a sua de usuário
```

Depois:

```bash
just configure            # mudar as escolhas (e aplicá-las)
just configure-keybindings  # só os atalhos no estilo Omarchy, um a um
just setup                # fase de sistema e depois a sua de usuário
just system | just user   # só uma fase
just apply capslock zed   # só estas features, agora (mesmo desligadas)
just users                # criar as contas de extra_users
```

Com `just apply`, uma feature desligada que sabe reverter é desfeita de novo
no próximo `just setup`; para mantê-la, ligue-a em `just configure`.

Dados pessoais ficam fora do repositório, em
`~/.config/bluefin-dakota-setup/local.yml` (modelo:
[users/local.example.yml](users/local.example.yml)): a conta Google do
rclone e, do administrador, as contas adicionais (`extra_users`, login e
nome completo). Configurações por usuário que podem ir para o git ficam em
`users/<login>.yml` ([users/README.md](users/README.md)).

Os demais usuários entram pelo GDM (definem a senha no primeiro login),
clonam o repositório e rodam a própria parte:

```bash
just user
```

`just check` confere a sintaxe, a fronteira entre as fases, o catálogo
contra as tags das plays e se o docs/features.md está em dia (`just docs`
o regera). Os playbooks são idempotentes — rodar de novo é seguro.

## O que muda em relação ao bluefin-initial-setup

- Só o Dakota: ficaram de fora o PAM via `authselect` (`playbooks/yubikey.yml`
  de lá), o tap `ublue-os` do Homebrew (no Dakota o Zed vem do `ujust`), o
  submódulo `bluefin-distrobox-libfprint` (Fedora) e o TeX Live/LilyPond em
  `/opt` (já desabilitado lá; hoje vêm do container
  [distrobox-typesetting](https://github.com/lbssousa/distrobox-typesetting)).
- Em vez de `site-dakota.yml` + tags `never` + `uninstall.yml`: o catálogo,
  as fases e, nas features com **revert**, a reversão ao desligar (Caps Lock,
  trava do KeePassXC, KeePassXC-Browser e autostart, Proton Pass, ssh-askpass,
  atalhos no estilo Omarchy, libfprint).
- O libfprint goodix538d não é mais compilado aqui: vem nas imagens do
  Dakota. A play `libfprint` só remove o que instalações antigas deixaram em
  `/usr/local`.
- A configuração do kanata é da máquina, em `/etc/kanata/kanata.kbd`
  (gerenciada), não mais o `~/.config/kanata/kanata.kbd` do administrador.
- A trava do KeePassXC tranca as bases de **toda** sessão aberta, não só a de
  quem rodou o Ansible.
- O e-mail do rclone e as contas adicionais saíram do repositório para o
  `local.yml`.
- Migrações automáticas: o bloco antigo do pam_u2f, o
  `bluefin-initial-setup.el` do Emacs e o backup dconf dos atalhos do Omarchy
  (restaurado; os atalhos são escolhidos de novo, um a um) são trocados
  pelos novos na primeira execução.

## Estrutura

| Arquivo/Diretório | Papel |
|---|---|
| `features.yml` | O catálogo: features, padrões, o que cada uma faz |
| `docs/features.md` | O catálogo como documento (`just docs`) |
| `scripts/configure.sh` | O menu do gum (`just configure`) |
| `scripts/features.py` | Resolve o catálogo com as suas escolhas; confere-o (`just check`); gera a doc |
| `scripts/run-phase.sh` | Roda uma fase: a de sistema só para `wheel`, sob `run-empowered.sh`; a de usuário só como o usuário; passa `users/$USER.yml`, `local.yml`, a seleção resolvida e as tags dela |
| `scripts/check-phases.sh` | Falha quando uma play de usuário vira root ou instala software, ou uma de sistema fala com uma sessão de usuário |
| `scripts/python` | O Python com PyYAML (o do sistema ou o do ansible do Homebrew) |
| `run-empowered.sh` | Roda o ansible-playbook sob `run0 --empower` (veja *Privilégio*) |
| `site.yml`, `system.yml`, `user.yml` | As duas fases; as plays da de sistema; as da de usuário. Cada play tem a tag do id da sua feature |
| `playbooks/system/`, `playbooks/user/` | Um arquivo por feature (ou algumas bem próximas), na sua fase |
| `playbooks/tasks/` | Tasks compartilhadas (handlers da fase de usuário, detecção do KeePassXC) |
| `playbooks/files/`, `playbooks/templates/` | Arquivos estáticos e templates Jinja2 |
| `group_vars/all/main.yml` | Variáveis de todas as automações |
| `group_vars/all/target.yml` | `target_user`/`target_home`: a conta que a execução configura |
| `users/` | Configurações por usuário e o modelo do `local.yml` |
| `docs/omarchy-keybindings.md` | Atalhos do GNOME × Omarchy e a estratégia da feature `omarchy-keybindings` |
| `requirements.yml` | Collections do Ansible |
| `Justfile` | `just configure`, `setup`, `system`, `user`, `apply`, `check`, ... |

**Nada aqui foi validado em hardware Dakota de ponta a ponta nesta
reorganização**: as plays vêm das do bluefin-initial-setup, já usadas no
Dakota, mas o Dakota ainda é alpha. Trate as features novas de reversão como
ponto de partida a testar.

## Créditos

- Bitwarden (agente SSH + polkit biométrico) e YubiKey: de
  [lbssousa/dotfiles](https://github.com/lbssousa/dotfiles).
- Fila da EPSON L4160, Caps Lock via kanata e trava do KeePassXC: de
  [lbssousa/nix-config](https://github.com/lbssousa/nix-config).
- libfprint goodix538d: de
  [lbssousa/bluefin-distrobox-libfprint](https://github.com/lbssousa/bluefin-distrobox-libfprint).
- Catálogo de features, fases, menu, `run-empowered.sh` e configuração do
  Emacs: de [lbssousa/omarchy-setup](https://github.com/lbssousa/omarchy-setup).
