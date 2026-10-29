#!/usr/bin/env bash
# Runs a command (normally ansible-playbook) under `run0 --empower`.
#
# The command keeps running as YOUR user, so $HOME, $USER, ~/.config and
# `systemctl --user` all behave as usual, but with every capability and the
# "empower" group, for which systemd's stock polkit rule
# (/usr/share/polkit-1/rules.d/empower.rules) allows every action. You
# authenticate once, through the desktop's polkit dialog (GNOME's agent,
# fingerprint or password); every `become: true` task's own `run0
# --user=root` inside then passes without another prompt.
#
# Why not rely on `become_method = community.general.run0` alone: GNOME
# (Bluefin Dakota's desktop) registers a graphical polkit agent, so
# each bare run0 call pops up a dialog, and polkit doesn't retain the
# authorization between separate run0 processes (same behavior verified for
# lbssousa/omarchy-setup, which this script is ported from). A playbook run
# has dozens of privileged tasks: dozens of dialogs.
#
# No polkit rule is installed and nothing persists: the privileges live only
# in this process tree, for as long as the command runs. Per run0(1), other
# unprivileged processes of your user have privileges over an empowered
# process, so avoid running this with untrusted software going on in your
# session.
#
# run0 starts from a clean environment, so every variable of the caller is
# passed through by name (--setenv=NAME, no value = the current one): PATH
# (Homebrew, mise shims), XDG_RUNTIME_DIR/DBUS_SESSION_BUS_ADDRESS
# (`systemctl --user`, the GNOME polkit agent)...
#
# TEMPORARY ESCAPE HATCH — EMPOWER_WITH=sudo: skips run0 and lets Ansible
# escalate each `become: true` task through sudo instead (ansible.cfg's
# become_method is overridden by ANSIBLE_BECOME_METHOD). Meant for when
# polkit authentication is unusable (e.g. a pam_u2f/pkexec problem). The
# command still runs as your user; there is no single up-front
# authentication, so sudo asks once PER privileged task (touch the
# YubiKey, or the sudo password prompt — see below). "-n" is dropped from
# sudo's flags so PAM can wait for the touch, and the connection timeout
# is raised for the same reason. Unset the variable to go back to run0.
#
# Usage: ./run-empowered.sh ansible-playbook system.yml --tags <tag>
#        EMPOWER_WITH=sudo ./run-empowered.sh ansible-playbook system.yml --tags <tag>
# (normally through scripts/run-phase.sh: `just system`, `just apply <id>`)
#        ./run-empowered.sh --help
set -euo pipefail

if [[ $# -eq 0 || $1 == -h || $1 == --help ]]; then
    sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "$0"
    exit 0
fi

if [[ ${EMPOWER_WITH:-run0} == sudo ]]; then
    echo "run-empowered.sh: EMPOWER_WITH=sudo — escalating each task via sudo (no run0)" >&2
    exec env ANSIBLE_BECOME_METHOD=sudo ANSIBLE_BECOME_FLAGS='-H -S' \
        ANSIBLE_TIMEOUT="${ANSIBLE_TIMEOUT:-120}" "$@"
fi

setenv=()
while IFS='=' read -r -d '' name _; do
    if [[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ && $name != _ ]]; then
        setenv+=("--setenv=$name")
    fi
done < <(env -0)

exec run0 --empower "${setenv[@]}" "$@"
