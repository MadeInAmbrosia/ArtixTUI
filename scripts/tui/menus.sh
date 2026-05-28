#!/usr/bin/env bash
set -Eeuo pipefail

tui_select_disk() {
    local disk disks=()
    while IFS=' ' read -r name size model; do
        disks+=("${name} - ${size} (${model:-Unknown})")
    done < <(lsblk -dpno NAME,SIZE,MODEL -e 7)

    disk=$(tui_menu "Disk Selection" "Choose target drive:" "${disks[@]}") || return 1
    disk="${disk%% *}"
    state_set DISK "${disk}"
}

tui_select_init() {
    local init
    init=$(tui_menu "Init System" "Select init system:" \
        "OpenRC" "runit" "dinit" "s6") || return 1
    state_set INIT "${init,,}"
}

tui_select_filesystem() {
    local fs
    local fs_options=("ext4" "btrfs" "xfs" "f2fs" "bcachefs" "exfat")

    local live_kernel_pkg=""
    case "$(uname -r)" in
        *lts*)       live_kernel_pkg="linux-lts" ;;
        *zen*)       live_kernel_pkg="linux-zen" ;;
        *hardened*)  live_kernel_pkg="linux-hardened" ;;
        *)           live_kernel_pkg="linux" ;;
    esac

    if grep -q '^\[archzfs\]' /etc/pacman.conf 2>/dev/null \
        && pacman -Sl archzfs 2>/dev/null | grep -q "zfs-${live_kernel_pkg} "; then
        fs_options+=("zfs")
    fi

    fs=$(tui_menu "Filesystem" "Select filesystem:" "${fs_options[@]}") || return 1

    if [[ "${fs}" == "zfs" ]]; then
        tui_msg_quick "ZFS Selected" "ZFS likes to break. You're on your own. Good luck!"
    elif [[ "${fs}" == "bcachefs" ]]; then
        tui_msg "Unavailable" "Bcachefs-tools is temporarily disabled for stability reasons (Rust rewrite W.I.P)."
        tui_select_filesystem
        return
    fi

    state_set FS_TYPE "${fs}"
}



tui_select_bootloader() {
    local bl
    bl=$(tui_menu "Bootloader" "Select bootloader:" \
        "GRUB" "rEFInd" "EFIStub") || return 1
    state_set BOOTLOADER "${bl,,}"
}

tui_select_uki() {
    if tui_yesno "UKI" "Generate a Unified Kernel Image (UKI)?"; then
        state_set GENERATE_UKI "yes"
    else
        state_set GENERATE_UKI "no"
    fi
}

tui_select_kernel() {
    local k
    k=$(tui_menu "Kernel" "Select kernel:" \
        "linux" "linux-zen" "linux-lts" "linux-hardened" "linux-libre" \
        "linux-cachyos-bore" "linux-bazzite-bin" "xanmod" "tkg") || return 1
    state_set KERNEL_CHOICE "${k}"
}

tui_select_desktop() {
    local d
    d=$(tui_menu "Desktop Environment" "Select desktop:" \
        "xfce4" "lxqt" "kde" "lxde" "mango" "hyprland" "niri" "sway" \
        "i3wm" "dwm" "vxwm" "icewm" "none") || return 1
    state_set WM_DE "${d}"

    if [[ "${d}" == "kde" ]]; then
        local profile
        profile=$(tui_menu "KDE Profile" "Select KDE Plasma profile:" \
            "minimal" "desktop" "full") || return 1
        state_set KDE_PROFILE "${profile}"
    else
        state_set KDE_PROFILE "none"
    fi
}

tui_select_display_manager() {
    local wm dm
    wm="$(state_get WM_DE none)"
    if [[ "${wm}" =~ ^(none|dwm|i3wm|icewm|hyprland|mango|niri|sway)$ ]]; then
        dm=$(tui_menu "Display Manager" "Select display manager:" "None" "LightDM" "SDDM") || return 1
    else
        dm=$(tui_menu "Display Manager" "Select display manager:" "LightDM" "SDDM") || return 1
    fi
    state_set DISPLAY_MANAGER "${dm,,}"
}

tui_select_xstack() {
    local wm stack
    wm="$(state_get WM_DE none)"
    if [[ "${wm}" == "none" ]]; then
        state_set X_STACK "none"
        return 0
    fi
    stack=$(tui_menu "Display Stack" "Select display stack:" "X.Org" "xLibre") || return 1
    state_set X_STACK "${stack,,}"
}

tui_select_network_stack() {
    local ns
    ns=$(tui_menu "Networking" "Select network stack:" \
        "NetworkManager" "dhcpcd+iwd" "ConnMan" "None") || return 1
    state_set NETWORK_STACK "${ns,,}"
}

tui_select_audio_stack() {
    local as
    as=$(tui_menu "Audio" "Select audio stack:" "PipeWire" "PulseAudio" "None") || return 1
    state_set AUDIO_STACK "${as,,}"
}

tui_select_shell() {
    local s
    s=$(tui_menu "User Shell" "Select default shell:" "bash" "zsh" "fish") || return 1
    state_set USER_SHELL "${s}"
}

tui_select_extras() {
    local extras category

    category=$(tui_menu "Extras" "Select category:" \
        "System Tools" \
        "Editors" \
        "Browsers" \
        "File Managers" \
        "Terminals" \
        "Shell & Prompt" \
        "Monitoring" \
        "Media" \
        "Done (finish selection)") || return 1

    local selected=""
    while [[ "${category}" != "Done"* ]]; do
        case "${category}" in
            "System Tools")
                selected+=$(tui_checklist "System Tools" "Select system packages:" \
                    "git" "flatpak" "firewalld" "bluez" "zram-tools" "usb_modeswitch") || true
                ;;
            "Editors")
                selected+=$(tui_checklist "Editors" "Select text editors:" \
                    "nano" "vim" "neovim" "micro" "helix") || true
                ;;
            "Browsers")
                selected+=$(tui_checklist "Browsers" "Select web browsers:" \
                    "firefox" "chromium" "qutebrowser") || true
                ;;
            "File Managers")
                selected+=$(tui_checklist "File Managers" "Select file managers:" \
                    "ranger" "lf" "nnn" "thunar") || true
                ;;
            "Terminals")
                selected+=$(tui_checklist "Terminals" "Select terminal emulators:" \
                    "alacritty" "kitty" "foot") || true
                ;;
            "Shell & Prompt")
                selected+=$(tui_checklist "Shell & Prompt" "Select shell tools:" \
                    "fastfetch" "fzf" "zoxide" "starship" "eza" "tmux") || true
                ;;
            "Monitoring")
                selected+=$(tui_checklist "Monitoring" "Select monitoring tools:" \
                    "btop" "htop" "nvtop") || true
                ;;
            "Media")
                selected+=$(tui_checklist "Media" "Select media tools:" \
                    "mpv" "feh") || true
                ;;
        esac
        selected+=$'\n'
        category=$(tui_menu "Extras" "Select category:" \
            "System Tools" \
            "Editors" \
            "Browsers" \
            "File Managers" \
            "Terminals" \
            "Shell & Prompt" \
            "Monitoring" \
            "Media" \
            "Done (finish selection)") || break
    done

    state_set EXTRAS "${selected//$'\n'/ }"
}

tui_select_luks() {
    if tui_yesno "Disk Encryption" "Enable LUKS full disk encryption?"; then
        state_set USE_LUKS "yes"
        local pass
        pass=$(tui_password_confirm "LUKS Passphrase" "Enter passphrase:" "Confirm passphrase:") || return 1
        state_set LUKS_PASS "${pass}"
    else
        state_set USE_LUKS "no"
    fi

    if tui_yesno "LVM" "Enable Logical Volume Management (LVM)?"; then
        state_set USE_LVM "yes"
    else
        state_set USE_LVM "no"
    fi
}

tui_select_arch_repos() {
    local kernel fs_type wm_de required='no' reasons=()
    kernel="$(state_get KERNEL_CHOICE linux)"
    fs_type="$(state_get FS_TYPE ext4)"
    wm_de="$(state_get WM_DE none)"

    case "${kernel}" in
        linux-bazzite-bin|linux-cachyos-bore|xanmod) required='yes'; reasons+=("Kernel ${kernel}") ;;
    esac
    case "${fs_type}" in
        zfs) required='yes'; reasons+=("ZFS filesystem") ;;
    esac
    case "${wm_de}" in
        hyprland|niri) required='yes'; reasons+=("${wm_de} may need Arch packages") ;;
    esac

    if [[ "${required}" == "yes" ]]; then
        local reason_list
        reason_list=$(printf ' - %s\n' "${reasons[@]}")
        tui_msg_quick "Arch Repositories Required" $'Enabling official Arch repositories because:\n\n'"${reason_list}"
        state_set ENABLE_ARCH_REPOS "yes"
        return 0
    fi

    if tui_yesno "Arch Repositories" "Enable official Arch repositories?"; then
        state_set ENABLE_ARCH_REPOS "yes"
    else
        state_set ENABLE_ARCH_REPOS "no"
    fi
}

tui_select_offline_mode() {
    local off
    off=$(tui_menu "Offline Installation" "Allow offline installation?" "No (require internet)" "Yes (cached install)") || return 1
    case "${off}" in
        Yes*) state_set ALLOW_OFFLINE "yes" ;;
        *)     state_set ALLOW_OFFLINE "no" ;;
    esac
}

tui_select_username() {
    local u
    u=$(tui_input "Username" "Enter username:" "artix") || return 1
    u="${u//[$'\r'$'\n'$'\t' ]/}"
    [[ -n "${u}" ]] || return 1
    state_set USER_NAME "${u}"
}

tui_select_user_password() {
    local pass
    pass=$(tui_password_confirm "User Password" "Enter user password:" "Confirm password:") || return 1
    state_set USER_PASS "${pass}"
}

tui_select_root_password() {
    local pass
    pass=$(tui_password_confirm "Root Password" "Enter root password:" "Confirm password:") || return 1
    state_set ROOT_PASS "${pass}"
}

tui_select_hostname() {
    local h
    while true; do
        h=$(tui_input "Hostname" "Enter system hostname:" "artix") || return 1
        h="${h//[$'\r'$'\n'$'\t' ]/}"
        [[ -n "${h}" ]] || return 1
        if [[ "${h}" =~ ^[a-zA-Z0-9][a-zA-Z0-9\-]*$ ]]; then
            state_set HOSTNAME "${h}"
            return 0
        fi
        tui_msg_quick "Invalid Hostname" "Allowed: a-z, A-Z, 0-9, dash. Start with letter/digit."
    done
}

tui_select_timezone() {
    local tz
    while true; do
        tz=$(tui_input "Timezone" "Enter timezone (Region/City):" "Europe/Belgrade") || return 1
        if [[ -f "/usr/share/zoneinfo/${tz}" ]]; then break; fi
        tui_msg_quick "Invalid Timezone" "Timezone not found. Example: Europe/London"
    done
    state_set TIMEZONE "${tz}"
}

tui_select_locale() {
    local l
    l=$(tui_input "Locale" "Enter locale:" "en_US.UTF-8") || return 1
    state_set LOCALE "${l}"
}

tui_select_priv_escalation() {
    local priv
    priv=$(tui_menu "Privilege Escalation" "Select privilege escalation tool:" \
        "sudo" "doas") || return 1
    state_set PRIV_ESCALATION "${priv,,}"
}

tui_select_keyboard_layout() {
    local k
    k=$(tui_input "Keyboard Layout" "Enter keyboard layout:" "us") || return 1
    state_set KEYMAP "${k}"
}

tui_select_microcode() {
    local detected='amd-ucode'
    grep -q 'GenuineIntel' /proc/cpuinfo && detected='intel-ucode'

    if tui_yesno "CPU Microcode" "Detected ${detected}. Use automatically?"; then
        state_set MICROCODE_OVERRIDE "${detected}"
        return 0
    fi
    local u
    u=$(tui_menu "CPU Microcode" "Select microcode:" "amd-ucode" "intel-ucode" "none") || return 1
    state_set MICROCODE_OVERRIDE "${u}"
}

tui_select_btrfs_layout() {
    local fs_type
    fs_type="$(state_get FS_TYPE ext4)"
    [[ "${fs_type}" == "btrfs" ]] || return 0
    local layout
    layout=$(tui_menu "BTRFS Layout" "Select subvolume layout:" "standard" "flat" "snapshot") || return 1
    state_set BTRFS_LAYOUT "${layout}"
}

tui_select_poweruser() {
    [[ "$(state_get POWER_USER no)" == "yes" ]] || return 0

    state_set POWER_USER "yes"

    POWERUSER_DIR="${BASE_DIR}/poweruser"
    source "${POWERUSER_DIR}/lib/flags.bash"
    source "${POWERUSER_DIR}/lib/recipe.bash"
    source "${POWERUSER_DIR}/tui/menu_poweruser.sh"

    tui_poweruser_config
}

tui_show_sanity_warnings() {
    local warnings=()

    [[ "$(state_get FS_TYPE)" == "exfat" ]] && warnings+=("exFAT not recommended for root")
    [[ "$(state_get FS_TYPE)" == "zfs" ]] && warnings+=("ZFS is experimental — DKMS rebuilds may be required")
    [[ "$(state_get FS_TYPE)" == "bcachefs" ]] && warnings+=("bcachefs is experimental — tools may be unstable")

    [[ "$(state_get KERNEL_CHOICE)" == "linux-libre" ]] && warnings+=("linux-libre removes non-free firmware — hardware may not work")
    [[ "$(state_get KERNEL_CHOICE)" == "tkg" ]] && warnings+=("TKG kernel requires manual compilation after install")

    [[ "$(state_get BOOTLOADER)" == "efistub" ]] && warnings+=("EFIStub needs compatible UEFI firmware")
    [[ "$(state_get BOOTLOADER)" == "uki" ]] && warnings+=("UKI is UEFI-only — BIOS systems not supported")
    [[ "$(state_get BOOTLOADER)" == "grub" && "$(state_get FS_TYPE)" == "xfs" ]] && warnings+=("GRUB + XFS: ensure bigtime is disabled for compatibility")
    [[ "$(state_get BOOTLOADER)" == "uki" && "$(state_get USE_LUKS)" == "yes" ]] && warnings+=("UKI + LUKS: ensure initramfs includes encrypt hook")

    [[ "$(state_get INIT)" == "busybox" ]] && warnings+=("BusyBox init is minimal — manual service scripts required")
    [[ "$(state_get INIT)" == "busybox" && "$(state_get WM_DE)" != "none" ]] && warnings+=("BusyBox init with a desktop — you'll need to start services manually")
    [[ "$(state_get INIT)" == "busybox" && "$(state_get COREUTILS)" != "busybox" && "$(state_get COREUTILS)" != "artix" ]] && warnings+=("BusyBox init with GNU coreutils — consider BusyBox coreutils for consistency")

    [[ "$(state_get USE_LVM)" == "yes" && "$(state_get BOOTLOADER)" == "grub" ]] && warnings+=("LVM + GRUB: ensure lvm2 hook is in initramfs")
    [[ "$(state_get USE_LVM)" == "yes" && "$(state_get BOOTLOADER)" == "efistub" ]] && warnings+=("LVM + EFIStub: cmdline must reference /dev/mapper paths")
    [[ "$(state_get USE_LVM)" == "yes" && "$(state_get USE_LUKS)" == "yes" ]] && warnings+=("LVM on LUKS: correct crypt device order is critical")
    [[ "$(state_get USE_LVM)" == "yes" && "$(state_get FS_TYPE)" == "exfat" ]] && warnings+=("LVM + exFAT is unusual — ensure your use case supports this")
    
    [[ "$(state_get USE_LUKS)" == "yes" && "$(state_get BOOTLOADER)" == "refind" ]] && warnings+=("LUKS + rEFInd: may require manual boot config")
    [[ "$(state_get USE_LUKS)" == "yes" && "$(state_get FS_TYPE)" == "zfs" ]] && warnings+=("LUKS + ZFS: complex setup, test thoroughly before relying on it")

    [[ "$(state_get COREUTILS)" == "busybox" ]] && warnings+=("BusyBox coreutils — some scripts may need GNU extensions")
    [[ "$(state_get COREUTILS)" == "uutils" ]] && warnings+=("uutils coreutils — Rust-based, may have compatibility gaps")
    [[ "$(state_get COREUTILS)" == "custom" ]] && warnings+=("Custom coreutils — ensure all essential tools are implemented")
    [[ "$(state_get COREUTILS)" != "gnu" && "$(state_get COREUTILS)" != "none" && "$(state_get COREUTILS)" != "" ]] && warnings+=("Non-GNU coreutils: some install scripts may behave unexpectedly")

    [[ "$(state_get WM_DE)" == "none" ]] && warnings+=("No desktop environment selected")
    [[ "$(state_get WM_DE)" =~ ^(hyprland|niri|sway)$ && "$(state_get X_STACK)" == "xorg" ]] && warnings+=("Wayland compositor selected but X.Org display stack configured")
    [[ "$(state_get WM_DE)" =~ ^(hyprland|niri)$ && "$(state_get ENABLE_ARCH_REPOS)" == "no" ]] && warnings+=("Hyprland/Niri may need Arch repositories for dependencies")
    [[ "$(state_get DISPLAY_MANAGER)" == "none" && "$(state_get WM_DE)" != "none" ]] && warnings+=("No display manager — you'll start the desktop manually")

    [[ "$(state_get NETWORK_STACK)" == "none" ]] && warnings+=("No network stack — you'll configure networking manually")

    [[ "$(state_get POWER_USER)" == "yes" && "$(state_get KEEP_BINARY_KERNEL)" == "no" ]] && warnings+=("No fallback kernel — system may be unbootable if custom kernel fails")
    [[ "$(state_get POWER_USER)" == "yes" && " $(state_get POWERUSER_PACKAGES) " =~ " glibc " ]] && warnings+=("glibc from source is DANGEROUS — a miscompilation breaks everything")
    [[ "$(state_get POWER_USER)" == "yes" && "$(state_get INIT)" == "busybox" ]] && warnings+=("BusyBox init from source — ensure the recipe compiled successfully")

    [[ "$(state_get ALLOW_OFFLINE)" == "yes" ]] && warnings+=("Offline mode — packages may be outdated or missing")

    [[ "$(state_get PRIV_ESCALATION)" == "none" ]] && warnings+=("No privilege escalation tool — you'll need to configure su manually")
    [[ "$(state_get PRIV_ESCALATION)" == "doas" && "$(state_get POWER_USER)" == "yes" ]] && warnings+=("doas + Power User: gartix commands require root; use 'doas gartix ...'")

    [[ "$(state_get QUICK_INSTALL)" == "yes" && "$(state_get WM_DE)" == "embedded" ]] && warnings+=("Embedded profile: minimal system, no networking, no desktop — know what you're doing")

    if [[ ${#warnings[@]} -gt 0 ]]; then
        local msg
        msg=$(printf ' - %s\n' "${warnings[@]}")
        tui_msg "Sanity Warnings" "${msg}"
    fi
}

tui_quick_install() {
    if ! tui_yesno "Quick Install" "Use a pre-configured profile?"; then
        return 1
    fi

    local profile
    profile=$(tui_menu "Quick Profile" "Select a preset:" \
        "Desktop – KDE, NetworkManager, PipeWire, flatpak" \
        "Server – no desktop, SSH, firewalld, zram" \
        "Minimal – no extras, basic system only" \
        "Embedded – BusyBox init, minimal kernel, no X" \
        "Volk's Personal – dinit, KDE minimal, source-built kernel") || return 1

    case "${profile}" in
        *Desktop*)
            state_set FS_TYPE "ext4"
            state_set BOOTLOADER "grub"
            state_set KERNEL_CHOICE "linux"
            state_set INIT "openrc"
            state_set PRIV_ESCALATION "sudo"
            state_set USE_LUKS "no"
            state_set USE_LVM "no"
            state_set GENERATE_UKI "no"
            state_set ALLOW_OFFLINE "no"
            state_set ENABLE_ARCH_REPOS "yes"
            state_set MICROCODE_OVERRIDE "auto"
            state_set KEEP_BINARY_KERNEL "yes"
            state_set COREUTILS "gnu"
            state_set KERNEL_CONFIG_DEPTH "auto"
            state_set WM_DE "kde"
            state_set KDE_PROFILE "desktop"
            state_set DISPLAY_MANAGER "sddm"
            state_set NETWORK_STACK "networkmanager"
            state_set AUDIO_STACK "pipewire"
            state_set X_STACK "xlibre"
            state_set USER_SHELL "bash"
            state_set EXTRAS "git flatpak fastfetch firewalld bluez zram-tools firefox neovim alacritty fzf zoxide starship eza btop htop tmux mpv"
            ;;
        *Server*)
            state_set FS_TYPE "ext4"
            state_set BOOTLOADER "grub"
            state_set KERNEL_CHOICE "linux"
            state_set INIT "openrc"
            state_set PRIV_ESCALATION "doas"
            state_set USE_LUKS "no"
            state_set USE_LVM "no"
            state_set GENERATE_UKI "no"
            state_set ALLOW_OFFLINE "no"
            state_set ENABLE_ARCH_REPOS "no"
            state_set MICROCODE_OVERRIDE "auto"
            state_set KEEP_BINARY_KERNEL "yes"
            state_set COREUTILS "gnu"
            state_set KERNEL_CONFIG_DEPTH "auto"
            state_set WM_DE "none"
            state_set DISPLAY_MANAGER "none"
            state_set NETWORK_STACK "dhcpcd+iwd"
            state_set AUDIO_STACK "none"
            state_set X_STACK "none"
            state_set USER_SHELL "bash"
            state_set EXTRAS "git firewalld zram-tools tmux"
            ;;
        *Minimal*)
            state_set FS_TYPE "ext4"
            state_set BOOTLOADER "grub"
            state_set KERNEL_CHOICE "linux"
            state_set INIT "openrc"
            state_set PRIV_ESCALATION "doas"
            state_set USE_LUKS "no"
            state_set USE_LVM "no"
            state_set GENERATE_UKI "no"
            state_set ALLOW_OFFLINE "no"
            state_set ENABLE_ARCH_REPOS "no"
            state_set MICROCODE_OVERRIDE "auto"
            state_set KEEP_BINARY_KERNEL "yes"
            state_set COREUTILS "gnu"
            state_set KERNEL_CONFIG_DEPTH "auto"
            state_set WM_DE "none"
            state_set DISPLAY_MANAGER "none"
            state_set NETWORK_STACK "dhcpcd+iwd"
            state_set AUDIO_STACK "none"
            state_set X_STACK "none"
            state_set USER_SHELL "bash"
            state_set EXTRAS ""
            ;;
        *Embedded*)
            state_set FS_TYPE "ext4"
            state_set BOOTLOADER "grub"
            state_set KERNEL_CHOICE "linux-lts"
            state_set INIT "busybox"
            state_set PRIV_ESCALATION "none"
            state_set USE_LUKS "no"
            state_set USE_LVM "no"
            state_set GENERATE_UKI "no"
            state_set ALLOW_OFFLINE "no"
            state_set ENABLE_ARCH_REPOS "no"
            state_set MICROCODE_OVERRIDE "auto"
            state_set POWER_USER "yes"
            state_set KEEP_BINARY_KERNEL "no"
            state_set COREUTILS "busybox"
            state_set KERNEL_CONFIG_DEPTH "auto"
            state_set WM_DE "none"
            state_set DISPLAY_MANAGER "none"
            state_set NETWORK_STACK "none"
            state_set AUDIO_STACK "none"
            state_set X_STACK "none"
            state_set USER_SHELL "bash"
            state_set EXTRAS ""
            ;;
        *Volk*)
            state_set FS_TYPE "ext4"
            state_set BOOTLOADER "grub"
            state_set KERNEL_CHOICE "linux"
            state_set INIT "dinit"
            state_set PRIV_ESCALATION "doas"
            state_set USE_LUKS "no"
            state_set USE_LVM "no"
            state_set GENERATE_UKI "no"
            state_set ALLOW_OFFLINE "no"
            state_set ENABLE_ARCH_REPOS "yes"
            state_set MICROCODE_OVERRIDE "auto"
            state_set POWER_USER "yes"
            state_set KEEP_BINARY_KERNEL "no"
            state_set COREUTILS "gnu"
            state_set KERNEL_CONFIG_DEPTH "auto"
            state_set WM_DE "kde"
            state_set KDE_PROFILE "minimal"
            state_set DISPLAY_MANAGER "lightdm"
            state_set NETWORK_STACK "dhcpcd+iwd"
            state_set AUDIO_STACK "pipewire"
            state_set X_STACK "xlibre"
            state_set USER_SHELL "bash"
            state_set EXTRAS "git fastfetch tmux htop kitty firewalld flatpak"
            ;;
    esac

    tui_select_hostname
    tui_select_timezone
    tui_select_locale
    tui_select_keyboard_layout
    tui_select_username
    tui_select_user_password
    tui_select_root_password

    local summary=""
    summary+="Profile: ${profile}"$'\n\n'
    summary+="Filesystem: $(state_get FS_TYPE ext4)"$'\n'
    summary+="Bootloader: $(state_get BOOTLOADER grub)"$'\n'
    summary+="Kernel: $(state_get KERNEL_CHOICE linux)"$'\n'
    summary+="Init: $(state_get INIT openrc)"$'\n'
    summary+="Desktop: $(state_get WM_DE none)"$'\n'
    summary+="Display Manager: $(state_get DISPLAY_MANAGER none)"$'\n'
    summary+="Network: $(state_get NETWORK_STACK none)"$'\n'
    summary+="Audio: $(state_get AUDIO_STACK none)"$'\n'
    summary+="X Stack: $(state_get X_STACK none)"$'\n'
    summary+="Privilege Escalation: $(state_get PRIV_ESCALATION sudo)"$'\n'
    summary+="LUKS: $(state_get USE_LUKS no)"$'\n'
    summary+="LVM: $(state_get USE_LVM no)"$'\n'
    summary+="UKI: $(state_get GENERATE_UKI no)"$'\n'
    summary+="Extras: $(state_get EXTRAS)"

    if [[ "$(state_get INIT openrc)" == "busybox" ]]; then
        summary+=$'\n'"Power User: yes (BusyBox init, source-built)"$'\n'
    fi

    if ! tui_yesno "Confirm Profile" "${summary}"$'\n\n'"Proceed with this profile?"; then
        return 1
    fi

    if tui_yesno "Customize" "Would you like to customize any settings before installing?"; then
        state_set QUICK_INSTALL "no"
        return 1
    fi

    state_set QUICK_INSTALL "yes"
    return 0
}

tui_select_theme() {
    local theme
    while true; do
        theme=$(tui_menu "Theme" "Select colour scheme:" \
            "Gentoo (default)" \
            "Artix" \
            "Jet Black" \
            "Mono" \
            "Retro") || break
        case "${theme}" in
            "Gentoo (default)")
                GUM_TITLE_COLOR=212; GUM_ACCENT_COLOR=34 ;;
            Artix*)
                GUM_TITLE_COLOR=39; GUM_ACCENT_COLOR=117 ;;
            "Jet Black")
                GUM_TITLE_COLOR=245; GUM_ACCENT_COLOR=196 ;;
            Mono*)
                GUM_TITLE_COLOR=250; GUM_ACCENT_COLOR=255 ;;
            Retro*)
                GUM_TITLE_COLOR=3; GUM_ACCENT_COLOR=11 ;;
        esac

        state_set GUM_TITLE_COLOR "${GUM_TITLE_COLOR}"
        state_set GUM_ACCENT_COLOR "${GUM_ACCENT_COLOR}"

        tui_msg "Theme Preview" "This is how titles and messages will look."
        if tui_yesno "Keep Theme?" "Keep this theme?"; then
            break
        fi
    done
}

tui_collect_install_config() {
    tui_select_theme
    tui_select_disk
    if tui_quick_install; then
        if [[ "$(state_get POWER_USER no)" == "yes" ]]; then
            tui_select_poweruser
        fi
        return
    fi
    tui_select_init
    tui_select_filesystem
    tui_select_btrfs_layout
    tui_select_bootloader
    tui_select_uki
    tui_select_kernel
    tui_select_poweruser
    tui_select_microcode
    tui_select_desktop
    tui_select_display_manager
    tui_select_xstack
    tui_select_network_stack
    tui_select_audio_stack
    tui_select_shell
    tui_select_priv_escalation
    tui_select_extras
    tui_select_luks
    tui_select_arch_repos
    tui_select_offline_mode
    tui_select_hostname
    tui_select_timezone
    tui_select_locale
    tui_select_keyboard_layout
    tui_select_username
    tui_select_user_password
    tui_select_root_password
    tui_show_sanity_warnings
}