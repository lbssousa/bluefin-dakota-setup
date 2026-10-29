#!/usr/bin/env bash
# Tranca todas as bases do KeePassXC quando a YubiKey é removida (evento
# udev "remove"), via D-Bus, em cada sessão aberta na máquina. Chamado pela
# regra 70-keepassxc-yubikey-lock.rules. Portado de lbssousa/nix-config
# (modules/system/security/keepassxc-yubikey-lock.nix), que também percorre
# uma lista de usuários; aqui são todos os que têm um barramento de sessão
# em /run/user.
#
# Pula, sem erro, as sessões em que o KeePassXC não está rodando.
set -uo pipefail

for bus in /run/user/*/bus; do
    [[ -S $bus ]] || continue
    runtime_dir=${bus%/bus}
    uid=${runtime_dir##*/}
    username=$(id -nu "$uid" 2>/dev/null) || continue

    run_as_user() {
        runuser -u "$username" -- env \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
            "$@"
    }

    has_owner=$(run_as_user gdbus call --session \
        --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner \
        org.keepassxc.KeePassXC.MainWindow 2>/dev/null) || continue
    [[ $has_owner == *"(true,"* ]] || continue

    run_as_user gdbus call --session \
        --dest org.keepassxc.KeePassXC.MainWindow \
        --object-path /keepassxc \
        --method org.keepassxc.KeePassXC.MainWindow.lockAllDatabases >/dev/null
done
exit 0
