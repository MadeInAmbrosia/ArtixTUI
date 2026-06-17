#!/usr/bin/env bash
set -Eeuo pipefail

MIG_ROOT=""
if [[ -d /run/artix/sfs/rootfs ]]; then
    if ! mountpoint -q /mnt; then
        tui_msg "Live ISO Detected" "Migration from live ISO requires the target system mounted at /mnt."
        if tui_yesno "Mount Target" "Would you like to mount it now?"; then
            recovery_mount_all
        else
            tui_msg_quick "Migration Cancelled" "Mount the target system at /mnt and retry."
            exit 1
        fi
    fi
    MIG_ROOT="/mnt"
fi

_chroot() {
    if [[ -n "${MIG_ROOT}" ]]; then
        artix-chroot "${MIG_ROOT}" "$@"
    else
        "$@"
    fi
}

_pacman_Q() {
    if [[ -n "${MIG_ROOT}" ]]; then
        pacman --root "${MIG_ROOT}" -Q "$@" 2>/dev/null
    else
        pacman -Q "$@" 2>/dev/null
    fi
}

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
    if _pacman_Q sonicde-meta &>/dev/null; then echo "sonicde"
    elif _pacman_Q plasma-desktop &>/dev/null; then echo "kde"
    elif _pacman_Q xfce4 &>/dev/null; then echo "xfce"
    elif _pacman_Q lxqt &>/dev/null; then echo "lxqt"
    elif _pacman_Q lxde-common &>/dev/null || _pacman_Q lxde &>/dev/null; then echo "lxde"
    elif _pacman_Q hyprland &>/dev/null; then echo "hyprland"
    elif _pacman_Q sway &>/dev/null; then echo "sway"
    elif _pacman_Q niri &>/dev/null; then echo "niri"
    elif _pacman_Q i3-wm &>/dev/null; then echo "i3wm"
    elif _pacman_Q dwm &>/dev/null; then echo "dwm"
    elif _pacman_Q vxwm &>/dev/null; then echo "vxwm"
    elif _pacman_Q icewm &>/dev/null; then echo "icewm"
    elif _pacman_Q mangowm &>/dev/null; then echo "mango"
    else echo "none"; fi
}

detect_current_dm() {
    if _pacman_Q sonic-login-manager &>/dev/null; then echo "soniclogin"
    elif _pacman_Q sddm &>/dev/null; then echo "sddm"
    elif _pacman_Q lightdm &>/dev/null; then echo "lightdm"
    elif _pacman_Q gdm &>/dev/null; then echo "gdm"
    else echo "none"; fi
}

detect_current_x() {
    if _pacman_Q xlibre-xserver &>/dev/null; then echo "xlibre"
    elif _pacman_Q xorg-server &>/dev/null; then echo "xorg"
    elif [[ -d "${MIG_ROOT}/usr/share/wayland-sessions" ]]; then echo "wayland"
    else echo "none"; fi
}

detect_current_audio() {
    if _pacman_Q pipewire &>/dev/null; then echo "pipewire"
    elif _pacman_Q pulseaudio &>/dev/null; then echo "pulseaudio"
    else echo "none"; fi
}

detect_current_network() {
    if _pacman_Q networkmanager &>/dev/null; then echo "networkmanager"
    elif _pacman_Q dhcpcd &>/dev/null || _pacman_Q iwd &>/dev/null; then echo "dhcpcd+iwd"
    elif _pacman_Q connman &>/dev/null; then echo "connman"
    else echo "none"; fi
}

detect_current_init() {
    if [[ -d "${MIG_ROOT}/etc/runit" ]]; then echo "runit"
    elif [[ -d "${MIG_ROOT}/etc/dinit.d" ]]; then echo "dinit"
    elif [[ -d "${MIG_ROOT}/etc/s6" ]]; then echo "s6"
    else echo "openrc"; fi
}

backup_de_config() {
    local backup_dir="${MIG_ROOT}/root/de-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    for user_home in "${MIG_ROOT}"/home/*; do
        local user="${user_home##*/}"
        [[ -d "$user_home" ]] || continue
        cp -a "$user_home/.config" "$backup_dir/$user-config" 2>/dev/null || true
        cp -a "$user_home/.local"  "$backup_dir/$user-local"  2>/dev/null || true
        cp -a "$user_home/.cache"  "$backup_dir/$user-cache"  2>/dev/null || true
    done
    cp -a "${MIG_ROOT}/etc/sddm.conf.d"    "$backup_dir/sddm.conf.d"    2>/dev/null || true
    cp -a "${MIG_ROOT}/etc/lightdm"        "$backup_dir/lightdm"        2>/dev/null || true
    cp -a "${MIG_ROOT}/etc/X11/xorg.conf.d" "$backup_dir/xorg.conf.d"   2>/dev/null || true
    log_info "Configs backed up to $backup_dir"
}

remove_packages() {
    local pkgs="$1"
    [[ -n "$pkgs" ]] || return 0
    if [[ -n "${MIG_ROOT}" ]]; then
        artix-chroot "${MIG_ROOT}" pacman -Rns --noconfirm $pkgs 2>/dev/null || true
    else
        pacman -Rns --noconfirm $pkgs 2>/dev/null || true
    fi
}

install_packages() {
    local pkgs="$1"
    [[ -n "$pkgs" ]] || return 0
    if [[ -n "${MIG_ROOT}" ]]; then
        artix-chroot "${MIG_ROOT}" pacman -S --noconfirm --needed $pkgs 2>/dev/null || log_warn "Failed to install some packages"
    else
        pacman -S --noconfirm --needed $pkgs 2>/dev/null || log_warn "Failed to install some packages"
    fi
}

_enable_service() {
    local svc="$1"
    if [[ -n "${MIG_ROOT}" ]]; then
        artix-chroot "${MIG_ROOT}" bash -c "source /usr/local/lib/artix-installer/services.sh 2>/dev/null || source /root/ArtixForge/scripts/install/services.sh; export INIT='${INIT}'; enable_service '${svc}'" 2>/dev/null || log_warn "Could not enable $svc service"
    else
        enable_service "$svc" 2>/dev/null || log_warn "Could not enable $svc service"
    fi
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
    dm_choice="${dm_choice,,}"
    case "$dm_choice" in
        "sddm") dm_choice="sddm" ;;
        "lightdm") dm_choice="lightdm" ;;
        "sonic login") dm_choice="soniclogin" ;;
        "none") dm_choice="none" ;;
        "keep current"*) dm_choice="current" ;;
        *) dm_choice="current" ;;
    esac
    state_set DE_MIG_DM "${dm_choice}"

    x_choice=$(tui_menu "Display Stack" "Current: $current_x\nSelect display stack:" \
        "Keep current ($current_x)" "xlibre" "xorg" "wayland") || x_choice="Keep current"
    x_choice="${x_choice,,}"
    case "$x_choice" in
        "xlibre") x_choice="xlibre" ;;
        "xorg") x_choice="xorg" ;;
        "wayland") x_choice="wayland" ;;
        "keep current"*) x_choice="current" ;;
        *) x_choice="current" ;;
    esac
    state_set DE_MIG_X "${x_choice}"

    audio_choice=$(tui_menu "Audio Stack" "Current: $current_audio\nSelect audio stack:" \
        "Keep current ($current_audio)" "pipewire" "pulseaudio" "none") || audio_choice="Keep current"
    audio_choice="${audio_choice,,}"
    case "$audio_choice" in
        "pipewire") audio_choice="pipewire" ;;
        "pulseaudio") audio_choice="pulseaudio" ;;
        "none") audio_choice="none" ;;
        "keep current"*) audio_choice="current" ;;
        *) audio_choice="current" ;;
    esac
    state_set DE_MIG_AUDIO "${audio_choice}"

    network_choice=$(tui_menu "Network Stack" "Current: $current_network\nSelect network stack:" \
        "Keep current ($current_network)" "NetworkManager" "dhcpcd+iwd" "ConnMan" "None") || network_choice="Keep current"
    network_choice="${network_choice,,}"
    case "$network_choice" in
        "networkmanager") network_choice="networkmanager" ;;
        "dhcpcd+iwd") network_choice="dhcpcd+iwd" ;;
        "connman") network_choice="connman" ;;
        "none") network_choice="none" ;;
        "keep current"*) network_choice="current" ;;
        *) network_choice="current" ;;
    esac
    state_set DE_MIG_NETWORK "${network_choice}"

    local extras_list=()
    for extra in "${!EXTRA_PACKAGES[@]}"; do extras_list+=("$extra"); done
    extras_choice=$(tui_checklist "Extras" "Select extra packages to ensure are installed:" "${extras_list[@]}") || true
    state_set DE_MIG_EXTRAS "${extras_choice}"
}

apply_migration_choices() {
    local dm_choice x_choice audio_choice network_choice extras_choice init
    dm_choice="$(state_get DE_MIG_DM "current")"
    x_choice="$(state_get DE_MIG_X "current")"
    audio_choice="$(state_get DE_MIG_AUDIO "current")"
    network_choice="$(state_get DE_MIG_NETWORK "current")"
    extras_choice="$(state_get DE_MIG_EXTRAS "")"
    init=$(detect_current_init)
    export INIT="${init}"

    if [[ "$dm_choice" != "current" ]]; then
        if [[ "$dm_choice" != "none" ]]; then
            local key="${dm_choice}-${init}"
            install_packages "${DM_PACKAGES[$key]:-}"
            _enable_service "${dm_choice}"
        else
            remove_packages "sddm sddm-openrc sddm-runit sddm-dinit sddm-s6 lightdm lightdm-gtk-greeter lightdm-openrc lightdm-runit lightdm-dinit lightdm-s6 sonic-login-manager sonic-login-manager-openrc sonic-login-manager-runit sonic-login-manager-dinit sonic-login-manager-s6 gdm"
        fi
    fi

    if [[ "$x_choice" != "current" ]]; then
        if [[ "$x_choice" == "xlibre" ]]; then
            remove_packages "xorg-server xf86-input-libinput xf86-input-evdev"
        elif [[ "$x_choice" == "xorg" ]]; then
            remove_packages "xlibre-xserver xlibre-xserver-common xlibre-input-libinput xlibre-input-evdev"
        fi
        install_packages "${X_PACKAGES[$x_choice]:-}"
    fi

    if [[ "$audio_choice" != "current" ]]; then
        remove_packages "pipewire pipewire-pulse pipewire-alsa wireplumber pipewire-jack pulseaudio pulseaudio-alsa"
        install_packages "${AUDIO_PACKAGES[$audio_choice]:-}"
    fi

    if [[ "$network_choice" != "current" ]]; then
        remove_packages "networkmanager networkmanager-openrc networkmanager-runit networkmanager-dinit networkmanager-s6"
        remove_packages "dhcpcd iwd dhcpcd-openrc dhcpcd-runit dhcpcd-dinit dhcpcd-s6 iwd-openrc iwd-runit iwd-dinit iwd-s6"
        remove_packages "connman connman-openrc connman-runit connman-dinit connman-s6"

        if [[ "$network_choice" != "none" ]]; then
            local key="${network_choice}-${init}"
            install_packages "${NETWORK_PACKAGES[$key]:-}"
            case "$network_choice" in
                networkmanager) _enable_service NetworkManager ;;
                dhcpcd+iwd) _enable_service dhcpcd; _enable_service iwd ;;
                connman) _enable_service connmand ;;
            esac
        fi
    fi

    if [[ -n "$extras_choice" ]]; then
        local pkg_list=""
        for extra in $extras_choice; do
            local p="${EXTRA_PACKAGES[$extra]:-}"
            if [[ -n "$p" ]]; then
                pkg_list+=" $p"
            fi
        done
        pkg_list="${pkg_list# }"
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

    if [[ "$source_de" == "none" ]]; then
        local default_dm="${DE_DISPLAY_MANAGER[$target_de]:-none}"
        state_set DE_MIG_DM "$default_dm"
        state_set DE_MIG_X "$(detect_current_x)"
        state_set DE_MIG_AUDIO "$(detect_current_audio)"
        state_set DE_MIG_NETWORK "$(detect_current_network)"
        state_set DE_MIG_EXTRAS ""
    else
        prompt_migration_choices
    fi

    if [[ "$source_de" != "none" ]]; then
        log_info "Removing $source_de packages..."
        remove_packages "${DE_PACKAGES[$source_de]:-}"
        if [[ -n "${MIG_ROOT}" ]]; then
            local orphan
            orphan=$(artix-chroot "${MIG_ROOT}" pacman -Qtdq 2>/dev/null || true)
            if [[ -n "$orphan" ]]; then
                log_info "Removing orphaned packages..."
                artix-chroot "${MIG_ROOT}" pacman -Rns --noconfirm $orphan 2>/dev/null || log_warn "Some orphans could not be removed"
            fi
        else
            local orphan
            orphan=$(pacman -Qtdq 2>/dev/null || true)
            if [[ -n "$orphan" ]]; then
                log_info "Removing orphaned packages..."
                pacman -Rns --noconfirm $orphan 2>/dev/null || log_warn "Some orphans could not be removed"
            fi
        fi
    fi

    if [[ "$target_de" != "none" ]]; then
        log_info "Installing $target_de packages..."
        install_packages "${DE_PACKAGES[$target_de]:-}"
    fi

    log_info "MIG_ROOT=${MIG_ROOT:-empty}"
    apply_migration_choices

    if [[ -x "${MIG_ROOT}/usr/bin/mkinitcpio" ]]; then
        _chroot mkinitcpio -P 2>/dev/null || true
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
        run_de_migration "$source_de" "$target_de"
    fi
}