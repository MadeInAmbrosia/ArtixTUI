#!/usr/bin/env bash
set -Eeuo pipefail

ATA_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ata_detect_all() {
    log_info "Auditing Arch system..."

    # Core system (uses recovery detection functions)
    detect_init
    detect_display_manager
    detect_xstack
    detect_audio_stack
    detect_network_stack
    detect_kernel
    detect_ucode
    detect_bootloader
    detect_filesystem
    detect_luks
    detect_lvm
    detect_uki

    # Override desktop detection with Arch package names
    local -A arch_de_pkgs=(
        ["kde"]="plasma-meta plasma-desktop"
        ["xfce4"]="xfce4"
        ["cinnamon"]="cinnamon"
        ["budgie"]="budgie-desktop"
        ["gnome"]="gnome-shell"
        ["lxqt"]="lxqt-session"
        ["lxde"]="lxde-common"
        ["hyprland"]="hyprland"
        ["sway"]="sway"
        ["niri"]="niri"
        ["i3wm"]="i3-wm"
        ["dwm"]="dwm"
        ["icewm"]="icewm"
        ["mate"]="mate-desktop"
    )

    local detected_de="none"
    for de in "${!arch_de_pkgs[@]}"; do
        local found=0
        for pkg in ${arch_de_pkgs[$de]}; do
            if pacman -Q "$pkg" &>/dev/null; then
                detected_de="$de"
                found=1
                break
            fi
        done
        [[ $found -eq 1 ]] && break
    done

    if [[ "$detected_de" == "mate" ]]; then
        log_warn "MATE desktop detected, but MATE is not supported for automatic migration."
        log_warn "Setting WM_DE=none so you can install a desktop manually after migration."
        state_set WM_DE none
    else
        state_set WM_DE "$detected_de"
    fi

    # Users
    awk -F: '$3>=1000 && $1!="nobody" {print $1}' /etc/passwd > /tmp/ata-users.txt

    # Package inventory
    pacman -Qq > /tmp/ata-all-pkgs.txt
    pacman -Qqe > /tmp/ata-explicit.txt
    pacman -Qqm > /tmp/ata-aur.txt
    pacman -Qqd > /tmp/ata-deps.txt

    # AUR package details
    while IFS= read -r pkg; do
        pacman -Qi "$pkg" 2>/dev/null | grep -E '^(Name|Version|Description|URL):' >> /tmp/ata-aur-info.txt
    done < /tmp/ata-aur.txt

    # Flatpaks and Snaps
    flatpak list --app --columns=application 2>/dev/null > /tmp/ata-flatpak.txt || true
    snap list 2>/dev/null | tail -n +2 | awk '{print $1}' > /tmp/ata-snap.txt || true

    # AppImages
    find /home /opt -name '*.AppImage' 2>/dev/null > /tmp/ata-appimages.txt

    # Docker
    docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}' 2>/dev/null > /tmp/ata-docker.txt || true

    # Systemd units
    systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' > /tmp/ata-units.txt

    # User units: iterate over each user, not just root
    : > /tmp/ata-user-units.txt
    while IFS= read -r user; do
        if id "$user" &>/dev/null; then
            su - "$user" -c 'systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null' 2>/dev/null | awk '{print $1}' >> /tmp/ata-user-units.txt || true
        fi
    done < /tmp/ata-users.txt

    # Custom unit files
    find /etc/systemd/system -name '*.service' -not -name 'dbus-org.*' > /tmp/ata-custom-units.txt 2>/dev/null

    # Timers
    systemctl list-timers --all --no-legend 2>/dev/null | awk '{print $NF}' > /tmp/ata-timers.txt

    # Network configs
    for d in /etc/systemd/network /etc/netctl /etc/NetworkManager/system-connections /var/lib/iwd; do
        find "$d" -type f 2>/dev/null
    done > /tmp/ata-network-files.txt

    # DNS
    [[ -f /etc/systemd/resolved.conf ]] && cp /etc/systemd/resolved.conf /tmp/ata-resolved.conf
    if [[ -L /etc/resolv.conf ]]; then
        readlink -f /etc/resolv.conf > /tmp/ata-resolv-link.txt
    fi

    # systemd-homed
    homectl list 2>/dev/null > /tmp/ata-homed.txt || true

    # systemd-boot
    bootctl status 2>/dev/null > /tmp/ata-bootctl.txt || true

    # Journal size
    journalctl --disk-usage 2>/dev/null > /tmp/ata-journal-size.txt || true

    # DKMS
    dkms status 2>/dev/null > /tmp/ata-dkms.txt || true

    # Exotic mounts
    grep -E 'nfs|cifs|sshfs|ceph|gluster' /etc/fstab 2>/dev/null > /tmp/ata-exotic-mounts.txt || true

    # Custom repos
    grep -rhE '^\[.*\]' /etc/pacman.conf /etc/pacman.d/ 2>/dev/null | sort -u > /tmp/ata-custom-repos.txt

    # Pacman hooks that reference systemd
    grep -rl 'systemctl\|journalctl\|systemd' /usr/share/libalpm/hooks/ 2>/dev/null > /tmp/ata-systemd-hooks.txt || true

    # PAM modules
    grep -rl 'pam_systemd' /etc/pam.d/ 2>/dev/null > /tmp/ata-pam-systemd.txt || true

    # crypttab
    [[ -f /etc/crypttab ]] && cp /etc/crypttab /tmp/ata-crypttab.txt

    # Firewall rules
    iptables-save 2>/dev/null > /tmp/ata-iptables.rules || true
    nft list ruleset 2>/dev/null > /tmp/ata-nftables.rules || true

    # Cron jobs
    while IFS= read -r user; do
        crontab -u "$user" -l > "/tmp/ata-cron-${user}.txt" 2>/dev/null || true
    done < /tmp/ata-users.txt
    find /etc/cron.* -type f > /tmp/ata-cron-files.txt 2>/dev/null || true

    # SSH keys
    find /etc/ssh -type f > /tmp/ata-ssh.txt 2>/dev/null || true

    # /usr/local
    find /usr/local -type f 2>/dev/null > /tmp/ata-usrlocal.txt || true

    # timesyncd state
    timedatectl show 2>/dev/null > /tmp/ata-timedatectl.txt || true

    # Flatpak remotes (for restoration)
    flatpak remotes --columns=name 2>/dev/null > /tmp/ata-flatpak-remotes.txt || true

    # Snap packages (for reference only, snaps need systemd)
    if command -v snap >/dev/null 2>&1; then
        snap list 2>/dev/null | tail -n +2 | awk '{print $1}' > /tmp/ata-snap.txt || true
        log_warn "Snap packages detected. Snaps require systemd and will NOT function on Artix."
        log_warn "List saved to backup. Consider replacing with flatpaks or native packages."
    fi

    log_info "Audit complete."
}