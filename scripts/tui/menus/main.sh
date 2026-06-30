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

tui_partition_setup() {
    local disk
    disk="$(state_get DISK)"
    [[ -b "${disk}" ]] || die "No disk selected"

    if tui_yesno "Partition Scheme" "Use the entire disk ${disk}?"; then
        if tui_yesno "Swap" "Create a swap partition?"; then
            local mem_gib
            mem_gib=$(awk '/MemTotal/ {printf "%d", ($2 / 1024 / 1024) + 1}' /proc/meminfo)
            local default_swap
            if   [[ "${mem_gib}" -le 8 ]]; then default_swap='4G'
            elif [[ "${mem_gib}" -le 16 ]]; then default_swap='8G'
            else default_swap='16G'; fi
            local swap_size
            swap_size=$(tui_input "Swap Size" "Recommended: ${default_swap}" "${default_swap}") || die "Swap size required"
            state_set SWAP_ENABLED "yes"
            state_set SWAP_SIZE "${swap_size}"
        else
            state_set SWAP_ENABLED "no"
            state_set SWAP_SIZE "0"
        fi
        state_set EFI_PART ""
        state_set ROOT_PART ""
        state_set SWAP_PART ""
        return 0
    fi

    local -a parts=()
    while IFS= read -r line; do
        parts+=("$line")
    done < <(lsblk -nlo NAME,SIZE,TYPE,MOUNTPOINT "${disk}" | grep -E 'part' || true)

    if [[ ${#parts[@]} -eq 0 ]]; then
        if tui_yesno "No Partitions" "No partitions found on ${disk}. Launch cfdisk?"; then
            cfdisk "${disk}"
            partprobe "${disk}"
            udevadm settle
            sleep 1
            while IFS= read -r line; do
                parts+=("$line")
            done < <(lsblk -nlo NAME,SIZE,TYPE,MOUNTPOINT "${disk}" | grep -E 'part' || true)
            if [[ ${#parts[@]} -eq 0 ]]; then
                die "Still no partitions found after cfdisk. Cannot continue."
            fi
        else
            die "Cannot continue without partitions"
        fi
    fi

    local efi_choice
    efi_choice=$(printf '%s\n' "${parts[@]}" | tui_menu "EFI Partition" "Select EFI system partition (≥512 MiB):") || die "EFI partition required"
    local efi_part="/dev/$(echo "${efi_choice}" | awk '{print $1}')"
    state_set EFI_PART "${efi_part}"

    local -a root_candidates=()
    for part in "${parts[@]}"; do
        [[ "/dev/$(echo "${part}" | awk '{print $1}')" != "${efi_part}" ]] && root_candidates+=("${part}")
    done
    if [[ ${#root_candidates[@]} -eq 0 ]]; then
        die "No partitions available for root (only EFI found). Create more partitions."
    fi
    local root_choice
    root_choice=$(printf '%s\n' "${root_candidates[@]}" | tui_menu "Root Partition" "Select root partition:") || die "Root partition required"
    state_set ROOT_PART "/dev/$(echo "${root_choice}" | awk '{print $1}')"

    if tui_yesno "Swap" "Do you have a swap partition?"; then
        local swap_choice
        swap_choice=$(printf '%s\n' "${parts[@]}" | tui_menu "Swap Partition" "Select swap partition:") || true
        if [[ -n "${swap_choice}" ]]; then
            state_set SWAP_PART "/dev/$(echo "${swap_choice}" | awk '{print $1}')"
            state_set SWAP_ENABLED "yes"
            state_set SWAP_SIZE "0"
        else
            state_set SWAP_ENABLED "no"
            state_set SWAP_SIZE "0"
        fi
    else
        state_set SWAP_ENABLED "no"
        state_set SWAP_SIZE "0"
    fi
}

tui_select_init() {
    local init
    init=$(tui_menu "Init System" "Select init system:" \
        "OpenRC" "runit" "dinit" "s6") || return 1
    state_set INIT "${init,,}"
}

tui_select_filesystem() {
    local fs
    local fs_options=("ext4" "btrfs" "xfs" "f2fs")
    fs=$(tui_menu "Filesystem" "Select filesystem:" "${fs_options[@]}") || return 1
    state_set FS_TYPE "${fs}"
}

tui_select_bootloader() {
    local bl
    if [[ "${ARTIX_BOOT_MODE:-uefi}" == "bios" ]]; then
        bl="grub"
        tui_msg_quick "BIOS Bootloader" "BIOS/Legacy boot detected. Only GRUB is supported."
    else
        bl=$(tui_menu "Bootloader" "Select bootloader:" \
            "GRUB" "rEFInd" "EFIStub" "Limine") || return 1
        bl="${bl,,}"
    fi
    state_set BOOTLOADER "${bl}"
}

tui_select_uki() {
    if [[ "${ARTIX_BOOT_MODE:-uefi}" == "bios" ]]; then
        state_set GENERATE_UKI "no"
        return 0
    fi
    if tui_yesno "UKI" "Generate a Unified Kernel Image (UKI)?"; then
        state_set GENERATE_UKI "yes"
    else
        state_set GENERATE_UKI "no"
    fi
}

tui_select_kernel() {
    local k
    k=$(tui_menu "Kernel" "Select kernel:" \
        "linux-* (standard)" "linux-cachyos-*" "linux-bazzite-bin" "xanmod" "tkg" \
        "linux-libre") || return 1

    case "${k}" in
        "linux-* (standard)")
            local variant
            variant=$(tui_menu "Standard Kernel" "Select variant:" \
                "linux" "linux-zen" "linux-lts" "linux-hardened") || return 1
            state_set KERNEL_CHOICE "${variant}"
            ;;
        "linux-cachyos-*")
            local variant
            variant=$(tui_menu "CachyOS Kernel" "Select variant:" \
                "linux-cachyos (EEVDF)" "linux-cachyos-bore (BORE)" \
                "linux-cachyos-eevdf" "linux-cachyos-bmq (BMQ)" \
                "linux-cachyos-rt-bore (RT + BORE)" "linux-cachyos-hardened (BORE + hardening)" \
                "linux-cachyos-lts (EEVDF, long-term)" "linux-cachyos-server (EEVDF, server)" \
                "linux-cachyos-deckify (BORE, Steam Deck)") || return 1
            variant="${variant%% *}"
            state_set KERNEL_CHOICE "${variant}"
            ;;
        *) state_set KERNEL_CHOICE "${k}" ;;
    esac
}

tui_select_theme() {
    local theme
    while true; do
        theme=$(tui_menu "Theme" "Select colour scheme:" \
            "Forge (default)" "Artix" "Jet Black" "Mono" "Retro") || break
        case "${theme}" in
            "Forge (default)") GUM_TITLE_COLOR=212; GUM_ACCENT_COLOR=34 ;;
            Artix*)            GUM_TITLE_COLOR=39;  GUM_ACCENT_COLOR=117 ;;
            "Jet Black")       GUM_TITLE_COLOR=245; GUM_ACCENT_COLOR=196 ;;
            Mono*)             GUM_TITLE_COLOR=250; GUM_ACCENT_COLOR=255 ;;
            Retro*)            GUM_TITLE_COLOR=3;   GUM_ACCENT_COLOR=11 ;;
        esac
        state_set GUM_TITLE_COLOR "${GUM_TITLE_COLOR}"
        state_set GUM_ACCENT_COLOR "${GUM_ACCENT_COLOR}"
        tui_msg "Theme Preview" "This is how titles and messages will look."
        if tui_yesno "Keep Theme?" "Keep this theme?"; then break; fi
    done
}

_submenu_disk() {
    while true; do
        local choice
        choice=$(tui_menu "Disk & Storage" "Configure disk and filesystem:" \
            "Target disk        [$(state_get DISK none)]" \
            "Partition scheme   [$(if [[ -n "$(state_get EFI_PART '')" ]]; then echo manual; else echo whole-disk; fi)]" \
            "Filesystem         [$(state_get FS_TYPE ext4)]" \
            "$(if [[ "$(state_get FS_TYPE ext4)" == "btrfs" ]]; then echo "BTRFS layout       [$(state_get BTRFS_LAYOUT standard)]"; fi)" \
            "Swap               [$(state_get SWAP_ENABLED no), $(state_get SWAP_SIZE 0)]" \
            "LUKS encryption    [$(state_get USE_LUKS no)]" \
            "LVM                [$(state_get USE_LVM no)]" \
            "Back") || return
        case "${choice}" in
            "Target disk"*)        tui_select_disk ;;
            "Partition scheme"*)   tui_partition_setup ;;
            "Filesystem"*)         tui_select_filesystem ;;
            "BTRFS layout"*)       tui_select_btrfs_layout ;;
            "Swap"*)               tui_partition_setup ;;
            "LUKS encryption"*)    tui_select_luks ;;
            "LVM"*)                tui_select_luks ;;
            Back*) return ;;
        esac
    done
}

_submenu_bootloader() {
    while true; do
        local choice
        choice=$(tui_menu "Bootloader" "Configure bootloader:" \
            "Bootloader         [$(state_get BOOTLOADER grub)]" \
            "UKI                [$(state_get GENERATE_UKI no)]" \
            "Back") || return
        case "${choice}" in
            "Bootloader"*) tui_select_bootloader ;;
            "UKI"*)        tui_select_uki ;;
            Back*) return ;;
        esac
    done
}

_submenu_kernel() {
    while true; do
        local choice
        choice=$(tui_menu "Kernel & Microcode" "Configure kernel:" \
            "Kernel             [$(state_get KERNEL_CHOICE linux)]" \
            "Microcode          [$(state_get MICROCODE_OVERRIDE auto)]" \
            "Back") || return
        case "${choice}" in
            "Kernel"*)    tui_select_kernel ;;
            "Microcode"*) tui_select_microcode ;;
            Back*) return ;;
        esac
    done
}

_submenu_init() {
    while true; do
        local choice
        choice=$(tui_menu "Init System" "Configure init system:" \
            "Init system        [$(state_get INIT openrc)]" \
            "Back") || return
        case "${choice}" in
            "Init system"*) tui_select_init ;;
            Back*) return ;;
        esac
    done
}

_submenu_desktop() {
    while true; do
        local choice
        choice=$(tui_menu "Desktop" "Configure desktop environment:" \
            "Desktop / WM       [$(state_get WM_DE none)]" \
            "Display Manager    [$(state_get DISPLAY_MANAGER none)]" \
            "Display Stack      [$(state_get X_STACK xorg)]" \
            "Back") || return
        case "${choice}" in
            "Desktop / WM"*)    tui_select_desktop ;;
            "Display Manager"*) tui_select_display_manager ;;
            "Display Stack"*)   tui_select_xstack ;;
            Back*) return ;;
        esac
    done
}

_submenu_network_audio() {
    while true; do
        local choice
        choice=$(tui_menu "Network & Audio" "Configure network and audio:" \
            "Network stack      [$(state_get NETWORK_STACK networkmanager)]" \
            "Audio stack        [$(state_get AUDIO_STACK pipewire)]" \
            "Back") || return
        case "${choice}" in
            "Network stack"*) tui_select_network_stack ;;
            "Audio stack"*)   tui_select_audio_stack ;;
            Back*) return ;;
        esac
    done
}

_submenu_users() {
    while true; do
        local choice
        choice=$(tui_menu "Users & Privilege" "Configure users:" \
            "User accounts      [$(state_get USER_COUNT 1) user(s)]" \
            "Root password      [$(if [[ -n "$(state_get ROOT_PASS '')" ]]; then echo set; else echo not set; fi)]" \
            "Privilege escalation [$(state_get PRIV_ESCALATION sudo)]" \
            "User shell         [$(state_get USER_SHELL bash)]" \
            "Back") || return
        case "${choice}" in
            "User accounts"*)       tui_configure_users ;;
            "Root password"*)       tui_select_root_password ;;
            "Privilege escalation"*) tui_select_priv_escalation ;;
            "User shell"*)          tui_select_shell ;;
            Back*) return ;;
        esac
    done
}

_submenu_extras() {
    while true; do
        local choice
        choice=$(tui_menu "Extras & Repositories" "Configure extras:" \
            "Extra packages     [$(state_get EXTRAS)]" \
            "Arch repositories  [$(state_get ENABLE_ARCH_REPOS no)]" \
            "AURIS              [$(state_get ENABLE_AURIS no)]" \
            "Offline mode       [$(state_get ALLOW_OFFLINE no)]" \
            "Power User mode    [$(state_get POWER_USER no)]" \
            "Back") || return
        case "${choice}" in
            "Extra packages"*)     tui_select_extras ;;
            "Arch repositories"*)  tui_select_arch_repos ;;
            "AURIS"*)              tui_select_auris ;;
            "Offline mode"*)       tui_select_offline_mode ;;
            "Power User mode"*)    tui_select_poweruser ;;
            Back*) return ;;
        esac
    done
}

_submenu_identity() {
    while true; do
        local choice
        choice=$(tui_menu "System Identity" "Configure system identity:" \
            "Hostname           [$(state_get HOSTNAME artix)]" \
            "Timezone           [$(state_get TIMEZONE Europe/Belgrade)]" \
            "Locale             [$(state_get LOCALE en_US.UTF-8)]" \
            "Keyboard layout    [$(state_get KEYMAP us)]" \
            "Back") || return
        case "${choice}" in
            "Hostname"*)        tui_select_hostname ;;
            "Timezone"*)        tui_select_timezone ;;
            "Locale"*)          tui_select_locale ;;
            "Keyboard layout"*) tui_select_keyboard_layout ;;
            Back*) return ;;
        esac
    done
}

tui_collect_install_config() {
    if [[ "${ARTIX_BOOT_MODE:-uefi}" == "bios" ]]; then
        tui_msg_quick "BIOS Mode" "Legacy BIOS boot detected. UEFI features (UKI, EFIStub, rEFInd, Limine) are disabled."
    fi
    tui_select_theme

    state_set DISK "${DISK:-$(state_get DISK '')}"
    state_set FS_TYPE "${FS_TYPE:-ext4}"
    state_set BOOTLOADER "${BOOTLOADER:-grub}"
    state_set KERNEL_CHOICE "${KERNEL_CHOICE:-linux}"
    state_set INIT "${INIT:-openrc}"
    state_set WM_DE "${WM_DE:-none}"
    state_set NETWORK_STACK "${NETWORK_STACK:-networkmanager}"
    state_set AUDIO_STACK "${AUDIO_STACK:-pipewire}"
    state_set PRIV_ESCALATION "${PRIV_ESCALATION:-sudo}"
    state_set HOSTNAME "${HOSTNAME:-artix}"
    state_set TIMEZONE "${TIMEZONE:-Europe/Belgrade}"
    state_set LOCALE "${LOCALE:-en_US.UTF-8}"
    state_set KEYMAP "${KEYMAP:-us}"
    state_set USER_COUNT "${USER_COUNT:-0}"

    if [[ -z "$(state_get DISK '')" ]]; then
        tui_select_disk
        tui_partition_setup
    fi

    while true; do
        local choice
        choice=$(tui_menu "ArtixForge Configuration" "Select a category to configure, or proceed:" \
            "Disk & Storage      [fs: $(state_get FS_TYPE ext4), swap: $(state_get SWAP_ENABLED no)]" \
            "Bootloader          [$(state_get BOOTLOADER grub), UKI: $(state_get GENERATE_UKI no)]" \
            "Kernel & Microcode  [$(state_get KERNEL_CHOICE linux)]" \
            "Init System         [$(state_get INIT openrc)]" \
            "Desktop             [$(state_get WM_DE none), dm: $(state_get DISPLAY_MANAGER none)]" \
            "Network & Audio     [net: $(state_get NETWORK_STACK networkmanager), aud: $(state_get AUDIO_STACK pipewire)]" \
            "Users & Privilege   [$(state_get USER_COUNT 0) user(s), priv: $(state_get PRIV_ESCALATION sudo)]" \
            "Extras & Repos      [arch: $(state_get ENABLE_ARCH_REPOS no), pw: $(state_get POWER_USER no)]" \
            "System Identity     [host: $(state_get HOSTNAME artix)]" \
            "▸ Quick Profile" \
            "▸ Proceed with installation" \
            "▸ View summary") || { tui_msg_quick "Cancelled" "Installation cancelled."; exit 0; }

        case "${choice}" in
            "Disk & Storage"*)      _submenu_disk ;;
            "Bootloader"*)          _submenu_bootloader ;;
            "Kernel & Microcode"*)  _submenu_kernel ;;
            "Init System"*)         _submenu_init ;;
            "Desktop"*)             _submenu_desktop ;;
            "Network & Audio"*)     _submenu_network_audio ;;
            "Users & Privilege"*)   _submenu_users ;;
            "Extras & Repos"*)      _submenu_extras ;;
            "System Identity"*)     _submenu_identity ;;
            "▸ Quick Profile"*)
                if tui_quick_install; then
                    if [[ "$(state_get POWER_USER no)" == "yes" ]]; then
                        tui_select_poweruser
                    fi
                    tui_show_sanity_warnings
                    return 0
                fi
                ;;
            "▸ Proceed with installation"*)
                if [[ -z "$(state_get DISK '')" ]]; then
                    tui_msg_quick "Disk Required" "Please select a target disk before proceeding."
                    continue
                fi
                if [[ "$(state_get USER_COUNT 0)" -eq 0 ]]; then
                    tui_msg_quick "Users Required" "Please create at least one user account."
                    tui_configure_users
                fi
                tui_show_sanity_warnings
                return 0
                ;;
            "▸ View summary"*)
                local summary
                printf -v summary \
                    "Disk: %s\nFilesystem: %s\nBootloader: %s\nUKI: %s\nKernel: %s\nInit: %s\nDesktop: %s\nDisplay Manager: %s\nNetwork: %s\nAudio: %s\nX Stack: %s\nLUKS: %s\nLVM: %s\nHostname: %s\nTimezone: %s\nLocale: %s\nKeymap: %s\nPrivilege: %s\nArch Repos: %s\nPower User: %s\nExtras: %s" \
                    "$(state_get DISK)" "$(state_get FS_TYPE)" "$(state_get BOOTLOADER)" \
                    "$(state_get GENERATE_UKI)" "$(state_get KERNEL_CHOICE)" "$(state_get INIT)" \
                    "$(state_get WM_DE)" "$(state_get DISPLAY_MANAGER)" "$(state_get NETWORK_STACK)" \
                    "$(state_get AUDIO_STACK)" "$(state_get X_STACK)" "$(state_get USE_LUKS)" \
                    "$(state_get USE_LVM)" "$(state_get HOSTNAME)" "$(state_get TIMEZONE)" \
                    "$(state_get LOCALE)" "$(state_get KEYMAP)" "$(state_get PRIV_ESCALATION)" \
                    "$(state_get ENABLE_ARCH_REPOS)" "$(state_get POWER_USER)" "$(state_get EXTRAS)"
                tui_msg "Installation Summary" "${summary}"
                tui_show_sanity_warnings
                ;;
        esac
    done
}