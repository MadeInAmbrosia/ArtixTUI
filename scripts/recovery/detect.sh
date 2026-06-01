#!/usr/bin/env bash
set -Eeuo pipefail

detect_init() {
    if [[ -d "${ROOT}/etc/runit" ]]; then
        state_set INIT runit
    elif [[ -d "${ROOT}/etc/dinit.d" ]]; then
        state_set INIT dinit
    elif [[ -d "${ROOT}/etc/s6" ]]; then
        state_set INIT s6
    else
        state_set INIT openrc
    fi
}

detect_filesystem() {
    local fs
    fs="$(findmnt -no FSTYPE "${ROOT}" 2>/dev/null || true)"
    [[ -n "${fs}" ]] || fs='ext4'
    state_set FS_TYPE "${fs}"
}

detect_zfs() {
    if pacman_root_has zfs-utils || pacman_root_has zfs-dkms; then
        state_set FS_TYPE zfs
    fi
}

detect_lvm() {
    if [[ -f "${ROOT}/etc/lvm/lvm.conf" ]] || pacman_root_has lvm2; then
        state_set USE_LVM yes
    else
        state_set USE_LVM no
    fi
}

detect_bootloader() {
    if [[ -d "${ROOT}/boot/grub" ]] || [[ -f "${ROOT}/boot/grub/grub.cfg" ]]; then
        state_set BOOTLOADER grub
    elif [[ -d "${ROOT}/boot/EFI/refind" ]] || [[ -f "${ROOT}/boot/refind_linux.conf" ]]; then
        state_set BOOTLOADER refind
    else
        state_set BOOTLOADER efistub
    fi
}

detect_uki() {
    if [[ -f "${ROOT}/boot/efi/EFI/Artix/linux-custom.efi" ]] || grep -q 'uki' "${ROOT}/etc/mkinitcpio.d/"*.preset 2>/dev/null; then
        state_set GENERATE_UKI yes
    else
        state_set GENERATE_UKI no
    fi
}

detect_kernel() {
    if pacman_root_has linux-zen; then
        state_set KERNEL_CHOICE linux-zen
    elif pacman_root_has linux-lts; then
        state_set KERNEL_CHOICE linux-lts
    elif pacman_root_has linux-hardened; then
        state_set KERNEL_CHOICE linux-hardened
    elif pacman_root_has linux-libre; then
        state_set KERNEL_CHOICE linux-libre
    elif pacman_root_has linux-cachyos-bore; then
        state_set KERNEL_CHOICE linux-cachyos-bore
    elif pacman_root_has linux-bazzite-bin; then
        state_set KERNEL_CHOICE linux-bazzite-bin
    elif pacman_root_has linux-xanmod-x64v4 || pacman_root_has linux-xanmod-x64v3 || pacman_root_has linux-xanmod-x64v2 || pacman_root_has linux-xanmod; then
        state_set KERNEL_CHOICE xanmod
    elif [[ -d "${ROOT}/opt/linux-tkg" ]] || pacman_root_has linux-tkg || pacman_root_has linux-tkg-bore; then
        state_set KERNEL_CHOICE tkg
    else
        state_set KERNEL_CHOICE linux
    fi
}

detect_desktop() {
    if pacman_root_has mangowm; then
        state_set WM_DE mango
    elif pacman_root_has hyprland; then
        state_set WM_DE hyprland
    elif pacman_root_has niri; then
        state_set WM_DE niri
    elif pacman_root_has sway; then
        state_set WM_DE sway
    elif pacman_root_has xfce4; then
        state_set WM_DE xfce4
    elif pacman_root_has lxqt; then
        state_set WM_DE lxqt
    elif pacman_root_has lxde-common || pacman_root_has lxde; then
        state_set WM_DE lxde
    elif pacman_root_has i3-wm; then
        state_set WM_DE i3wm
    elif pacman_root_has dwm; then
        state_set WM_DE dwm
    elif pacman_root_has vxwm || [[ -f "${ROOT}/usr/local/bin/vxwm" ]]; then
        state_set WM_DE vxwm
    elif pacman_root_has icewm; then
        state_set WM_DE icewm
    elif pacman_root_has plasma-desktop; then
        state_set WM_DE kde
        if pacman_root_has kde-applications; then
            state_set KDE_PROFILE full
        elif pacman_root_has dolphin; then
            state_set KDE_PROFILE minimal
        else
            state_set KDE_PROFILE desktop
        fi
    else
        state_set WM_DE none
    fi
}

detect_display_manager() {
    if pacman_root_has sddm; then
        state_set DISPLAY_MANAGER sddm
    elif pacman_root_has lightdm; then
        state_set DISPLAY_MANAGER lightdm
    else
        state_set DISPLAY_MANAGER none
    fi
}

detect_xstack() {
    if pacman_root_has xlibre-xserver; then
        state_set X_STACK xlibre
    elif pacman_root_has xorg-server; then
        state_set X_STACK xorg
    else
        state_set X_STACK none
    fi
}

detect_seat_manager() {
    if pacman_root_has seatd; then
        state_set SEAT_MANAGER seatd
    else
        state_set SEAT_MANAGER elogind
    fi
}

detect_network_stack() {
    if pacman_root_has networkmanager; then
        state_set NETWORK_STACK networkmanager
    elif pacman_root_has connman; then
        state_set NETWORK_STACK connman
    elif pacman_root_has dhcpcd || pacman_root_has iwd; then
        state_set NETWORK_STACK dhcpcd+iwd
    else
        state_set NETWORK_STACK none
    fi
}

detect_audio_stack() {
    if pacman_root_has pipewire; then
        state_set AUDIO_STACK pipewire
    elif pacman_root_has pulseaudio; then
        state_set AUDIO_STACK pulseaudio
    else
        state_set AUDIO_STACK none
    fi
}

detect_ucode() {
    if pacman_root_has intel-ucode; then
        state_set CPU_UCODE intel
    elif pacman_root_has amd-ucode; then
        state_set CPU_UCODE amd
    else
        state_set CPU_UCODE none
    fi
}

detect_user_shell() {
    local shell
    shell="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $7; exit}' "${ROOT}/etc/passwd" 2>/dev/null || true)"
    shell="${shell##*/}"
    case "${shell}" in
        bash|zsh|fish) ;;
        *) shell='bash' ;;
    esac
    state_set USER_SHELL "${shell}"
}

detect_extras() {
    local extras=()
    pacman_root_has git && extras+=(git)
    pacman_root_has flatpak && extras+=(flatpak)
    pacman_root_has fastfetch && extras+=(fastfetch)
    pacman_root_has firewalld && extras+=(firewalld)
    pacman_root_has bluez && extras+=(bluez)
    if pacman_root_has zram-generator || pacman_root_has zramen; then
        extras+=(zram-tools)
    fi
    pacman_root_has fzf && extras+=(fzf)
    pacman_root_has zoxide && extras+=(zoxide)
    pacman_root_has starship && extras+=(starship)
    pacman_root_has eza && extras+=(eza)
    pacman_root_has btop && extras+=(btop)
    pacman_root_has htop && extras+=(htop)
    pacman_root_has nvtop && extras+=(nvtop)
    pacman_root_has tmux && extras+=(tmux)
    pacman_root_has usb_modeswitch && extras+=(usb_modeswitch)
    pacman_root_has rsvc && extras+=(rsvc)
    pacman_root_has nano && extras+=(nano)
    pacman_root_has vim && extras+=(vim)
    pacman_root_has neovim && extras+=(neovim)
    pacman_root_has micro && extras+=(micro)
    pacman_root_has helix && extras+=(helix)
    pacman_root_has firefox && extras+=(firefox)
    pacman_root_has chromium && extras+=(chromium)
    pacman_root_has qutebrowser && extras+=(qutebrowser)
    pacman_root_has ranger && extras+=(ranger)
    pacman_root_has lf && extras+=(lf)
    pacman_root_has nnn && extras+=(nnn)
    pacman_root_has thunar && extras+=(thunar)
    pacman_root_has alacritty && extras+=(alacritty)
    pacman_root_has kitty && extras+=(kitty)
    pacman_root_has foot && extras+=(foot)
    pacman_root_has mpv && extras+=(mpv)
    pacman_root_has feh && extras+=(feh)
    state_set EXTRAS "${extras[*]}"
}

detect_repositories() {
    if grep -Eq '^\[(core|extra|multilib)\]' "${ROOT}/etc/pacman.conf" 2>/dev/null; then
        state_set ENABLE_ARCH_REPOS yes
    else
        state_set ENABLE_ARCH_REPOS no
    fi
    if grep -q '^\[chaotic-aur\]' "${ROOT}/etc/pacman.conf" 2>/dev/null; then
        state_set HAS_CHAOTIC yes
    else
        state_set HAS_CHAOTIC no
    fi
}

detect_username() {
    local user
    user="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}' "${ROOT}/etc/passwd" 2>/dev/null || true)"
    [[ -n "${user}" ]] || user='artix'
    state_set USER_NAME "${user}"
}

detect_luks() {
    local source parent
    source="$(findmnt -no SOURCE "${ROOT}" 2>/dev/null || true)"
    [[ -n "${source}" ]] || return 0
    parent="$(lsblk -no PKNAME "${source}" 2>/dev/null || true)"
    if [[ -n "${parent}" ]] && cryptsetup isLuks "/dev/${parent}" &>/dev/null; then
        state_set USE_LUKS yes
    else
        state_set USE_LUKS no
    fi
}

detect_disk() {
    local source pkname disk candidate
    source="$(findmnt -no SOURCE "${ROOT}" 2>/dev/null || true)"
    [[ -n "${source}" ]] || return 0

    if [[ "${source}" == /dev/mapper/* ]]; then
        pkname="$(lsblk -no PKNAME "${source}" 2>/dev/null || true)"
        [[ -n "${pkname}" ]] && source="/dev/${pkname}"
    fi

    candidate="${source}"
    while [[ -n "${candidate}" ]]; do
        disk="$(lsblk -no PKNAME "${candidate}" 2>/dev/null || true)"
        if [[ -z "${disk}" ]]; then
            # This is already a disk
            break
        fi
        candidate="/dev/${disk}"
    done

    if [[ -b "${candidate}" ]]; then
        state_set DISK "${candidate}"
        log_info "Detected installation disk: ${candidate}"
        return 0
    fi

    local fstab_root
    fstab_root="$(awk '$2 == "/" {print $1}' "${ROOT}/etc/fstab" 2>/dev/null | head -n1)"
    if [[ "${fstab_root}" == UUID=* ]]; then
        candidate="$(blkid -U "${fstab_root#UUID=}" 2>/dev/null || true)"
        [[ -b "${candidate}" ]] && { state_set DISK "${candidate}"; log_info "Detected disk from fstab UUID: ${candidate}"; return 0; }
    fi

    log_warn "Could not auto-detect installation disk."
    if tui_yesno "Disk Detection" "Automatic disk detection failed. Would you like to select the installation disk manually?"; then
        tui_select_disk
    else
        die "Cannot continue without a valid installation disk."
    fi
}

detect_display_protocol() {
    if [[ -d "${ROOT}/usr/share/wayland-sessions" ]]; then
        state_set DISPLAY_PROTOCOL wayland
    elif [[ -d "${ROOT}/usr/share/xsessions" ]]; then
        state_set DISPLAY_PROTOCOL x11
    fi
}

detect_nvidia() {
    if pacman_root_has nvidia || pacman_root_has nvidia-dkms || pacman_root_has nvidia-open; then
        state_set GPU_DRIVER nvidia
    fi
}

detect_virtualization() {
    if pacman_root_has qemu-guest-agent; then
        state_set VM_GUEST qemu
    elif pacman_root_has virtualbox-guest-utils; then
        state_set VM_GUEST virtualbox
    elif pacman_root_has open-vm-tools; then
        state_set VM_GUEST vmware
    else
        state_set VM_GUEST none
    fi
}

detect_hostname() {
    local hostname='artix'
    [[ -f "${ROOT}/etc/hostname" ]] && hostname="$(tr -d '[:space:]' < "${ROOT}/etc/hostname")"
    state_set HOSTNAME "${hostname}"
}

detect_coreutils() {
    if pacman_root_has busybox && [[ "$(readlink "${ROOT}/usr/bin/ls" 2>/dev/null)" == *"busybox"* ]]; then
        state_set COREUTILS busybox
    elif pacman_root_has uutils-coreutils; then
        state_set COREUTILS uutils
    elif [[ -f "${ROOT}/etc/artix-poweruser/world.txt" ]] && grep -q 'artix-coreutils' "${ROOT}/etc/artix-poweruser/world.txt" 2>/dev/null; then
        state_set COREUTILS artix
    else
        state_set COREUTILS gnu
    fi
}

detect_poweruser() {
    if [[ -f "${ROOT}/etc/artix-poweruser/world.txt" ]] || [[ -f "${ROOT}/usr/local/bin/gartix" ]]; then
        state_set POWER_USER yes
        if [[ -f "${ROOT}/etc/artix-poweruser/world.txt" ]]; then
            local pkgs
            pkgs=$(tr '\n' ' ' < "${ROOT}/etc/artix-poweruser/world.txt")
            state_set POWERUSER_PACKAGES "${pkgs}"
        fi
        if [[ -f "${ROOT}/usr/share/artix-poweruser/profile/active" ]]; then
            state_set POWERUSER_PROFILE "$(tr -d '[:space:]' < "${ROOT}/usr/share/artix-poweruser/profile/active")"
        fi
    else
        state_set POWER_USER no
    fi
}

detect_priv_escalation() {
    if pacman_root_has doas && [[ -f "${ROOT}/etc/doas.conf" ]]; then
        state_set PRIV_ESCALATION doas
    elif pacman_root_has sudo; then
        state_set PRIV_ESCALATION sudo
    else
        state_set PRIV_ESCALATION none
    fi
}

detect_install_stage() {
    local status=""
    [[ -f "${ROOT}/etc/fstab" ]] && status+="fstab "
    [[ -x "${ROOT}/usr/bin/bash" ]] && status+="basestrap "
    [[ -f "${ROOT}/boot/grub/grub.cfg" ]] && status+="grub "
    [[ -f "${ROOT}/boot/efi/EFI/Artix/linux-custom.efi" ]] && status+="uki "
    [[ -d "${ROOT}/home" ]] && status+="home "
    [[ -f "${ROOT}/etc/hostname" ]] && status+="hostname "
    [[ -f "${ROOT}/etc/locale.conf" ]] && status+="locale "
    [[ -f "${ROOT}/root/.artix-post-complete" ]] && status+="post-complete "
    if pacman_root_has xfce4 || pacman_root_has plasma-desktop || pacman_root_has hyprland; then
        status+="desktop "
    fi
    [[ -z "${status}" ]] && status="minimal (base system only)"
    state_set RECOVERY_STATUS "${status}"
}

detect_fstab_health() {
    if [[ -f "${ROOT}/etc/fstab" ]]; then
        local issues=""
        while IFS= read -r line; do
            [[ -z "${line}" || "${line}" == \#* ]] && continue
            local device
            device=$(echo "${line}" | awk '{print $1}')
            if [[ "${device}" == UUID=* ]]; then
                local uuid="${device#UUID=}"
                if ! blkid -U "${uuid}" &>/dev/null; then
                    issues+="missing-uuid:${uuid} "
                fi
            fi
        done < "${ROOT}/etc/fstab"
        state_set FSTAB_ISSUES "${issues:-none}"
    else
        state_set FSTAB_ISSUES "missing"
    fi
}

detect_boot_health() {
    local issues=""
    if [[ -d "${ROOT}/boot" ]]; then
        if ! ls "${ROOT}/boot/vmlinuz-"* &>/dev/null; then
            issues+="no-kernel "
        fi
        if ! ls "${ROOT}/boot/initramfs-"*.img &>/dev/null; then
            issues+="no-initramfs "
        fi
    else
        issues+="no-boot-dir "
    fi
    if command -v efibootmgr &>/dev/null; then
        if ! efibootmgr 2>/dev/null | grep -qi 'Artix'; then
            issues+="no-efi-entry "
        fi
    fi
    state_set BOOT_ISSUES "${issues:-none}"
}

detect_pacman_health() {
    local issues=""
    if [[ -f "${ROOT}/var/lib/pacman/db.lck" ]]; then
        issues+="stale-lock "
    fi
    if ! pacman --root "${ROOT}" -Q base &>/dev/null 2>&1; then
        issues+="base-missing "
    fi
    local broken
    broken=$(pacman --root "${ROOT}" -Qk 2>/dev/null | grep ': missing' | cut -d: -f1 | sort -u | tr '\n' ' ')
    if [[ -n "${broken}" ]]; then
        local count
        count=$(echo "${broken}" | wc -w)
        issues+="broken-pkgs:${count} "
        state_set BROKEN_PACKAGES "${broken}"
    else
        state_set BROKEN_PACKAGES ""
    fi
    state_set PACMAN_ISSUES "${issues:-none}"
}