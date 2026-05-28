#!/usr/bin/env bash
set -Eeuo pipefail

install_extras() {
    local selected=" ${EXTRAS:-} " pkgs=() init="${INIT:-openrc}"

    [[ "${selected}" == *" git "* ]] && pkgs+=(git base-devel)

    if [[ "${selected}" == *" rsvc "* ]]; then
        if [[ "${init}" != 'runit' ]]; then
            log_warn "rsvc only supported on runit systems. Skipping."
        else
            [[ "${selected}" == *" git "* ]] || pkgs+=(git base-devel)
        fi
    fi

    [[ "${selected}" == *" flatpak "* ]] && pkgs+=(flatpak)
    [[ "${selected}" == *" firewalld "* ]] && pkgs+=(firewalld "firewalld-${init}")
    [[ "${selected}" == *" bluez "* ]] && pkgs+=(bluez bluez-utils "bluez-${init}")
    [[ "${selected}" == *" zram-tools "* ]] && pkgs+=(zram-tools "zram-tools-${init}")
    [[ "${selected}" == *" usb_modeswitch "* ]] && pkgs+=(usb_modeswitch)

    [[ "${selected}" == *" nano "* ]] && pkgs+=(nano)
    [[ "${selected}" == *" vim "* ]] && pkgs+=(vim)
    [[ "${selected}" == *" neovim "* ]] && pkgs+=(neovim)
    [[ "${selected}" == *" micro "* ]] && pkgs+=(micro)
    [[ "${selected}" == *" helix "* ]] && pkgs+=(helix)

    [[ "${selected}" == *" firefox "* ]] && pkgs+=(firefox)
    [[ "${selected}" == *" chromium "* ]] && pkgs+=(chromium)
    [[ "${selected}" == *" qutebrowser "* ]] && pkgs+=(qutebrowser)

    [[ "${selected}" == *" ranger "* ]] && pkgs+=(ranger)
    [[ "${selected}" == *" lf "* ]] && pkgs+=(lf)
    [[ "${selected}" == *" nnn "* ]] && pkgs+=(nnn)
    [[ "${selected}" == *" thunar "* ]] && pkgs+=(thunar)

    [[ "${selected}" == *" alacritty "* ]] && pkgs+=(alacritty)
    [[ "${selected}" == *" kitty "* ]] && pkgs+=(kitty)
    [[ "${selected}" == *" foot "* ]] && pkgs+=(foot)

    [[ "${selected}" == *" fastfetch "* ]] && pkgs+=(fastfetch)
    [[ "${selected}" == *" fzf "* ]] && pkgs+=(fzf)
    [[ "${selected}" == *" zoxide "* ]] && pkgs+=(zoxide)
    [[ "${selected}" == *" starship "* ]] && pkgs+=(starship)
    [[ "${selected}" == *" eza "* ]] && pkgs+=(eza)
    [[ "${selected}" == *" tmux "* ]] && pkgs+=(tmux)

    [[ "${selected}" == *" btop "* ]] && pkgs+=(btop)
    [[ "${selected}" == *" htop "* ]] && pkgs+=(htop)
    [[ "${selected}" == *" nvtop "* ]] && pkgs+=(nvtop)

    [[ "${selected}" == *" mpv "* ]] && pkgs+=(mpv)
    [[ "${selected}" == *" feh "* ]] && pkgs+=(feh)

    if [[ ${#pkgs[@]} -eq 0 && "${selected}" != *" rsvc "* ]]; then return 0; fi

    log_info "Installing extras..."
    [[ ${#pkgs[@]} -gt 0 ]] && pacman -S --noconfirm --needed "${pkgs[@]}"

    [[ "${selected}" == *" firewalld "* ]] && enable_service firewalld
    [[ "${selected}" == *" bluez "* ]] && enable_service bluetooth
    [[ "${selected}" == *" zram-tools "* ]] && enable_service zramd

    if [[ "${selected}" == *" rsvc "* && "${init}" == 'runit' ]]; then
        log_info "Installing rsvc..."
        git clone https://github.com/SashexSRB/rsvc /tmp/rsvc || true
        ( cd /tmp/rsvc && make && make install )
    fi

    log_info "Extras installation complete."
}