#!/usr/bin/env bash
set -Eeuo pipefail

_qp_defaults() {
    state_set FS_TYPE "ext4"
    state_set BOOTLOADER "grub"
    state_set KERNEL_CHOICE "linux"
    state_set INIT "openrc"
    state_set PRIV_ESCALATION "sudo"
    state_set USE_LUKS "no"
    state_set USE_LVM "no"
    state_set GENERATE_UKI "no"
    state_set ALLOW_OFFLINE "no"
    state_set ENABLE_ARCH_REPOS "no"
    state_set MICROCODE_OVERRIDE "auto"
    state_set KEEP_BINARY_KERNEL "yes"
    state_set COREUTILS "gnu"
    state_set KERNEL_CONFIG_DEPTH "auto"
    state_set POWER_USER "no"
    state_set USER_SHELL "bash"
}

_qp_desktop() {
    # Args: WM_DE DISPLAY_MANAGER [X_STACK] [ENABLE_ARCH_REPOS] [EXTRAS]
    _qp_defaults
    state_set WM_DE "${1}"
    state_set DISPLAY_MANAGER "${2}"
    state_set NETWORK_STACK "networkmanager"
    state_set AUDIO_STACK "pipewire"
    state_set X_STACK "${3:-xlibre}"
    state_set ENABLE_ARCH_REPOS "${4:-no}"
    state_set EXTRAS "${5:-git firefox alacritty fzf zoxide starship eza btop tmux}"
}

_qp_wayland() {
    # Args: WM_DE [ENABLE_ARCH_REPOS] [EXTRAS]
    _qp_desktop "${1}" "none" "none" "${2:-no}" "${3:-git firefox alacritty fzf zoxide starship eza btop tmux}"
}

_qp_confirm() {
    tui_select_hostname
    tui_select_timezone
    tui_select_locale
    tui_select_keyboard_layout
    tui_select_username
    tui_select_user_password
    tui_select_root_password

    local summary
    printf -v summary \
        "Profile: %s\n\nFilesystem: %s\nBootloader: %s\nKernel: %s\nInit: %s\nDesktop: %s\nDisplay Manager: %s\nNetwork: %s\nAudio: %s\nX Stack: %s\nPrivilege Escalation: %s\nLUKS: %s\nLVM: %s\nUKI: %s\nExtras: %s" \
        "${1}" \
        "$(state_get FS_TYPE)" "$(state_get BOOTLOADER)" "$(state_get KERNEL_CHOICE)" \
        "$(state_get INIT)" "$(state_get WM_DE)" "$(state_get DISPLAY_MANAGER)" \
        "$(state_get NETWORK_STACK)" "$(state_get AUDIO_STACK)" "$(state_get X_STACK)" \
        "$(state_get PRIV_ESCALATION)" "$(state_get USE_LUKS)" "$(state_get USE_LVM)" \
        "$(state_get GENERATE_UKI)" "$(state_get EXTRAS)"

    [[ "$(state_get INIT)" == "busybox" ]] && summary+=$'\nPower User: yes (BusyBox init)'
    [[ "$(state_get POWER_USER)" == "yes" ]] && summary+=$'\nPower User: yes'

    tui_yesno "Confirm Profile" "${summary}"$'\n\nProceed with this profile?' || return 1

    if tui_yesno "Customize" "Customize any settings before installing?"; then
        state_set QUICK_INSTALL "no"
        return 1
    fi
    state_set QUICK_INSTALL "yes"
}

_qp_kde() {
    local v
    v=$(tui_menu "KDE Plasma" "Variant:" "Full – plasma + kde-applications" "Desktop – plasma" "Minimal – plasma-desktop only") || return 1
    _qp_desktop "kde" "sddm" "xlibre" "yes" "git flatpak fastfetch firewalld bluez zram-tools firefox neovim alacritty fzf zoxide starship eza btop htop tmux mpv"
    case "${v}" in Full*) state_set KDE_PROFILE "full" ;; Desktop*) state_set KDE_PROFILE "desktop" ;; Minimal*) state_set KDE_PROFILE "minimal" ;; esac
    state_set QUICK_PROFILE "KDE-${v%% *}"
    _qp_confirm "KDE Plasma (${v%% *})"
}

_qp_xfce() {
    local v
    v=$(tui_menu "XFCE" "Variant:" "Full – xfce4 + goodies" "Minimal – xfce4 only") || return 1
    _qp_desktop "xfce4" "lightdm" "xlibre" "no" "$([[ "${v}" == Full* ]] && echo 'git firefox neovim alacritty fzf zoxide starship eza btop tmux mpv' || echo 'git neovim tmux')"
    state_set QUICK_PROFILE "XFCE-${v%% *}"
    _qp_confirm "XFCE (${v%% *})"
}

_qp_mango()   { _qp_wayland "mango"   "yes" "git firefox alacritty waybar wofi swaybg swaylock fzf zoxide starship eza btop tmux"; state_set DISPLAY_MANAGER "lightdm"; state_set QUICK_PROFILE "MangoWM";   _qp_confirm "MangoWM"; }
_qp_hyprland(){ _qp_wayland "hyprland" "yes" "git firefox alacritty waybar wofi hyprpaper hyprlock fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "Hyprland"; _qp_confirm "Hyprland"; }
_qp_sway()    { _qp_wayland "sway"     "no"  "git firefox alacritty waybar wofi swaybg swaylock fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "Sway";     _qp_confirm "Sway"; }
_qp_niri()    { _qp_wayland "niri"     "no"  "git firefox alacritty waybar fuzzel swaybg swaylock fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "Niri";     _qp_confirm "Niri"; }

_qp_i3()      { _qp_desktop "i3wm"  "lightdm" "xlibre" "no" "git firefox alacritty fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "i3wm";  _qp_confirm "i3wm"; }
_qp_dwm()     { _qp_desktop "dwm"   "lightdm" "xlibre" "no" "git firefox st fzf zoxide starship eza tmux";           state_set QUICK_PROFILE "dwm";   _qp_confirm "dwm"; }

_qp_lxqt()    { _qp_desktop "lxqt"    "sddm"    "xlibre" "no" "git firefox alacritty fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "LXQt";    _qp_confirm "LXQt"; }
_qp_lxde()    { _qp_desktop "lxde"    "lightdm" "xlibre" "no" "git firefox alacritty fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "LXDE";    _qp_confirm "LXDE"; }
_qp_cinnamon(){ _qp_desktop "cinnamon" "lightdm" "xlibre" "no" "git firefox alacritty fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "Cinnamon"; _qp_confirm "Cinnamon"; }
_qp_budgie()  { _qp_desktop "budgie"  "lightdm" "xlibre" "no" "git firefox alacritty fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "Budgie";  _qp_confirm "Budgie"; }
_qp_moksha()  { _qp_desktop "moksha"  "lightdm" "xlibre" "no" "git firefox terminology fzf zoxide starship eza tmux";   state_set QUICK_PROFILE "Moksha";  _qp_confirm "Moksha"; }
_qp_cosmic()  { _qp_desktop "cosmic"  "lightdm" "none"   "no" "git firefox alacritty fzf zoxide starship eza btop tmux"; state_set QUICK_PROFILE "COSMIC";  _qp_confirm "COSMIC"; }

_qp_server() {
    local v
    v=$(tui_menu "Server" "Variant:" "Full – firewalld, zram, SSH" "Minimal – SSH only") || return 1
    _qp_defaults
    state_set WM_DE "none"; state_set DISPLAY_MANAGER "none"; state_set NETWORK_STACK "dhcpcd+iwd"
    state_set AUDIO_STACK "none"; state_set X_STACK "none"; state_set PRIV_ESCALATION "doas"
    case "${v}" in
        Full*)    state_set EXTRAS "git firewalld zram-tools tmux" ;;
        Minimal*) state_set EXTRAS "git tmux" ;;
    esac
    state_set QUICK_PROFILE "Server-${v%% *}"
    _qp_confirm "Server (${v%% *})"
}

_qp_embedded() {
    _qp_defaults
    state_set WM_DE "none"; state_set DISPLAY_MANAGER "none"; state_set NETWORK_STACK "none"
    state_set AUDIO_STACK "none"; state_set X_STACK "none"; state_set PRIV_ESCALATION "none"
    state_set INIT "busybox"; state_set KERNEL_CHOICE "linux-lts"; state_set COREUTILS "busybox"
    state_set POWER_USER "yes"; state_set KEEP_BINARY_KERNEL "no"; state_set EXTRAS ""
    state_set QUICK_PROFILE "Embedded"
    _qp_confirm "Embedded"
}

_qp_volk() {
    _qp_desktop "kde" "lightdm" "xlibre" "yes" "git fastfetch tmux htop kitty firewalld flatpak"
    state_set KDE_PROFILE "minimal"; state_set INIT "dinit"; state_set PRIV_ESCALATION "doas"
    state_set POWER_USER "yes"; state_set KEEP_BINARY_KERNEL "no"; state_set NETWORK_STACK "dhcpcd+iwd"
    state_set QUICK_PROFILE "Volk"
    tui_msg_quick "Volk Profile" "Minimal source kernel with auto-detected hardware.\n\nNo VirtIO/VM drivers included — will NOT boot in virtual machines."
    _qp_confirm "Volk's Personal"
}

_qp_testing() {
    _qp_defaults
    state_set FS_TYPE "xfs"; state_set BOOTLOADER "limine"; state_set KERNEL_CHOICE "linux-cachyos-bore"
    state_set INIT "s6"; state_set PRIV_ESCALATION "doas"; state_set USE_LUKS "yes"
    state_set USE_LVM "yes"; state_set GENERATE_UKI "yes"; state_set ENABLE_ARCH_REPOS "yes"
    state_set MICROCODE_OVERRIDE "none"; state_set COREUTILS "busybox"
    state_set WM_DE "mango"; state_set DISPLAY_MANAGER "lightdm"; state_set NETWORK_STACK "dhcpcd+iwd"
    state_set AUDIO_STACK "pipewire"; state_set X_STACK "none"; state_set USER_SHELL "fish"
    state_set EXTRAS "git fastfetch tmux htop kitty firewalld flatpak"
    state_set QUICK_PROFILE "TestingQP"
    tui_msg_quick "Testing Profile" "Every experimental combination enabled.\n\nIf this installs and boots, you may complain about bugs."
    _qp_confirm "TestingQP"
}

_qp_load() {
    local pf
    pf=$(tui_input "Load Profile" "Path to profile file:" "/mnt/etc/artixforge-profile.conf") || return 1
    [[ -f "${pf}" ]] || { tui_msg_quick "Error" "Profile not found: ${pf}"; return 1; }
    source "${pf}"
    local var
    for var in FS_TYPE BOOTLOADER KERNEL_CHOICE INIT PRIV_ESCALATION USE_LUKS USE_LVM GENERATE_UKI ALLOW_OFFLINE ENABLE_ARCH_REPOS MICROCODE_OVERRIDE KEEP_BINARY_KERNEL COREUTILS KERNEL_CONFIG_DEPTH WM_DE KDE_PROFILE DISPLAY_MANAGER NETWORK_STACK AUDIO_STACK X_STACK USER_SHELL EXTRAS POWER_USER POWERUSER_PACKAGES POWERUSER_PROFILE; do
        [[ -n "${!var:-}" ]] && state_set "${var}" "${!var}"
    done
    tui_msg_quick "Profile Loaded" "Configuration loaded from ${pf}"
    state_set QUICK_PROFILE "Custom"
    _qp_confirm "Custom Profile"
}

tui_quick_install() {
    if ! tui_yesno "Quick Install" "Use a pre-configured profile?"; then
        return 1
    fi

    local de
    de=$(tui_menu "Quick Profile" "Select desktop environment:" \
        "KDE Plasma"      "XFCE"        "MangoWM"   "Hyprland" \
        "Sway"            "Niri"        "i3wm"      "dwm" \
        "LXQt"            "LXDE"        "Cinnamon"  "Budgie" \
        "Moksha"          "COSMIC"      "Server (no desktop)" \
        "Embedded (BusyBox)"            "Volk's Personal" \
        "TestingQP"                     "Load custom profile...") || return 1

    case "${de}" in
        "KDE Plasma")     _qp_kde ;;
        "XFCE")           _qp_xfce ;;
        "MangoWM")        _qp_mango ;;
        "Hyprland")       _qp_hyprland ;;
        "Sway")           _qp_sway ;;
        "Niri")           _qp_niri ;;
        "i3wm")           _qp_i3 ;;
        "dwm")            _qp_dwm ;;
        "LXQt")           _qp_lxqt ;;
        "LXDE")           _qp_lxde ;;
        "Cinnamon")       _qp_cinnamon ;;
        "Budgie")         _qp_budgie ;;
        "Moksha")         _qp_moksha ;;
        "COSMIC")         _qp_cosmic ;;
        "Server"*)        _qp_server ;;
        "Embedded"*)      _qp_embedded ;;
        "Volk"*)          _qp_volk ;;
        "TestingQP")      _qp_testing ;;
        "Load"*)          _qp_load ;;
    esac
}