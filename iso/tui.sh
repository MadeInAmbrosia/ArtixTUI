#!/usr/bin/env bash
set -Eeuo pipefail

ISO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

start_iso_build() {
    if ! command -v buildiso &>/dev/null; then
        if tui_yesno "Missing Tools" "artools is not installed. Install now?"; then
            pacman -S --noconfirm artools iso-profiles || die "Failed to install artools"
            modprobe loop
        else
            die "artools is required for ISO generation"
        fi
    fi

    # Ask boot mode FIRST
    local boot_mode
    boot_mode=$(tui_menu "ISO Type" "What kind of ISO do you want to build?" \
        "Live Desktop – full graphical environment, installer available manually" \
        "Installer – boots directly into ArtixForge installer") || return 1

    case "${boot_mode}" in
        "Live Desktop"*) boot_mode="live" ;;
        "Installer"*)    boot_mode="installer" ;;
    esac

    # Configuration – skip DE stuff for installer mode
    if [[ "${boot_mode}" == "live" ]]; then
        local config_method
        config_method=$(tui_menu "ISO Configuration" "How would you like to configure the ISO?" \
            "Quick Profile – use a preset" \
            "Full Customization – choose every option" \
            "Load Profile – from saved configuration file") || return 1

        case "${config_method}" in
            "Quick Profile"*)
                tui_quick_install || die "Profile selection cancelled"
                ;;
            "Full Customization"*)
                tui_collect_install_config
                ;;
            "Load Profile"*)
                local profile_file
                profile_file=$(tui_input "Load Profile" "Enter path to profile file:" "/etc/artixforge-profile.conf") || return 1
                if [[ -f "${profile_file}" ]]; then
                    source "${profile_file}"
                    for var in FS_TYPE BOOTLOADER KERNEL_CHOICE INIT PRIV_ESCALATION USE_LUKS USE_LVM GENERATE_UKI ALLOW_OFFLINE ENABLE_ARCH_REPOS MICROCODE_OVERRIDE KEEP_BINARY_KERNEL COREUTILS KERNEL_CONFIG_DEPTH WM_DE KDE_PROFILE DISPLAY_MANAGER NETWORK_STACK AUDIO_STACK X_STACK USER_SHELL EXTRAS POWER_USER POWERUSER_PACKAGES POWERUSER_PROFILE; do
                        [[ -n "${!var:-}" ]] && state_set "${var}" "${!var}"
                    done
                    tui_msg_quick "Profile Loaded" "Configuration loaded from ${profile_file}"
                else
                    tui_msg_quick "Error" "Profile file not found: ${profile_file}"
                    return 1
                fi
                ;;
        esac
    else
        # Installer mode: minimal config – just init, kernel, and offline preference
        local inst_init inst_kernel
        inst_init=$(tui_menu "Init System" "Select init system for the installer ISO:" \
            "openrc" "runit" "dinit" "s6") || return 1
        state_set INIT "${inst_init}"

        inst_kernel=$(tui_menu "Kernel" "Select kernel for the installer ISO:" \
            "linux" "linux-zen" "linux-lts" "linux-hardened") || return 1
        state_set KERNEL_CHOICE "${inst_kernel}"

        # Defaults for installer mode
        state_set WM_DE "none"
        state_set DISPLAY_MANAGER "none"
        state_set X_STACK "none"
        state_set AUDIO_STACK "none"
        state_set NETWORK_STACK "networkmanager"
        state_set QUICK_PROFILE "Installer"
    fi

    # Optional extra packages
    if tui_yesno "Additional Packages" "Would you like to add extra packages to the ISO?"; then
        local extra_pkgs
        extra_pkgs=$(tui_input "Extra Packages" "Space-separated list of additional packages:" "") || true
        if [[ -n "${extra_pkgs}" ]]; then
            state_set ISO_EXTRA_PACKAGES "${extra_pkgs}"
        fi
    fi

    local profile_name init kernel offline
    profile_name="$(state_get QUICK_PROFILE "Custom")"
    init="$(state_get INIT "openrc")"
    kernel="$(state_get KERNEL_CHOICE "linux")"

    offline="no"
    if tui_yesno "Offline ISO" "Include all packages for offline installation?"; then
        offline="yes"
    fi

    source "${ISO_DIR}/build.sh"
    build_artix_iso "${profile_name}" "${init}" "${kernel}" "${offline}" "${boot_mode}"
}