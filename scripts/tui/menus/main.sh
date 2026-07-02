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
    efi_choice=$(printf '%s\n' "${parts[@]}" | tui_menu "EFI Partition" "Select EFI system partition (>=512 MiB):") || die "EFI partition required"
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

tui_configure_swap() {
    if tui_yesno "Swap" "Create or change swap?"; then
        if [[ -n "$(state_get EFI_PART '')" ]]; then
            local disk
            disk="$(state_get DISK)"
            local -a parts=()
            while IFS= read -r line; do
                parts+=("$line")
            done < <(lsblk -nlo NAME,SIZE,TYPE,MOUNTPOINT "${disk}" | grep -E 'part' || true)
            local swap_choice
            swap_choice=$(printf '%s\n' "${parts[@]}" | tui_menu "Swap Partition" "Select swap partition:") || true
            if [[ -n "${swap_choice}" ]]; then
                state_set SWAP_PART "/dev/$(echo "${swap_choice}" | awk '{print $1}')"
                state_set SWAP_ENABLED "yes"
            else
                state_set SWAP_ENABLED "no"
            fi
        else
            local mem_gib default_swap swap_size
            mem_gib=$(awk '/MemTotal/ {printf "%d", ($2 / 1024 / 1024) + 1}' /proc/meminfo)
            if   [[ "${mem_gib}" -le 8 ]]; then default_swap='4G'
            elif [[ "${mem_gib}" -le 16 ]]; then default_swap='8G'
            else default_swap='16G'; fi
            swap_size=$(tui_input "Swap Size" "Recommended: ${default_swap}" "${default_swap}") || return
            state_set SWAP_ENABLED "yes"
            state_set SWAP_SIZE "${swap_size}"
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

_tkg_source_config() {
    local sched
    sched="$(state_get TKG_SCHEDULER eevdf)"

    local compiler
    compiler=$(tui_menu "TKG Compiler" "Select compiler:" "gcc" "llvm") || compiler="gcc"
    state_set TKG_COMPILER "${compiler}"

    local optlevel
    optlevel=$(tui_menu "TKG Optimization" "Compiler optimization level:" "1 (O2)" "2 (O3)" "3 (Os)") || optlevel="1"
    state_set TKG_OPTLEVEL "${optlevel%% *}"

    local cpu_opt
    cpu_opt=$(tui_input "TKG CPU Target" "CPU architecture (-march=):" "native") || cpu_opt="native"
    state_set TKG_PROCESSOR_OPT "${cpu_opt}"

    local lto_mode="no"
    if [[ "${compiler}" == "llvm" ]]; then
        lto_mode=$(tui_menu "TKG LTO Mode" "Link-Time Optimization:" "no" "full" "thin") || lto_mode="no"
    fi
    state_set TKG_LTO_MODE "${lto_mode}"

    if tui_yesno "TKG PREEMPT_RT" "Apply PREEMPT_RT patchset?"; then state_set TKG_PREEMPT_RT "1"; else state_set TKG_PREEMPT_RT "0"; fi

    local tickless
    tickless=$(tui_menu "TKG Tickless" "Tickless mode:" "0 (periodic)" "1 (full tickless)" "2 (idle only)") || tickless="2"
    state_set TKG_TICKLESS "${tickless%% *}"

    local timer_freq
    timer_freq=$(tui_menu "TKG Timer Freq" "Timer frequency (Hz):" "100" "250" "300" "500" "750" "1000") || timer_freq="1000"
    state_set TKG_TIMER_FREQ "${timer_freq}"

    local cpu_gov
    cpu_gov=$(tui_menu "TKG CPU Governor" "Default CPU governor:" "schedutil" "performance" "ondemand") || cpu_gov="ondemand"
    state_set TKG_CPU_GOV "${cpu_gov}"

    tui_msg_quick "TKG Patches" "glitched_base  = Zen/Xanmod base tweaks
zenify         = Zenify patches (depends on glitched base)
clear_patches  = Clear Linux patches
openrgb        = OpenRGB support
acs_override   = ACS override
fsync          = Fsync support
mglru          = MGLRU
ntsync         = NTsync"

    local -a tkg_patches=(
        "glitched_base"
        "zenify"
        "clear_patches"
        "openrgb"
        "acs_override"
        "fsync"
        "mglru"
        "ntsync"
    )

    state_set TKG_GLITCHED_BASE "false"
    state_set TKG_ZENIFY "false"
    state_set TKG_CLEAR_PATCHES "false"
    state_set TKG_OPENRGB "false"
    state_set TKG_ACS_OVERRIDE "false"
    state_set TKG_FSYNC "false"
    state_set TKG_MGLRU "false"
    state_set TKG_NTSYNC "false"

    local selected
    selected=$(tui_multiselect "TKG Patches" "Select patches to apply:" "Search patches..." 0 0 "${tkg_patches[@]}")

    if [[ "${selected}" =~ "glitched_base" ]]; then state_set TKG_GLITCHED_BASE "true"; fi
    if [[ "${selected}" =~ "zenify" ]]; then state_set TKG_ZENIFY "true"; fi
    if [[ "${selected}" =~ "clear_patches" ]]; then state_set TKG_CLEAR_PATCHES "true"; fi
    if [[ "${selected}" =~ "openrgb" ]]; then state_set TKG_OPENRGB "true"; fi
    if [[ "${selected}" =~ "acs_override" ]]; then state_set TKG_ACS_OVERRIDE "true"; fi
    if [[ "${selected}" =~ "fsync" ]]; then state_set TKG_FSYNC "true"; fi
    if [[ "${selected}" =~ "mglru" ]]; then state_set TKG_MGLRU "true"; fi
    if [[ "${selected}" =~ "ntsync" ]]; then state_set TKG_NTSYNC "true"; fi

    local nr_cpus
    nr_cpus=$(tui_input "TKG NR_CPUS" "Max CPU count:" "$(nproc)") || nr_cpus="$(nproc)"
    state_set TKG_NR_CPUS "${nr_cpus}"

    if tui_yesno "TKG Review Config" "Review full configuration file before building?"; then
        local tmp_cfg="/tmp/tkg-customization.cfg"
        _tkg_write_config "${tmp_cfg}"
        tui_edit "TKG customization.cfg" "${tmp_cfg}"
        rm -f "${tmp_cfg}"
    fi
}

_tkg_write_config() {
    local out="${1}"
    local sched="${TKG_SCHEDULER:-eevdf}"
    cat > "${out}" <<EOF
_distro="Arch"
_cpusched="${sched}"
_compiler="$(state_get TKG_COMPILER gcc)"
_compileroptlevel="$(state_get TKG_OPTLEVEL 1)"
_processor_opt="$(state_get TKG_PROCESSOR_OPT native)"
_lto_mode="$(state_get TKG_LTO_MODE no)"
_preempt_rt="$(state_get TKG_PREEMPT_RT 0)"
_tickless="$(state_get TKG_TICKLESS 2)"
_timer_freq="$(state_get TKG_TIMER_FREQ 1000)"
_default_cpu_gov="$(state_get TKG_CPU_GOV ondemand)"
_glitched_base="$(state_get TKG_GLITCHED_BASE true)"
_zenify="$(state_get TKG_ZENIFY true)"
_clear_patches="$(state_get TKG_CLEAR_PATCHES true)"
_openrgb="$(state_get TKG_OPENRGB true)"
_acs_override="$(state_get TKG_ACS_OVERRIDE false)"
_fsync_backport="$(state_get TKG_FSYNC true)"
_mglru="$(state_get TKG_MGLRU true)"
_ntsync="$(state_get TKG_NTSYNC false)"
_NR_CPUS_value="$(state_get TKG_NR_CPUS $(nproc))"
_user_patches="true"
_user_patches_no_confirm="false"
_config_fragments="true"
_config_fragments_no_confirm="false"
EOF
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
        tkg)
            local tkg_sched
            tkg_sched=$(tui_menu "TKG Scheduler" "Select CPU scheduler:" \
                "eevdf (default)" "bmq" "bore" "pds") || return 1
            tkg_sched="${tkg_sched%% *}"
            state_set TKG_SCHEDULER "${tkg_sched}"
            state_set KERNEL_CHOICE "tkg"

            if tui_yesno "TKG Build" "Use prebuilt binary from GitHub releases?\n\nYes = download binary (~50MB)\nNo  = compile from source (~30 min, full customization)"; then
                state_set TKG_BINARY "yes"
            else
                state_set TKG_BINARY "no"
                _tkg_source_config
            fi
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
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("Target disk        [$(state_get DISK none)]")
            if [[ -n "$(state_get EFI_PART '')" ]]; then
                items+=("Partition scheme   [manual]")
            else
                items+=("Partition scheme   [whole-disk]")
            fi
            items+=("Filesystem         [$(state_get FS_TYPE ext4)]")
            [[ "$(state_get FS_TYPE ext4)" == "btrfs" ]] && items+=("BTRFS layout       [$(state_get BTRFS_LAYOUT standard)]")
            items+=("Swap               [$(state_get SWAP_ENABLED no), $(state_get SWAP_SIZE 0)]")
            items+=("LUKS encryption    [$(state_get USE_LUKS no)]")
            items+=("LVM                [$(state_get USE_LVM no)]")
            items+=("Back")
            submenu_dirty=0
        fi

        local choice
        choice=$(tui_menu "Disk & Storage" "Configure disk and filesystem:" "${items[@]}") || return
        case "${choice}" in
            "Target disk"*)        tui_select_disk ; submenu_dirty=1 ;;
            "Partition scheme"*)   tui_partition_setup ; submenu_dirty=1 ;;
            "Filesystem"*)         tui_select_filesystem ; submenu_dirty=1 ;;
            "BTRFS layout"*)       tui_select_btrfs_layout ; submenu_dirty=1 ;;
            "Swap"*)               tui_configure_swap ; submenu_dirty=1 ;;
            "LUKS encryption"*)    tui_toggle_luks || true ; submenu_dirty=1 ;;
            "LVM"*)                tui_toggle_lvm ; submenu_dirty=1 ;;
            Back*) return ;;
        esac
    done
}

_submenu_bootloader() {
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("Bootloader         [$(state_get BOOTLOADER grub)]")
            items+=("UKI                [$(state_get GENERATE_UKI no)]")
            items+=("Back")
            submenu_dirty=0
        fi
        local choice
        choice=$(tui_menu "Bootloader" "Configure bootloader:" "${items[@]}") || return
        case "${choice}" in
            "Bootloader"*) tui_select_bootloader ; submenu_dirty=1 ;;
            "UKI"*)        tui_select_uki ; submenu_dirty=1 ;;
            Back*) return ;;
        esac
    done
}

_submenu_kernel() {
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("Kernel             [$(state_get KERNEL_CHOICE linux)]")
            items+=("Microcode          [$(state_get MICROCODE_OVERRIDE auto)]")
            items+=("Back")
            submenu_dirty=0
        fi
        local choice
        choice=$(tui_menu "Kernel & Microcode" "Configure kernel:" "${items[@]}") || return
        case "${choice}" in
            "Kernel"*)    tui_select_kernel || true ; submenu_dirty=1 ;;
            "Microcode"*) tui_select_microcode || true ; submenu_dirty=1 ;;
            Back*) return ;;
        esac
    done
}

_submenu_init() {
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("Init system        [$(state_get INIT openrc)]")
            items+=("Back")
            submenu_dirty=0
        fi
        local choice
        choice=$(tui_menu "Init System" "Configure init system:" "${items[@]}") || return
        case "${choice}" in
            "Init system"*) tui_select_init || true ; submenu_dirty=1 ;;
            Back*) return ;;
        esac
    done
}

_submenu_desktop() {
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("Desktop / WM       [$(state_get WM_DE none)]")
            items+=("Display Manager    [$(state_get DISPLAY_MANAGER none)]")
            items+=("Display Stack      [$(state_get X_STACK xorg)]")
            items+=("Back")
            submenu_dirty=0
        fi
        local choice
        choice=$(tui_menu "Desktop" "Configure desktop environment:" "${items[@]}") || return
        case "${choice}" in
            "Desktop / WM"*)    tui_select_desktop || true ; submenu_dirty=1 ;;
            "Display Manager"*) tui_select_display_manager || true ; submenu_dirty=1 ;;
            "Display Stack"*)   tui_select_xstack || true ; submenu_dirty=1 ;;
            Back*) return ;;
        esac
    done
}

_submenu_network_audio() {
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("Network stack      [$(state_get NETWORK_STACK networkmanager)]")
            items+=("Audio stack        [$(state_get AUDIO_STACK pipewire)]")
            items+=("Back")
            submenu_dirty=0
        fi
        local choice
        choice=$(tui_menu "Network & Audio" "Configure network and audio:" "${items[@]}") || return
        case "${choice}" in
            "Network stack"*) tui_select_network_stack || true ; submenu_dirty=1 ;;
            "Audio stack"*)   tui_select_audio_stack || true ; submenu_dirty=1 ;;
            Back*) return ;;
        esac
    done
}

_submenu_users() {
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("User accounts      [$(state_get USER_COUNT 1) user(s)]")
            local root_label="not set"
            [[ -n "$(state_get ROOT_PASS '')" ]] && root_label="set"
            items+=("Root password      [${root_label}]")
            items+=("Privilege escalation [$(state_get PRIV_ESCALATION sudo)]")
            items+=("User shell         [$(state_get USER_SHELL bash)]")
            items+=("Back")
            submenu_dirty=0
        fi
        local choice
        choice=$(tui_menu "Users & Privilege" "Configure users:" "${items[@]}") || return
        case "${choice}" in
            "User accounts"*)       tui_configure_users || true ; submenu_dirty=1 ;;
            "Root password"*)       tui_select_root_password || true ; submenu_dirty=1 ;;
            "Privilege escalation"*) tui_select_priv_escalation || true ; submenu_dirty=1 ;;
            "User shell"*)          tui_select_shell || true ; submenu_dirty=1 ;;
            Back*) return ;;
        esac
    done
}

_submenu_extras() {
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("Extra packages     [$(state_get EXTRAS)]")
            items+=("Arch repositories  [$(state_get ENABLE_ARCH_REPOS no)]")
            items+=("AURIS              [$(state_get ENABLE_AURIS no)]")
            items+=("Offline mode       [$(state_get ALLOW_OFFLINE no)]")
            items+=("Power User mode    [$(state_get POWER_USER no)]")
            items+=("Back")
            submenu_dirty=0
        fi
        local choice
        choice=$(tui_menu "Extras & Repositories" "Configure extras:" "${items[@]}") || return
        case "${choice}" in
            "Extra packages"*)     tui_select_extras || true ; submenu_dirty=1 ;;
            "Arch repositories"*)  tui_select_arch_repos || true ; submenu_dirty=1 ;;
            "AURIS"*)              tui_select_auris || true ; submenu_dirty=1 ;;
            "Offline mode"*)       tui_select_offline_mode || true ; submenu_dirty=1 ;;
            "Power User mode"*)    tui_select_poweruser || true ; submenu_dirty=1 ;;
            Back*) return ;;
        esac
    done
}

_submenu_identity() {
    local -a items=()
    local submenu_dirty=1
    while true; do
        if [[ $submenu_dirty -eq 1 ]]; then
            items=()
            items+=("Hostname           [$(state_get HOSTNAME artix)]")
            items+=("Timezone           [$(state_get TIMEZONE Europe/Belgrade)]")
            items+=("Locale             [$(state_get LOCALE en_US.UTF-8)]")
            items+=("Keyboard layout    [$(state_get KEYMAP us)]")
            items+=("Back")
            submenu_dirty=0
        fi
        local choice
        choice=$(tui_menu "System Identity" "Configure system identity:" "${items[@]}") || return
        case "${choice}" in
            "Hostname"*)        tui_select_hostname || true ; submenu_dirty=1 ;;
            "Timezone"*)        tui_select_timezone || true ; submenu_dirty=1 ;;
            "Locale"*)          tui_select_locale || true ; submenu_dirty=1 ;;
            "Keyboard layout"*) tui_select_keyboard_layout || true ; submenu_dirty=1 ;;
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

    local -a hub_items=()
    local hub_dirty=1
    local cached_summary=""

    _rebuild_hub() {
        hub_items=()
        hub_items+=("Disk & Storage      [fs: $(state_get FS_TYPE ext4), swap: $(state_get SWAP_ENABLED no)]")
        hub_items+=("Bootloader          [$(state_get BOOTLOADER grub), UKI: $(state_get GENERATE_UKI no)]")
        hub_items+=("Kernel & Microcode  [$(state_get KERNEL_CHOICE linux)]")
        hub_items+=("Init System         [$(state_get INIT openrc)]")
        hub_items+=("Desktop             [$(state_get WM_DE none), dm: $(state_get DISPLAY_MANAGER none)]")
        hub_items+=("Network & Audio     [net: $(state_get NETWORK_STACK networkmanager), aud: $(state_get AUDIO_STACK pipewire)]")
        hub_items+=("Users & Privilege   [$(state_get USER_COUNT 0) user(s), priv: $(state_get PRIV_ESCALATION sudo)]")
        hub_items+=("Extras & Repos      [arch: $(state_get ENABLE_ARCH_REPOS no), pw: $(state_get POWER_USER no)]")
        hub_items+=("System Identity     [host: $(state_get HOSTNAME artix)]")
        hub_items+=("▸ Quick Profile")
        hub_items+=("▸ Proceed with installation")
        hub_items+=("▸ View summary")
        hub_dirty=0

        printf -v cached_summary \
            "Disk: %s\nFilesystem: %s\nBootloader: %s\nUKI: %s\nKernel: %s\nInit: %s\nDesktop: %s\nDisplay Manager: %s\nNetwork: %s\nAudio: %s\nX Stack: %s\nLUKS: %s\nLVM: %s\nHostname: %s\nTimezone: %s\nLocale: %s\nKeymap: %s\nPrivilege: %s\nArch Repos: %s\nPower User: %s\nExtras: %s" \
            "$(state_get DISK)" "$(state_get FS_TYPE)" "$(state_get BOOTLOADER)" \
            "$(state_get GENERATE_UKI)" "$(state_get KERNEL_CHOICE)" "$(state_get INIT)" \
            "$(state_get WM_DE)" "$(state_get DISPLAY_MANAGER)" "$(state_get NETWORK_STACK)" \
            "$(state_get AUDIO_STACK)" "$(state_get X_STACK)" "$(state_get USE_LUKS)" \
            "$(state_get USE_LVM)" "$(state_get HOSTNAME)" "$(state_get TIMEZONE)" \
            "$(state_get LOCALE)" "$(state_get KEYMAP)" "$(state_get PRIV_ESCALATION)" \
            "$(state_get ENABLE_ARCH_REPOS)" "$(state_get POWER_USER)" "$(state_get EXTRAS)"
    }

    while true; do
        [[ $hub_dirty -eq 1 ]] && _rebuild_hub

        local choice
        choice=$(tui_menu "ArtixForge Configuration" "Select a category to configure, or proceed:" "${hub_items[@]}") || {
            tui_msg_quick "Cancelled" "Installation cancelled."
            exit 0
        }

        case "${choice}" in
            "Disk & Storage"*)      _submenu_disk ; hub_dirty=1 ;;
            "Bootloader"*)          _submenu_bootloader ; hub_dirty=1 ;;
            "Kernel & Microcode"*)  _submenu_kernel ; hub_dirty=1 ;;
            "Init System"*)         _submenu_init ; hub_dirty=1 ;;
            "Desktop"*)             _submenu_desktop ; hub_dirty=1 ;;
            "Network & Audio"*)     _submenu_network_audio ; hub_dirty=1 ;;
            "Users & Privilege"*)   _submenu_users ; hub_dirty=1 ;;
            "Extras & Repos"*)      _submenu_extras ; hub_dirty=1 ;;
            "System Identity"*)     _submenu_identity ; hub_dirty=1 ;;
            "▸ Quick Profile"*)
                if tui_quick_install; then
                    [[ "$(state_get POWER_USER no)" == "yes" ]] && tui_select_poweruser
                    tui_show_sanity_warnings
                    return 0
                fi
                hub_dirty=1
                ;;
            "▸ Proceed with installation"*)
                if [[ -z "$(state_get DISK '')" ]]; then
                    tui_msg_quick "Disk Required" "Please select a target disk before proceeding."
                    continue
                fi
                if [[ "$(state_get USER_COUNT 0)" -eq 0 ]]; then
                    tui_msg_quick "Users Required" "Please create at least one user account."
                    tui_configure_users || true
                fi
                tui_show_sanity_warnings
                return 0
                ;;
            "▸ View summary"*)
                [[ $hub_dirty -eq 1 ]] && _rebuild_hub
                tui_msg "Installation Summary" "${cached_summary}" || true
                ;;
        esac
    done
}