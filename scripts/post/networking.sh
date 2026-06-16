#!/usr/bin/env bash
set -Eeuo pipefail

setup_networking() {
    local network_stack="${NETWORK_STACK:-dhcpcd+iwd}" init="${INIT:-openrc}" pkgs=()
    case "${network_stack}" in
        networkmanager) pkgs+=(networkmanager "networkmanager-${init}") ;;
        connman)        pkgs+=(connman "connman-${init}") ;;
        dhcpcd+iwd)     pkgs+=(dhcpcd iwd "dhcpcd-${init}" "iwd-${init}") ;;
        none) return 0 ;;
    esac

    if [[ "${network_stack}" != "networkmanager" ]] && pacman -Q networkmanager &>/dev/null; then
        log_warn "NetworkManager is installed but ${network_stack} was selected. Remove it manually if conflicts arise."
    fi
    if [[ "${network_stack}" != "connman" ]] && pacman -Q connman &>/dev/null; then
        log_warn "ConnMan is installed but ${network_stack} was selected. Remove it manually if conflicts arise."
    fi
    if [[ "${network_stack}" != "dhcpcd+iwd" ]]; then
        if pacman -Q dhcpcd &>/dev/null || pacman -Q iwd &>/dev/null; then
            log_warn "dhcpcd/iwd is installed but ${network_stack} was selected. Remove manually if conflicts arise."
        fi
    fi

    local -a to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Q "${pkg}" &>/dev/null; then
            to_install+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        pacman -S --noconfirm --needed "${to_install[@]}"
    else
        log_info "Network packages already installed — skipping."
    fi

    case "${network_stack}" in
        networkmanager) enable_service NetworkManager || log_warn "Failed to enable NetworkManager" ;;
        connman)        enable_service connmand || log_warn "Failed to enable connmand" ;;
        dhcpcd+iwd)
            enable_service dhcpcd || log_warn "Failed to enable dhcpcd"
            enable_service iwd || log_warn "Failed to enable iwd"
            ;;
    esac
}