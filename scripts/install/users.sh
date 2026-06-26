#!/usr/bin/env bash
set -Eeuo pipefail

configure_users() {
    local priv_esc wm_de
    priv_esc="$(state_get PRIV_ESCALATION sudo)"
    wm_de="$(state_get WM_DE none)"

    # Safety net in-case the user bit the dust
    if [[ ${USER_COUNT:-0} -eq 0 ]]; then
        state_set USER_COUNT 1
        state_set USER_1_NAME "artix"
        state_set USER_1_SHELL "/bin/bash"
        state_set USER_1_GROUPS "wheel,audio,video,storage"
        state_set USER_1_SUDO "yes"
        log_warn "No users configured — creating default user 'artix'"
    fi

    local user_count="${USER_COUNT:-1}"

    for ((i=1; i<=user_count; i++)); do
        local username password shell ugroups usudo
        username="$(state_get "USER_${i}_NAME" "")"
        password="$(state_get "USER_${i}_PASS" "")"
        shell="$(state_get "USER_${i}_SHELL" "/bin/bash")"
        ugroups="$(state_get "USER_${i}_GROUPS" "wheel,audio,video,storage")"
        usudo="$(state_get "USER_${i}_SUDO" "yes")"

        [[ -n "${username}" ]] || continue
        [[ "${username}" =~ ^[a-z_][a-z0-9_-]*$ ]] || {
            log_warn "Invalid username '${username}' — skipping"
            continue
        }

        case "${shell}" in
            bash) shell="/bin/bash" ;;
            zsh)  shell="/bin/zsh" ;;
            fish) shell="/usr/bin/fish" ;;
        esac
        [[ -x "/mnt${shell}" ]] || shell="/bin/bash"

        local user_hash
        if [[ "${password}" == '$6$'* ]]; then
            user_hash="${password}"
        elif [[ -n "${password}" ]]; then
            user_hash=$(openssl passwd -6 -- "${password}") || {
                log_warn "Failed to hash password for ${username}"
                user_hash=""
            }
        fi

        log_info "Creating user ${username}..."

        artix-chroot /mnt /bin/bash -c "
set -Eeuo pipefail
if ! id '${username}' &>/dev/null; then
    useradd -m -G '${ugroups//,/ }' -s '${shell}' '${username}'
fi
[[ -n '${user_hash}' ]] && usermod -p '${user_hash}' '${username}'

if [[ '${wm_de}' =~ ^(hyprland|sway|niri|mango|cosmic)$ ]]; then
    usermod -aG seat '${username}'
fi
"

        if [[ "${usudo}" == "yes" ]]; then
            if [[ "${priv_esc}" == "doas" ]]; then
                echo "permit persist ${username}" >> /mnt/etc/doas.conf
            else
                mkdir -p /mnt/etc/sudoers.d
                echo "${username} ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers.d/99-artixforge
            fi
        fi
    done

    if [[ -f /mnt/etc/sudoers.d/99-artixforge ]]; then
        chmod 440 /mnt/etc/sudoers.d/99-artixforge
    fi
    if [[ -f /mnt/etc/doas.conf ]]; then
        chmod 0400 /mnt/etc/doas.conf
    fi

    if [[ "${priv_esc}" == "sudo" ]]; then
        artix-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        artix-chroot /mnt sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
    fi

    local root_password root_hash
    root_password="$(state_get ROOT_PASS "")"
    if [[ -n "${root_password}" ]]; then
        if [[ "${root_password}" == '$6$'* ]]; then
            root_hash="${root_password}"
        else
            root_hash=$(openssl passwd -6 -- "${root_password}") || die 'failed to hash root password'
        fi
        artix-chroot /mnt usermod -p "${root_hash}" root
        log_info "Root password set."
    fi

    export USER_NAME="${USER_1_NAME:-artix}"

    log_info "User configuration complete."
}