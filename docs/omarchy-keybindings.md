# Atalhos de teclado: GNOME (esta sessão) × Omarchy

Comparação entre os atalhos definidos hoje na sessão GNOME (Bluefin Dakota, Wayland,
GNOME Shell 51 + extensões) e os atalhos padrão do
[Omarchy](https://github.com/omacom/omarchy) v4 (Hyprland), mais a estratégia
e a automação (feature `omarchy-keybindings`,
`playbooks/user/omarchy-keybindings.yml`) que aproximam o primeiro
do segundo.

- **Fonte do Omarchy:** `default/hypr/bindings/{tiling,utilities,applications,media,clipboard}.lua`
  e `config/ghostty/config`, branch `quattro` (release v4.0.4, 2026‑09‑15).
  O próprio Omarchy lista os seus atalhos com `SUPER + K`.
- **Fonte desta sessão:** `gsettings list-recursively` dos schemas
  `org.gnome.desktop.wm.keybindings`, `org.gnome.mutter(.wayland).keybindings`,
  `org.gnome.shell.keybindings`, `org.gnome.settings-daemon.plugins.media-keys`
  (+ `custom-keybindings`), Tiling Shell, Dash to Dock, Ghostty e kanata
  (levantamento de 2026‑10‑03).
- Notação: `Super` = tecla Windows/Meta (o `SUPER` do Omarchy).

## 1. Atalhos hoje definidos na sessão

### 1.1 Alterados por você (diferem do padrão do GNOME)

| Atalho | Ação | Onde |
|---|---|---|
| `Ctrl+Alt+T` | Terminal (`xdg-terminal-exec`) | custom0 |
| `Ctrl+Alt+Enter` | Terminal (alt) | custom1 |
| `Ctrl+Shift+Esc` | Mission Center | custom2 |
| `Ctrl+Alt+Backspace` | Alpaca | custom3 |
| `Super+E` | Nautilus (nova janela) | custom4 |
| `Ctrl+Alt+Espaço` | Seletor de emoji (Smile) | custom5 |
| `Super+.` | Seletor de emoji (Smile, alt) | custom6 |
| `Shift+Super+Espaço` | Trocar fonte de entrada | media-keys/wm |
| `Super+←/→` | Tiling Shell: mover janela entre tiles | Tiling Shell |
| `Super+↑/↓` | Tiling Shell: mover janela entre tiles | Tiling Shell |
| `F11` | Tela cheia no Ghostty | `~/.config/ghostty/config.ghostty` |
| `Caps` | tap = `Esc`, hold = `Ctrl`, `Shift`+tap = Caps Lock | kanata (evdev) |

Tiling Shell desliga `maximize`/`unmaximize` (`Super+↑/↓`) e `toggle-tiled-*`
(`Super+←/→`) do GNOME, e `edge-tiling` do mutter (`dconf` mostra `[]`/`false`).

### 1.2 Padrões do GNOME ainda ativos (os relevantes)

| Grupo | Atalhos |
|---|---|
| Janelas | `Alt+F4` fechar · `Alt+F10` maximizar · `Super+H` minimizar · `Super+D` mostrar área de trabalho · `Alt+Espaço` menu da janela · `Alt+F7/F8` mover/redimensionar · `Super+Shift+←↑→↓` janela → monitor |
| Alternância | `Alt+Tab` janelas · `Super+Tab` **apps** · `Super+\`` / `Alt+\`` janelas do mesmo app · `Alt+Esc` |
| Workspaces | `Super+PgUp/PgDn`, `Super+Alt+←/→`, `Ctrl+Alt+←/→/↑/↓` ir · `Super+Shift+PgUp/PgDn`, `Super+Shift+Alt+←/→`, `Ctrl+Shift+Alt+setas` mover janela · `Super+Home/End` primeiro/último |
| Shell | `Super+A` grade de apps · `Super+S` configurações rápidas · `Super+V`/`Super+M` bandeja de notificações · `Super+N` foco na notificação · `Super+L` bloquear · `Super+P` espelhar/trocar tela · `Ctrl+Alt+Del` encerrar sessão · `Alt+F2` executar comando |
| Apps do dash | `Super+1…9` ativar app N do dash · `Super+Ctrl+1…9` nova janela do app N |
| Dash to Dock | `Super+1…0` (+`Ctrl`/`Shift`) apps do dock · `Super+Q` mostrar o dock |
| Captura | `Print` UI de screenshot · `Shift+Print` tela inteira · `Alt+Print` janela · `Ctrl+Shift+Alt+R` gravação de tela |
| Acessibilidade | `Alt+Super+8` lupa · `Alt+Super+=`/`-` zoom · `Alt+Super+S` leitor de tela |
| Mídia (XF86) | volume/mudo/brilho/play/next/prev/eject/calc/etc. — teclas de mídia padrão |

## 2. Estratégia

1. **Mapear 1:1 quando o GNOME tem a função.** Fechar, tela cheia, maximizar,
   workspaces 1–10, mover janela, monitor, lupa, lock, gravação de tela e
   troca de janelas existem como chaves do GNOME → só mudam de tecla.
2. **Usar o Tiling Shell para o que o GNOME não tem** (foco direcional, trocar
   janelas de posição, float/tile ≈ *untile*). Funciona só com a extensão
   habilitada; sem ela as chaves ficam inertes.
3. **Atalhos de apps/painéis viram *custom keybindings*** (`omarchy-*`), sem
   tocar nos seus `custom0…6`. Cada um tem um `check` (o atalho é pulado se o
   app não estiver instalado). Painéis do Omarchy (`Super+Ctrl+A/B/W/D/P`)
   viram `gnome-control-center <painel>`.
4. **Resolver colisões antes de atribuir.** O GNOME aceita o mesmo atalho em
   duas ações e o resultado é imprevisível. Colisões tratadas:
   `Super+1…9` (dash/Shell e Dash to Dock) → workspaces; `Super+Q` (Dash to
   Dock) → fechar; `Super+Shift+←↑→↓` (monitor) → `Super+Shift+Alt+…`;
   `Super+L` → `Super+Ctrl+L`; `Super+A` → `Super+Alt+Espaço`;
   `Super+O` (rotação de tela) → pin; `Alt+Print` (screenshot de janela) →
   `Shift+Alt+Print`; `Super+Tab` (apps) → próximo workspace.
5. **Workspaces fixos.** O Omarchy tem 10 workspaces; `Super+N` leva ao N mesmo
   vazio. Para isso o GNOME precisa de workspaces estáticos
   (`dynamic-workspaces=false`, `num-workspaces=10`). Desligável com
   `-e omarchy_keys_static_workspaces=false`.
6. **O que não tem equivalente fica como está** (tabela 4) — não se rouba um
   atalho do GNOME para uma função que não existe.
7. **Reversível.** Backup dconf dos caminhos tocados na 1ª execução;
   desligar a feature (`just configure`) restaura o backup no próximo
   `just user`. **Simulável:**
   `just omarchy-keybindings-dry-run` mostra cada `de → para` sem gravar.

## 3. Comparação por grupo

Legenda: ✅ igual · 🔁 equivalente aproximado (função análoga) · ➕ novo atalho
(custom) · ⛔ sem equivalente no GNOME · ⚙️ já era igual antes.

### 3.1 Janelas

| Omarchy | Função no Omarchy | Antes (GNOME) | Depois | |
|---|---|---|---|---|
| `Super+W` / `Super+Q` | Fechar janela | `Alt+F4`; `Super+Q` = dock | `Alt+F4`, `Super+W`, `Super+Q` | ✅ |
| `Ctrl+Alt+Del` | Fechar todas as janelas | Encerrar sessão | inalterado (segurança) | ⛔ |
| `Super+F` | Tela cheia | — | `Super+F` | ✅ |
| `Super+Alt+F` | "Full width" | `Alt+F10` | `Alt+F10` + `Super+Alt+F` | 🔁 |
| `Super+Ctrl+F`, `Super+Ctrl+Alt+F` | Fullscreen em tiles / desktop | — | — | ⛔ |
| `Super+T` | Alternar flutuante/tiling | — | `Super+T` → *untile* (Tiling Shell) | 🔁 |
| `Super+O` | Pop-out (float + pin) | `Super+O` = trava rotação | `Super+O` → em todos os workspaces | 🔁 |
| `Super+J`, `Super+P`, `Super+G`… | Split, pseudo, grupos (abas) | `Super+P` = espelhar tela | inalterado | ⛔ |
| `Super+←/→/↑/↓` | **Foco** direcional | Tiling Shell: mover janela | **Foco** (Tiling Shell `focus-window-*`) | ✅ |
| `Super+Shift+←/→/↑/↓` | **Trocar** janela de lugar | mover janela p/ monitor | mover/trocar tile (`move-window-*`) | ✅ |
| `Super+Shift+Alt+←/→/↑/↓` | Mover workspace p/ monitor | mover p/ workspace (esq/dir) | mover **janela** p/ monitor | 🔁 |
| `Super+Home` / `Super+Alt+Home` | Restaurar/salvar largura | `Super+Home` = workspace 1 | inalterado | ⛔ |
| `Super+Alt+←/→/↑/↓`, `Super+Ctrl+←/→` | Mover para / navegar grupos | `Super+Alt+←/→` = workspace | inalterado | ⛔ |
| `Super+=`/`Super+-` (+`Alt`/`Ctrl`) | Redimensionar janela | — | — (use `Alt+F8` / mouse) | ⛔ |
| `Super+botão esq./dir.` | Mover / redimensionar com o mouse | idem (`mouse-button-modifier=<Super>`) | idem | ⚙️ |

### 3.2 Workspaces e alternância

| Omarchy | Função | Antes | Depois | |
|---|---|---|---|---|
| `Super+1…0` | Ir ao workspace N | `Super+N` = app N do dash/dock | workspace N (dock/dash liberados) | ✅ |
| `Super+Shift+1…0` | Mover janela p/ workspace N | — | idem | ✅ |
| `Super+Shift+Alt+1…0` | Mover sem seguir | — | — | ⛔ |
| `Super+Tab` / `Super+Shift+Tab` | Próximo / anterior workspace | alternar **apps** | próximo / anterior workspace | ✅ |
| `Super+Ctrl+Tab` | Workspace anterior (histórico) | — | — | ⛔ |
| `Alt+Tab` / `Alt+Shift+Tab` | Próxima / anterior janela | idem | idem | ⚙️ |
| `Ctrl+Alt+Tab` | Foco no próximo monitor | foco nos painéis (a11y) | inalterado | ⛔ |
| `Super+S`, `Super+\`` | Scratchpad | `Super+S` = config. rápidas | inalterado | ⛔ |
| `Super+scroll` | Rolar workspaces | — | — | ⛔ |

### 3.3 Menus, launcher e utilitários

| Omarchy | Função | Antes | Depois | |
|---|---|---|---|---|
| `Super+Espaço` | Menu Omarchy / launcher | — | Visão geral (`toggle-overview`) | 🔁 |
| `Super+Alt+Espaço` | Menu de apps | `Super+A` = grade de apps | grade de apps | 🔁 |
| `Super+Esc` | Menu do sistema | restaurar atalhos (Wayland) | inalterado (necessário em VMs/RDP) | ⛔ |
| `Super+K` (+`Alt`/`Ctrl`) | Lista de atalhos | — | — (este documento) | ⛔ |
| `Super+Ctrl+Q` | Calculadora | — | Calculadora | ➕ |
| `Super+Ctrl+E` | Emojis | `Ctrl+Alt+Espaço`, `Super+.` (mantidos) | + `Super+Ctrl+E` | ➕ |
| `Super+Ctrl+T` | Atividade (btop) | `Ctrl+Shift+Esc` (mantido) | + `Super+Ctrl+T` → Mission Center | ➕ |
| `Super+Ctrl+A/B/W/D/P` | Painéis Áudio/Bluetooth/Rede/Tela/Energia | — | `gnome-control-center sound/bluetooth/wifi/display/power` | ➕ |
| `Super+Ctrl+Alt+D` / `+E` | Calendário / relógio mundial | — | Calendário / Relógios | ➕ |
| `Super+Ctrl+N` | Alternar luz noturna | — | alterna `night-light-enabled` | ➕ |
| `Super+Ctrl+L` | Bloquear sistema | `Super+L` | `Super+Ctrl+L` (`Super+L` liberado) | ✅ |
| `Super+Ctrl+Z` / `+Alt+Z` | Zoom / resetar zoom | `Alt+Super+=`, `Alt+Super+8` | `Super+Ctrl+Z` / `Super+Ctrl+Alt+Z` (lupa) | 🔁 |
| `Super+,` (+`Shift`/`Ctrl`/`Alt`) | Dispensar/silenciar/invocar notificações | — | — | ⛔ |
| `Super+Shift+Alt+,` | Histórico de notificações | `Super+V`/`Super+M` | `Super+Shift+Alt+,` (bandeja) | 🔁 |
| `Super+Backspace` (+`Shift`/`Ctrl`) | Transparência / gaps / aspecto | — | — | ⛔ |
| `Super+Shift+Espaço` | Barra superior | `Shift+Super+Espaço` = fonte de entrada | inalterado | ⛔ |
| `Super+Ctrl+I`, `Super+Ctrl+R`, `Super+Ctrl+S`, `Super+/` … | Idle, lembretes, compartilhar, escala | — | — | ⛔ |

### 3.4 Aplicativos

| Omarchy | Função | Antes | Depois | |
|---|---|---|---|---|
| `Super+Enter` | Terminal | `Ctrl+Alt+T`, `Ctrl+Alt+Enter` (mantidos) | + `Super+Enter` | ➕ |
| `Super+Alt+Enter` | Terminal + tmux | — | `xdg-terminal-exec tmux` | ➕ |
| `Super+Shift+Enter` / `Super+Shift+B` | Navegador | — | navegador padrão (`xdg-mime`) | ➕ |
| `Super+Shift+F` | Gerenciador de arquivos | `Super+E` (mantido) | + `Super+Shift+F` | ➕ |
| `Super+Shift+N` | Editor | — | `nvim` no terminal | ➕ |
| `Super+Shift+/` | Senhas (1Password) | — | KeePassXC | 🔁 |
| `Super+Shift+A/Y/X/G/P/S…` | Webapps (ChatGPT, YouTube, X, Maps…) | — | opt‑in: `-e omarchy_keys_webapps=true` | ➕ |
| `Super+Shift+D/M/O/W/C/E` | Docker, música, Obsidian, Hey… | — | — (apps do Omarchy) | ⛔ |

### 3.5 Captura

| Omarchy | Função | Antes | Depois | |
|---|---|---|---|---|
| `Print` | Screenshot | UI de screenshot | idem | ⚙️ |
| `Alt+Print` | Gravar tela | screenshot de janela | UI de gravação (`Alt+Print`); janela → `Shift+Alt+Print` | ✅ |
| `Super+Print` / `Super+Ctrl+Print` | Seletor de cor / OCR | — | — | ⛔ |
| `Super+Ctrl+C` | Menu de captura | — | — (use `Print`) | ⛔ |

### 3.6 Mídia (XF86)

Volume, mudo, microfone, brilho, play/pause/next/prev, teclado retroiluminado,
touchpad e eject são teclas XF86 tratadas por `gnome-settings-daemon` do mesmo
jeito que o Omarchy → ⚙️ iguais. Diferenças deixadas como estão: o Omarchy usa
`Alt+Volume/Brilho` para o passo fino e `Alt+Play`/`Alt+Shift+Play` para
próxima/anterior; no GNOME o passo fino é `Shift+Volume` e `Alt+Volume` é
"silencioso". `Shift+Mute` (trocar saída de áudio) não existe.

### 3.7 Área de transferência

| Omarchy | Função | GNOME | |
|---|---|---|---|
| `Super+C` / `Super+V` / `Super+X` / `Super+A` | Cópia/colagem/recorte/selecionar tudo "universais" (injeta `Ctrl`/`Ctrl+Shift` no app em foco) | ⛔ — o GNOME Shell não injeta teclas em apps. `Super+V` segue como bandeja de notificações e `Super+A`, grade de apps (→ `Super+Alt+Espaço`, pois `Super+A` ficaria sem função) | ⛔ |
| `Super+Ctrl+V` | Gerenciador de clipboard | — | ⛔ |

### 3.8 Terminal (Ghostty)

| Omarchy | Função | Antes | Depois |
|---|---|---|---|
| `Shift+Insert` / `Ctrl+Insert` | Colar / copiar | — | ✅ (bloco gerenciado em `config.ghostty`) |
| `Shift+Enter`, `Alt+Shift+Enter` | Enviam CSI‑u (TUIs distinguem `Shift+Enter`; tmux casa `M-S-Enter`) | — | ✅ |
| `Super+Ctrl+Shift+Alt+setas` | Redimensionar split | — | ✅ |
| `F11` | (Bluefin) tela cheia | `F11` | mantido |

## 4. Divergências deliberadas (não replicadas)

- **Caps Lock (kanata):** o Omarchy usa `Caps` como tecla *Compose*
  (`kb_options = compose:caps`); aqui `Caps` é tap=`Esc`/hold=`Ctrl`
  (feature `capslock`, `playbooks/system/capslock.yml`). Mantido — é preferência pessoal explícita.
- **Ctrl+Alt+Del** continua abrindo o diálogo de encerrar sessão.
- **`Super+Esc`, `Super+S`, `Super+P`, `Super+V`, `Super+Home`** mantêm o
  significado do GNOME (restaurar atalhos em VM/RDP, configurações rápidas,
  espelhar tela, bandeja, workspace 1): as funções do Omarchy não existem
  aqui, e cada uma é útil.
- Atalhos que dependem de recursos exclusivos do Hyprland (grupos/abas,
  pseudo‑tiles, scratchpad, split dwindle/master, redimensionar por teclado,
  gaps/transparência, painéis da barra Omarchy) ficam ⛔.

## 5. Uso

```bash
just omarchy-keybindings-dry-run   # mostra as mudanças, não grava
just configure                     # ligar (ou desligar: restaura o backup) e aplicar
```

`just apply omarchy-keybindings` aplica sem mexer nas escolhas, mas, com a
feature desligada, o próximo `just user` desfaz (ela reverte).

Opções (`-e`): `omarchy_keys_webapps=true` · `omarchy_keys_static_workspaces=false`
· `omarchy_dry_run=true`. Os dados (atalhos, comandos, `check`s) estão em
`playbooks/files/omarchy-keybindings.vars.yml`; o motor idempotente em
`playbooks/files/omarchy-keybindings-apply.py`. A feature vem **desligada**
(opt-in), porque muda os atalhos da sessão inteira.

Depois de aplicar, o estado final foi checado por script: nenhum atalho
duplicado entre schemas GNOME, Tiling Shell, Dash to Dock e custom keybindings.
Reaplicar é seguro (a 2ª execução não muda nada). Os atalhos do Tiling Shell
e do Dash to Dock exigem as extensões instaladas; sem elas, são pulados.
