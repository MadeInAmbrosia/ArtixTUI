#!/usr/bin/env bash
set -Eeuo pipefail

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
        "Gaming – KDE, linux-zen, PipeWire, flatpak, gaming extras" \
        "Development – XFCE, base-devel, git, neovim, development tools" \
        "Media – KDE minimal, mpv, feh, media extras" \
        "Volk's Personal – dinit, KDE minimal, source-built kernel" \
        "Load custom profile – source a saved configuration file") || return 1

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
        *Gaming*)
            state_set FS_TYPE "ext4"
            state_set BOOTLOADER "grub"
            state_set KERNEL_CHOICE "linux-zen"
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
            state_set KDE_PROFILE "minimal"
            state_set DISPLAY_MANAGER "sddm"
            state_set NETWORK_STACK "networkmanager"
            state_set AUDIO_STACK "pipewire"
            state_set X_STACK "xlibre"
            state_set USER_SHELL "bash"
            state_set EXTRAS "git flatpak fastfetch firewalld firefox alacritty fzf zoxide starship eza btop tmux mpv"
            ;;
        *Development*)
            state_set FS_TYPE "ext4"
            state_set BOOTLOADER "grub"
            state_set KERNEL_CHOICE "linux"
            state_set INIT "openrc"
            state_set PRIV_ESCALATION "doas"
            state_set USE_LUKS "no"
            state_set USE_LVM "no"
            state_set GENERATE_UKI "no"
            state_set ALLOW_OFFLINE "no"
            state_set ENABLE_ARCH_REPOS "yes"
            state_set MICROCODE_OVERRIDE "auto"
            state_set KEEP_BINARY_KERNEL "yes"
            state_set COREUTILS "gnu"
            state_set KERNEL_CONFIG_DEPTH "auto"
            state_set WM_DE "xfce4"
            state_set DISPLAY_MANAGER "lightdm"
            state_set NETWORK_STACK "networkmanager"
            state_set AUDIO_STACK "pipewire"
            state_set X_STACK "xlibre"
            state_set USER_SHELL "bash"
            state_set EXTRAS "git base-devel neovim firefox alacritty tmux fzf zoxide starship eza btop"
            ;;
        *Media*)
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
            state_set KDE_PROFILE "minimal"
            state_set DISPLAY_MANAGER "sddm"
            state_set NETWORK_STACK "networkmanager"
            state_set AUDIO_STACK "pipewire"
            state_set X_STACK "xlibre"
            state_set USER_SHELL "bash"
            state_set EXTRAS "git flatpak firefox alacritty mpv feh fzf zoxide starship eza btop tmux"
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
        *Load*)
            local profile_file
            profile_file=$(tui_input "Load Profile" "Enter path to profile file:" "/mnt/etc/artixforge-profile.conf") || return 1
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