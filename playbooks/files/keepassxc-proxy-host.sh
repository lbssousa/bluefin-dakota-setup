#!/usr/bin/env sh
# keepassxc-proxy-host — wrapper instalado DENTRO do diretório de dados de
# cada navegador Flatpak (~/.var/app/<browser-id>/...), portanto visível
# ao sandbox do próprio navegador. NÃO EDITE À MÃO — reescrito a cada
# execução de playbooks/keepassxc.yml (tag keepassxc-browser).
#
# Um Flatpak não consegue spawnar diretamente um processo de outro
# Flatpak. flatpak-spawn --host roda o comando no host (permissão padrão
# de quase todo Flatpak, via org.freedesktop.Flatpak), que por sua vez usa
# `flatpak run` para invocar o keepassxc-proxy de dentro do Flatpak do
# KeePassXC — a ponte de native messaging que a extensão KeePassXC-Browser
# precisa para falar com o KeePassXC.
exec flatpak-spawn --host flatpak run --command=keepassxc-proxy org.keepassxc.KeePassXC "$@"
