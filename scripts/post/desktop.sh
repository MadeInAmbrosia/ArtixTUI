#!/usr/bin/env bash
set -Eeuo pipefail

install_sonicde() {
    log_info "Setting up SonicDE repository..."
    
    sed -i '/^\[sonicde\]/,/^\[/d' /etc/pacman.conf
    
    cat <<'EOF' >> /etc/pacman.conf
[sonicde]
Server = https://sonicde-artix.github.io/$arch
EOF

    log_info "Importing SonicDE signing key..."
    curl -sL https://sonicde-artix.github.io/sonicde-artixlinux.asc -o /tmp/sonicde.asc
    pacman-key --add /tmp/sonicde.asc
    pacman-key --finger 72AAA51726BC3C29
    pacman-key --lsign-key 72AAA51726BC3C29
    rm -f /tmp/sonicde.asc
    
    pacman -Syy --noconfirm
    yes | pacman -S --needed sonicde-meta 2>/dev/null || true
    
    log_info "SonicDE repository configured with proper signature verification."
}

install_mango() {
    log_info "Setting up Chaotic-AUR for MangoWM..."
    export GNUPGHOME="/etc/pacman.d/gnupg"
    mkdir -p "${GNUPGHOME}"
    chmod 700 "${GNUPGHOME}"
    [[ "$(state_get ENABLE_ARCH_REPOS no)" == 'yes' ]] && pacman -S --noconfirm archlinux-keyring || { log_error "Failed to install Arch Linux keyring."; return 1; }
    pacman-key --init || { log_error "Failed to initialize pacman keys."; return 1; }
    pacman-key --populate artix archlinux || { log_error "Failed to populate pacman keys."; return 1; }
    rm -f /var/cache/pacman/pkg/chaotic-keyring* /var/cache/pacman/pkg/chaotic-mirrorlist*
    pacman-key --recv-key 3056513887B78AEB --keyserver hkp://keyserver.ubuntu.com || { log_error "Failed to receive Chaotic-AUR key."; return 1; }
    pacman-key --lsign-key 3056513887B78AEB || { log_error "Failed to locally sign Chaotic-AUR key."; return 1; }
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || { log_error "Failed to install Chaotic-AUR bootstrap packages."; return 1; }
    grep -q '^\[chaotic-aur\]' /etc/pacman.conf || cat <<'EOF' >> /etc/pacman.conf
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    pacman -Sy --noconfirm || { log_error "Failed to sync package databases."; return 1; }
}

install_mango_aur() {
    local aur_dir="/tmp/mango-deps"
    rm -rf "${aur_dir}"
    mkdir -p "${aur_dir}"

    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/artixforge-mango
    chmod 440 /etc/sudoers.d/artixforge-mango
    trap 'rm -f /etc/sudoers.d/artixforge-mango; rm -rf /tmp/mango-deps' RETURN

    for repo in wlroots0.19-hidpi-xprop scenefx0.4 mangowm-git; do
        git clone "https://aur.archlinux.org/${repo}.git" "${aur_dir}/${repo}" || {
            log_error "Failed to clone ${repo}"
            return 1
        }
        chown -R "${USER_NAME}:${USER_NAME}" "${aur_dir}/${repo}"
        su - "${USER_NAME}" -c "cd '${aur_dir}/${repo}' && makepkg -si --noconfirm" || {
            log_error "Failed to build ${repo}"
            return 1
        }
    done

    log_info "MangoWM installation complete."
}

install_vxwm_source() {
    log_info "Building vxwm from source..."
    local vxwm_dir='/tmp/vxwm'
    trap 'rm -rf /tmp/vxwm' RETURN
    rm -rf "${vxwm_dir}"
    git clone 'https://codeberg.org/wh1tepearl/vxwm.git' "${vxwm_dir}" || { log_error "Failed to clone vxwm repo."; return 1; }
    chown -R "${USER_NAME}:${USER_NAME}" "${vxwm_dir}"
    su - "${USER_NAME}" -c "cd '${vxwm_dir}' && make clean && make" || { log_error "Failed to build vxwm."; return 1; }
    make -C "${vxwm_dir}" install || { log_error "Failed to install vxwm."; return 1; }
    log_info "vxwm installed successfully."
}

install_desktop() {
    local wm_de init display_manager kde_profile
    local -a pkgs=()

    wm_de="$(printf '%s' "${WM_DE:-none}" | tr -d '[:space:]')"
    init="$(printf '%s' "${INIT:-openrc}" | tr -d '[:space:]')"
    display_manager="$(printf '%s' "${DISPLAY_MANAGER:-none}" | tr -d '[:space:]')"
    kde_profile='none'

    export USER_NAME="${USER_1_NAME:-${USER_NAME:-artix}}"

    if [[ "${wm_de}" == 'kde' ]]; then
        kde_profile="$(state_get KDE_PROFILE desktop)"
    fi

    log_info "Verifying dbus service..."
    service_exists dbus || { log_error "dbus service missing for init: ${init}"; return 1; }
    enable_service dbus

    case "${wm_de}" in
        xfce4)    pkgs+=(xfce4 xfce4-goodies) ;;
        lxqt)     pkgs+=(lxqt) ;;
        lxde)     pkgs+=(lxde lxappearance) ;;
        i3wm)     pkgs+=(i3-wm i3status i3lock dmenu xterm) ;;
        vxwm)     pkgs+=(base-devel git libx11 libxft libxinerama freetype2 xorg-server xorg-xinit xterm) ;;
        dwm)      pkgs+=(dwm dmenu xterm) ;;
        icewm)    pkgs+=(icewm icewm-themes xterm) ;;
        none)     return 0 ;;

        sonicde)
            install_sonicde
            pkgs+=(sonicde-meta)
            if [[ "${display_manager}" == "sddm" ]]; then
                display_manager="soniclogin"
            fi
            ;;

        kde)
            case "${kde_profile}" in
                minimal)       pkgs+=(plasma-desktop dolphin konsole xdg-desktop-portal-kde) ;;
                full|edge)     pkgs+=(plasma kde-applications xdg-desktop-portal-kde) ;;
                desktop|*)     pkgs+=(plasma xdg-desktop-portal-kde) ;;
            esac

            if [[ "${display_manager}" == "lightdm" ]]; then
                pkgs+=(lightdm lightdm-gtk-greeter "lightdm-${init}")
            fi

            if [[ "${x_stack:-xorg}" == 'xlibre' ]]; then
                pkgs+=(xlibre-input-wacom)
            fi
            ;;

        hyprland)
            pkgs+=(hyprland foot waybar wofi xdg-desktop-portal-hyprland seatd "seatd-${init}") ;;

        niri)
            pkgs+=(niri foot waybar fuzzel xdg-desktop-portal-gtk seatd "seatd-${init}") ;;

        sway)
            pkgs+=(sway swaybg swaylock swayidle foot waybar wofi xdg-desktop-portal-wlr seatd "seatd-${init}") ;;

        mango)
            install_mango
            pkgs+=(foot waybar wofi xdg-desktop-portal-hyprland seatd "seatd-${init}" base-devel git cjson xorg-xwayland)
            ;;

        cinnamon)
            pkgs+=(cinnamon lightdm lightdm-gtk-greeter "lightdm-${init}" xdg-desktop-portal-gtk)
            ;;

        budgie)
            pkgs+=(budgie-desktop budgie-screensaver budgie-control-center lightdm lightdm-gtk-greeter "lightdm-${init}" xdg-desktop-portal-gtk)
            ;;

        moksha)
            pkgs+=(moksha terminology lightdm lightdm-gtk-greeter "lightdm-${init}")
            ;;

        cosmic)
            pkgs+=(cosmic cosmic-terminal cosmic-text-editor cosmic-files cosmic-settings cosmic-launcher lightdm lightdm-gtk-greeter "lightdm-${init}")
            log_warn "COSMIC is alpha software — expect bugs and missing features"
            ;;
    esac

    case "${display_manager}" in
        lightdm)
            if [[ "${wm_de}" != "kde" && "${wm_de}" != "cinnamon" && "${wm_de}" != "budgie" && "${wm_de}" != "moksha" && "${wm_de}" != "cosmic" ]]; then
                pkgs+=(lightdm lightdm-gtk-greeter "lightdm-${init}")
            fi
            ;;
        soniclogin)
            pkgs+=(sonic-login-manager "sonic-login-manager-${init}")
            ;;
        sddm)    pkgs+=(sddm "sddm-${init}") ;;
    esac

    log_info "Installing desktop environment..."
    log_info "Desktop package list:"
    printf ' - %s\n' "${pkgs[@]}"
    clean_pacman_lock
    if ! retry_command "desktop install" pacman -S --noconfirm --needed "${pkgs[@]}"; then
        log_error "Failed to install desktop packages."
        return 1
    fi

    if [[ "${wm_de}" == 'mango' ]]; then
        install_mango_aur
    fi

    if [[ "${wm_de}" == 'vxwm' ]]; then
        install_vxwm_source
    fi

    if [[ "${wm_de}" == "kde" && "${display_manager}" == "lightdm" ]]; then
        log_info "Replacing SDDM with LightDM..."
        pacman -Rdd --noconfirm sddm "sddm-${init}" 2>/dev/null || true
    fi

    case "${display_manager}" in
        lightdm)     enable_service lightdm || log_warn "Failed to enable LightDM" ;;
        soniclogin)  enable_service soniclogin || log_warn "Failed to enable Sonic Login Manager" ;;
        sddm)        enable_service sddm || log_warn "Failed to enable SDDM" ;;
    esac

    case "${wm_de}" in
        hyprland|mango|niri|sway|cosmic)
            log_info "Verifying seatd service..."
            service_exists seatd || { log_error "seatd service missing for init: ${init}"; return 1; }
            enable_service seatd || log_warn "Failed to enable seatd" ;;
    esac

    log_info "Desktop installation complete."
}