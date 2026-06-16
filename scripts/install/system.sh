#!/usr/bin/env bash
set -Eeuo pipefail

configure_system() {
    local hostname timezone locale keymap
    hostname="$(state_get HOSTNAME artix)"
    timezone="$(state_get TIMEZONE UTC)"
    locale="$(state_get LOCALE en_US.UTF-8)"
    keymap="$(state_get KEYMAP us)"

    [[ -n "${hostname}" ]] && [[ "${hostname}" =~ ^[a-zA-Z0-9][a-zA-Z0-9\-]*$ ]] || die 'invalid hostname'
    [[ -n "${timezone}" ]] || die 'invalid timezone'
    [[ -n "${locale}" ]] || die 'invalid locale'
    [[ -n "${keymap}" ]] || die 'invalid keymap'

    log_info "Configuring hostname..."
    printf '%s\n' "${hostname}" > /mnt/etc/hostname
    cat <<EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${hostname}.localdomain ${hostname}
EOF

    log_info "Configuring locale..."
    if grep -q "^#${locale}" /mnt/etc/locale.gen; then
        sed -i "s/^#${locale}/${locale}/" /mnt/etc/locale.gen
    elif ! grep -q "^${locale}" /mnt/etc/locale.gen; then
        printf '%s UTF-8\n' "${locale%% *}" >> /mnt/etc/locale.gen
    fi
    artix-chroot /mnt locale-gen || die 'failed to generate locale'
    cat <<EOF > /mnt/etc/locale.conf
LANG=${locale}
EOF

    log_info "Configuring keyboard layout..."
    cat <<EOF > /mnt/etc/vconsole.conf
KEYMAP=${keymap}
EOF
    artix-chroot /mnt localectl set-keymap "${keymap}" 2>/dev/null || log_warn "Failed to set console keymap"

    local wm_de
    wm_de="$(state_get WM_DE none)"
    case "${wm_de}" in
        hyprland|sway|niri|mango)
            log_info "Wayland compositor detected — skipping X11 keymap (compositor handles layout)"
            ;;
        *)
            artix-chroot /mnt localectl set-x11-keymap "${keymap}" 2>/dev/null || log_warn "Failed to set X11 keymap"
            ;;
    esac

    log_info "Configuring timezone..."
    [[ -e "/mnt/usr/share/zoneinfo/${timezone}" ]] || die 'invalid timezone path'
    ln -sf "/usr/share/zoneinfo/${timezone}" /mnt/etc/localtime
    artix-chroot /mnt hwclock --systohc || die 'failed to synchronize hardware clock'

    log_info "System configuration complete."
}