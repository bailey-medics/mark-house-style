#!/usr/bin/env bash
# Install the remote-desktop switch on a Linux dev box. Run it through sudo
# from your own account, and again whenever the switch changes:
#
#   sudo bash scripts/remote-desktop/install.sh
#
# It copies the switch to /usr/local/sbin owned by root, so the copy that
# runs as root cannot be edited without root. It lets the calling account
# run its three modes, and nothing else, through sudo with no password, so
# an agent can switch for you. And it installs the dev tunnel host as a user
# service, which reads its tunnel name from ~/.config/remote-desktop/config.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user="${SUDO_USER:-}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo bash ${here}/install.sh" >&2
    exit 1
fi

if ! [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] || [ "$user" = root ] || ! id "$user" >/dev/null 2>&1; then
    echo "Run this through sudo from your own account, not as root." >&2
    exit 1
fi

home="$(getent passwd "$user" | cut -d: -f6)"
config="${home}/.config/remote-desktop/config"

bash -n "${here}/remote-desktop"
install -o root -g root -m 755 "${here}/remote-desktop" /usr/local/sbin/remote-desktop

rule="$(mktemp)"
trap 'rm -f "$rule"' EXIT
cat > "$rule" <<RULE
# Let ${user} switch the remote desktop without a password: these three
# exact commands only. The script is owned by root, so it cannot be edited.
${user} ALL=(root) NOPASSWD: /usr/local/sbin/remote-desktop google, /usr/local/sbin/remote-desktop windows, /usr/local/sbin/remote-desktop status
RULE
visudo -cf "$rule"
install -o root -g root -m 440 "$rule" /etc/sudoers.d/remote-desktop
visudo -c

units="${home}/.config/systemd/user"
install -d -o "$user" -g "$user" "$units"
install -o "$user" -g "$user" -m 644 "${here}/devtunnel-desktop.service" "${units}/devtunnel-desktop.service"
systemctl --user -M "${user}@" daemon-reload
systemctl --user -M "${user}@" enable devtunnel-desktop.service

if [ ! -e "$config" ]; then
    install -d -o "$user" -g "$user" "$(dirname "$config")"
    install -o "$user" -g "$user" -m 600 "${here}/config.example" "$config"
    echo "Fill in ${config} before using 'windows'."
fi

echo "Installed. Try: sudo remote-desktop status"
