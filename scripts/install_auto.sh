#!/usr/bin/env bash
set -eo pipefail;

if [[ "$*" == *"--debug"* ]]; then
    set -x;
fi

SELF_PATH="$(readlink -f "${BASH_SOURCE}")";
SCRIPT_DIR="${SELF_PATH%/*}";
source "${SCRIPT_DIR}/common.sh";
_load_state;

source "${SCRIPT_DIR}/engine.sh";
source "${SCRIPT_DIR}/pkgs.sh";

function _ask_passwords {
    [[ -z "${ROOT_PASS:-}" ]] && { printf "Root password: "; read -rs ROOT_PASS; printf "\n"; };
    [[ -z "${USER_PASS:-}" ]] && { printf "User password: "; read -rs USER_PASS; printf "\n"; };
    
    if [[ "${USE_LUKS}" == "yes" && -z "${LUKS_PASS:-}" ]]; then
        while true; do
            printf "LUKS Passphrase: "; read -rs LUKS_PASS; printf "\n"
            printf "Confirm LUKS Passphrase: "; read -rs LUKS_PASS_CONFIRM; printf "\n"
            if [[ -n "${LUKS_PASS}" && "${LUKS_PASS}" == "${LUKS_PASS_CONFIRM}" ]]; then
                break
            else
                printf "\e[1;31mPasswords not matching. Try again!\e[0m\n"
            fi
        done
    fi
}

function main {
    _is_efi;
    _check_internet;
    _load_state;
    [[ -z "${DISK:-}" ]] && _error_exit "no disk selected in state";

    _ensure_tools;
    _ask_passwords;
    _setup_storage;     
    _install_base;
    _load_state;
    _setup_bootloader;  
    _prepare_handoff;   
    artix-chroot /mnt /bin/bash <<EOF
echo "root:${ROOT_PASS}" | chpasswd
if ! id "${USER_NAME}" &>/dev/null; then
    useradd -m -G wheel,audio,storage -s "${USER_SHELL:-/bin/bash}" "${USER_NAME}"
    echo "${USER_NAME}:${USER_PASS}" | chpasswd
fi
if [[ -f /etc/sudoers ]]; then
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
fi
EOF
    umount -R /mnt 2>/dev/null || true;
    
    dialog --title " Success " --msgbox "Installation complete!\n\nYou can now reboot. Please log in as root on reboot!" 7 55
}
main;

