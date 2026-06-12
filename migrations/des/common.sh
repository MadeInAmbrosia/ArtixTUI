#!/usr/bin/env bash
set -Eeuo pipefail

declare -A DE_PACKAGES
DE_PACKAGES=(
    ["kde"]="plasma-desktop dolphin konsole kde-applications"
    ["kde-minimal"]="plasma-desktop dolphin konsole"
    ["sonicde"]="sonicde-meta"
    ["xfce"]="xfce4 xfce4-goodies"
    ["lxqt"]="lxqt"
    ["lxde"]="lxde-common lxde"
    ["hyprland"]="hyprland swaybg swaylock waybar"
    ["sway"]="sway swaybg swaylock waybar"
    ["niri"]="niri swaybg swaylock"
    ["i3wm"]="i3-wm i3status i3lock dmenu xterm"
    ["dwm"]="dwm dmenu xterm"
    ["vxwm"]="vxwm"
    ["icewm"]="icewm"
    ["mango"]="mangowm"
    ["none"]=""
)

declare -A DE_DISPLAY_MANAGER
DE_DISPLAY_MANAGER=(
    ["kde"]="sddm"
    ["sonicde"]="soniclogin"
    ["xfce"]="lightdm"
    ["lxqt"]="sddm"
    ["lxde"]="lightdm"
    ["hyprland"]="none"
    ["sway"]="none"
    ["niri"]="none"
    ["i3wm"]="lightdm"
    ["dwm"]="lightdm"
    ["vxwm"]="none"
    ["icewm"]="lightdm"
    ["mango"]="none"
    ["none"]="none"
)

declare -A DM_PACKAGES
DM_PACKAGES=(
    ["sddm-openrc"]="sddm sddm-openrc"
    ["sddm-runit"]="sddm sddm-runit"
    ["sddm-dinit"]="sddm sddm-dinit"
    ["sddm-s6"]="sddm sddm-s6"
    ["lightdm-openrc"]="lightdm lightdm-gtk-greeter lightdm-openrc"
    ["lightdm-runit"]="lightdm lightdm-gtk-greeter lightdm-runit"
    ["lightdm-dinit"]="lightdm lightdm-gtk-greeter lightdm-dinit"
    ["lightdm-s6"]="lightdm lightdm-gtk-greeter lightdm-s6"
    ["soniclogin-openrc"]="sonic-login-manager sonic-login-manager-openrc"
    ["soniclogin-runit"]="sonic-login-manager sonic-login-manager-runit"
    ["soniclogin-dinit"]="sonic-login-manager sonic-login-manager-dinit"
    ["soniclogin-s6"]="sonic-login-manager sonic-login-manager-s6"
)

declare -A AUDIO_PACKAGES
AUDIO_PACKAGES=(
    ["pipewire"]="pipewire pipewire-pulse pipewire-alsa wireplumber alsa-utils pavucontrol rtkit pipewire-jack"
    ["pulseaudio"]="pulseaudio pulseaudio-alsa alsa-utils pavucontrol"
    ["none"]=""
)

declare -A X_PACKAGES
X_PACKAGES=(
    ["xlibre"]="xlibre-xserver xlibre-xserver-common xlibre-input-libinput xlibre-input-evdev"
    ["xorg"]="xorg-server xorg-xinit xorg-xset xorg-xrandr xf86-input-libinput xf86-input-evdev"
    ["wayland"]=""
    ["none"]=""
)

declare -A NETWORK_PACKAGES
NETWORK_PACKAGES=(
    ["networkmanager-openrc"]="networkmanager networkmanager-openrc"
    ["networkmanager-runit"]="networkmanager networkmanager-runit"
    ["networkmanager-dinit"]="networkmanager networkmanager-dinit"
    ["networkmanager-s6"]="networkmanager networkmanager-s6"
    ["dhcpcd+iwd-openrc"]="dhcpcd iwd dhcpcd-openrc iwd-openrc"
    ["dhcpcd+iwd-runit"]="dhcpcd iwd dhcpcd-runit iwd-runit"
    ["dhcpcd+iwd-dinit"]="dhcpcd iwd dhcpcd-dinit iwd-dinit"
    ["dhcpcd+iwd-s6"]="dhcpcd iwd dhcpcd-s6 iwd-s6"
    ["connman-openrc"]="connman connman-openrc"
    ["connman-runit"]="connman connman-runit"
    ["connman-dinit"]="connman connman-dinit"
    ["connman-s6"]="connman connman-s6"
    ["none"]=""
)

declare -A EXTRA_PACKAGES
EXTRA_PACKAGES=(
    ["git"]="git"
    ["flatpak"]="flatpak"
    ["fastfetch"]="fastfetch"
    ["firewalld"]="firewalld"
    ["bluez"]="bluez"
    ["zram-tools"]="zram-tools"
    ["fzf"]="fzf"
    ["zoxide"]="zoxide"
    ["starship"]="starship"
    ["eza"]="eza"
    ["btop"]="btop"
    ["htop"]="htop"
    ["nvtop"]="nvtop"
    ["tmux"]="tmux"
    ["nano"]="nano"
    ["vim"]="vim"
    ["neovim"]="neovim"
    ["micro"]="micro"
    ["helix"]="helix"
    ["firefox"]="firefox"
    ["chromium"]="chromium"
    ["qutebrowser"]="qutebrowser"
    ["ranger"]="ranger"
    ["lf"]="lf"
    ["nnn"]="nnn"
    ["thunar"]="thunar"
    ["alacritty"]="alacritty"
    ["kitty"]="kitty"
    ["foot"]="foot"
    ["mpv"]="mpv"
    ["feh"]="feh"
)

detect_current_de() {
    if pacman -Qq sonicde-meta &>/dev/null; then echo "sonicde"
    elif pacman -Qq plasma-desktop &>/dev/null; then echo "kde"
    elif pacman -Qq xfce4 &>/dev/null; then echo "xfce"
    elif pacman -Qq lxqt &>/dev/null; then echo "lxqt"
    elif pacman -Qq lxde-common &>/dev/null || pacman -Qq lxde &>/dev/null; then echo "lxde"
    elif pacman -Qq hyprland &>/dev/null; then echo "hyprland"
    elif pacman -Qq sway &>/dev/null; then echo "sway"
    elif pacman -Qq niri &>/dev/null; then echo "niri"
    elif pacman -Qq i3-wm &>/dev/null; then echo "i3wm"
    elif pacman -Qq dwm &>/dev/null; then echo "dwm"
    elif pacman -Qq vxwm &>/dev/null; then echo "vxwm"
    elif pacman -Qq icewm &>/dev/null; then echo "icewm"
    elif pacman -Qq mangowm &>/dev/null; then echo "mango"
    else echo "none"; fi
}

detect_current_dm() {
    if pacman -Qq sonic-login-manager &>/dev/null; then echo "soniclogin"
    elif pacman -Qq sddm &>/dev/null; then echo "sddm"
    elif pacman -Qq lightdm &>/dev/null; then echo "lightdm"
    elif pacman -Qq gdm &>/dev/null; then echo "gdm"
    else echo "none"; fi
}

detect_current_x() {
    if pacman -Qq xlibre-xserver &>/dev/null; then echo "xlibre"
    elif pacman -Qq xorg-server &>/dev/null; then echo "xorg"
    elif [[ -d /usr/share/wayland-sessions ]]; then echo "wayland"
    else echo "none"; fi
}

detect_current_audio() {
    if pacman -Qq pipewire &>/dev/null; then echo "pipewire"
    elif pacman -Qq pulseaudio &>/dev/null; then echo "pulseaudio"
    else echo "none"; fi
}

detect_current_network() {
    if pacman -Qq networkmanager &>/dev/null; then echo "networkmanager"
    elif pacman -Qq dhcpcd &>/dev/null || pacman -Qq iwd &>/dev/null; then echo "dhcpcd+iwd"
    elif pacman -Qq connman &>/dev/null; then echo "connman"
    else echo "none"; fi
}

detect_current_init() {
    if [[ -d /etc/runit ]]; then echo "runit"
    elif [[ -d /etc/dinit.d ]]; then echo "dinit"
    elif [[ -d /etc/s6 ]]; then echo "s6"
    else echo "openrc"; fi
}

backup_de_config() {
    local backup_dir="/root/de-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    for user_home in /home/*; do
        local user="${user_home##*/}"
        [[ -d "$user_home" ]] || continue
        cp -a "$user_home/.config" "$backup_dir/$user-config" 2>/dev/null || true
        cp -a "$user_home/.local"  "$backup_dir/$user-local"  2>/dev/null || true
        cp -a "$user_home/.cache"  "$backup_dir/$user-cache"  2>/dev/null || true
    done
    cp -a /etc/sddm.conf.d    "$backup_dir/sddm.conf.d"    2>/dev/null || true
    cp -a /etc/lightdm        "$backup_dir/lightdm"        2>/dev/null || true
    cp -a /etc/X11/xorg.conf.d "$backup_dir/xorg.conf.d"   2>/dev/null || true
    log_info "Configs backed up to $backup_dir"
}

remove_packages() {
    local pkgs="$1"
    [[ -n "$pkgs" ]] || return 0
    pacman -Rns --noconfirm $pkgs 2>/dev/null || true
}

install_packages() {
    local pkgs="$1"
    [[ -n "$pkgs" ]] || return 0
    pacman -S --noconfirm --needed $pkgs 2>/dev/null || log_warn "Failed to install some packages"
}

prompt_migration_choices() {
    local current_dm current_x current_audio current_network current_init
    current_dm=$(detect_current_dm)
    current_x=$(detect_current_x)
    current_audio=$(detect_current_audio)
    current_network=$(detect_current_network)
    current_init=$(detect_current_init)

    local dm_choice x_choice audio_choice network_choice extras_choice

    dm_choice=$(tui_menu "Display Manager" "Current: $current_dm\nSelect display manager:" \
        "Keep current ($current_dm)" "SDDM" "LightDM" "Sonic Login" "None") || dm_choice="Keep current"
    state_set DE_MIG_DM "${dm_choice}"

    x_choice=$(tui_menu "Display Stack" "Current: $current_x\nSelect display stack:" \
        "Keep current ($current_x)" "xlibre" "xorg" "wayland") || x_choice="Keep current"
    state_set DE_MIG_X "${x_choice}"

    audio_choice=$(tui_menu "Audio Stack" "Current: $current_audio\nSelect audio stack:" \
        "Keep current ($current_audio)" "pipewire" "pulseaudio" "none") || audio_choice="Keep current"
    state_set DE_MIG_AUDIO "${audio_choice}"

    network_choice=$(tui_menu "Network Stack" "Current: $current_network\nSelect network stack:" \
        "Keep current ($current_network)" "NetworkManager" "dhcpcd+iwd" "ConnMan" "None") || network_choice="Keep current"
    state_set DE_MIG_NETWORK "${network_choice}"

    local extras_list=()
    for extra in "${!EXTRA_PACKAGES[@]}"; do extras_list+=("$extra"); done
    extras_choice=$(tui_checklist "Extras" "Select extra packages to ensure are installed:" "${extras_list[@]}") || true
    state_set DE_MIG_EXTRAS "${extras_choice}"
}

apply_migration_choices() {
    local dm_choice x_choice audio_choice network_choice extras_choice init
    dm_choice="$(state_get DE_MIG_DM "Keep current")"
    x_choice="$(state_get DE_MIG_X "Keep current")"
    audio_choice="$(state_get DE_MIG_AUDIO "Keep current")"
    network_choice="$(state_get DE_MIG_NETWORK "Keep current")"
    extras_choice="$(state_get DE_MIG_EXTRAS "")"
    init=$(detect_current_init)

    if [[ "$dm_choice" != "Keep current"* ]]; then
        local dm_pkg="${dm_choice,,}"
        case "$dm_pkg" in
            sddm|lightdm|soniclogin)
                local key="${dm_pkg}-${init}"
                install_packages "${DM_PACKAGES[$key]:-}"
                enable_service "${dm_pkg}" 2>/dev/null || log_warn "Could not enable $dm_pkg service"
                ;;
            none) remove_packages "sddm sddm-openrc sddm-runit sddm-dinit sddm-s6 lightdm lightdm-gtk-greeter lightdm-openrc lightdm-runit lightdm-dinit lightdm-s6 sonic-login-manager sonic-login-manager-openrc sonic-login-manager-runit sonic-login-manager-dinit sonic-login-manager-s6 gdm" ;;
        esac
    fi

    if [[ "$x_choice" != "Keep current"* ]]; then
        local x_new="${x_choice,,}"
        if [[ "$x_new" == "xlibre" ]]; then
            remove_packages "xorg-server xf86-input-libinput xf86-input-evdev"
        elif [[ "$x_new" == "xorg" ]]; then
            remove_packages "xlibre-xserver xlibre-xserver-common xlibre-input-libinput xlibre-input-evdev"
        fi
        install_packages "${X_PACKAGES[$x_new]:-}"
    fi

    if [[ "$audio_choice" != "Keep current"* ]]; then
        remove_packages "pipewire pipewire-pulse pipewire-alsa wireplumber pipewire-jack pulseaudio pulseaudio-alsa"
        install_packages "${AUDIO_PACKAGES[${audio_choice,,}]:-}"
    fi

    if [[ "$network_choice" != "Keep current"* ]]; then
        local net_new="${network_choice,,}"
        remove_packages "networkmanager networkmanager-openrc networkmanager-runit networkmanager-dinit networkmanager-s6"
        remove_packages "dhcpcd iwd dhcpcd-openrc dhcpcd-runit dhcpcd-dinit dhcpcd-s6 iwd-openrc iwd-runit iwd-dinit iwd-s6"
        remove_packages "connman connman-openrc connman-runit connman-dinit connman-s6"

        if [[ "$net_new" != "none" ]]; then
            local key="${net_new}-${init}"
            install_packages "${NETWORK_PACKAGES[$key]:-}"
            case "$net_new" in
                networkmanager) enable_service NetworkManager ;;
                dhcpcd+iwd) enable_service dhcpcd; enable_service iwd ;;
                connman) enable_service connmand ;;
            esac
        fi
    fi

    if [[ -n "$extras_choice" ]]; then
        local pkg_list=""
        for extra in $extras_choice; do
            pkg_list+=" ${EXTRA_PACKAGES[$extra]:-}"
        done
        install_packages "$pkg_list"
    fi
}

detect_de_conflicts() {
    local source_de="${1}" target_de="${2}"
    local conflicts=""
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        conflicts+="Current desktop session is running. Migration may cause instability.\n"
    fi
    local source_dm target_dm
    source_dm="${DE_DISPLAY_MANAGER[$source_de]:-none}"
    target_dm="${DE_DISPLAY_MANAGER[$target_de]:-none}"
    if [[ "$source_dm" != "$target_dm" ]]; then
        conflicts+="Display manager will change: $source_dm → $target_dm\n"
    fi
    local source_is_wayland=0 target_is_wayland=0
    [[ "$source_de" =~ ^(hyprland|sway|niri)$ ]] && source_is_wayland=1
    [[ "$target_de" =~ ^(hyprland|sway|niri)$ ]] && target_is_wayland=1
    if [[ $source_is_wayland -ne $target_is_wayland ]]; then
        conflicts+="Display protocol will change (Wayland ↔ X11)\n"
    fi
    printf '%b' "$conflicts"
}

run_de_migration() {
    local source_de="${1}" target_de="${2}"
    [[ "$source_de" != "$target_de" ]] || die "Source and target DE are the same: $source_de"

    local conflicts
    conflicts=$(detect_de_conflicts "$source_de" "$target_de")
    if [[ -n "$conflicts" ]]; then
        tui_msg "Migration Warnings" "The following conflicts were detected:\n\n${conflicts}\n\nProceed with caution."
        if ! tui_yesno "Continue?" "Are you sure you want to proceed with the migration?"; then
            log_info "Migration cancelled."
            return 0
        fi
    fi

    log_info "Backing up user configs..."
    backup_de_config

    prompt_migration_choices

    if [[ "$source_de" != "none" ]]; then
        log_info "Removing $source_de packages..."
        remove_packages "${DE_PACKAGES[$source_de]:-}"
        pacman -Qtdq 2>/dev/null | xargs -r pacman -Rns --noconfirm 2>/dev/null || true
    fi

    if [[ "$target_de" != "none" ]]; then
        log_info "Installing $target_de packages..."
        install_packages "${DE_PACKAGES[$target_de]:-}"
    fi

    apply_migration_choices

    if [[ -x /usr/bin/mkinitcpio ]]; then
        mkinitcpio -P 2>/dev/null || true
    fi

    log_info "Desktop migration complete."
    log_info "You should reboot for all changes to take effect."
    if tui_yesno "Reboot" "Reboot now?"; then
        reboot
    fi
}

tui_de_migration_menu() {
    local current_de source_de target_de
    current_de=$(detect_current_de)
    tui_msg "Current Desktop" "Detected desktop environment: ${current_de}"

    source_de=$(tui_menu "Source Desktop" "Select desktop to migrate FROM:" \
        "kde" "sonicde" "xfce" "lxqt" "lxde" "hyprland" "sway" "niri" \
        "i3wm" "dwm" "vxwm" "icewm" "mango" "none") || return 1

    target_de=$(tui_menu "Target Desktop" "Select desktop to migrate TO:" \
        "kde" "sonicde" "xfce" "lxqt" "lxde" "hyprland" "sway" "niri" \
        "i3wm" "dwm" "vxwm" "icewm" "mango" "none") || return 1

    [[ "$source_de" != "$target_de" ]] || die "Source and target are the same."

    local script="${MIGRATIONS_DIR}/des/${source_de}-to-${target_de}.sh"
    if [[ -f "$script" ]]; then
        source "$script"
    else
        log_warn "No direct migration script for $source_de → $target_de"
        if tui_yesno "Generic Migration" "No direct path exists. Remove all $source_de packages and install $target_de?"; then
            run_de_migration "$source_de" "$target_de"
        fi
    fi
}