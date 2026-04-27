#!/usr/bin/env bash
set -eo pipefail;

if [[ "$*" == *"--debug"* ]]; then
    set -x;
fi

SELF_PATH="$(readlink -f "${BASH_SOURCE}")";
SCRIPT_DIR="${SELF_PATH%/*}";

source "${SCRIPT_DIR}/common.sh";
source "${SCRIPT_DIR}/engine.sh";
source "${SCRIPT_DIR}/pkgs.sh";

ROOT_PASS="";
USER_PASS="";
USER_NAME="";
USER_SHELL="/bin/bash"; 

function _verify_mounts {
    printf "[*] Verifying manual mounts...\n";
    findmnt /mnt >/dev/null || _error_exit "/mnt is not mounted. Please mount your root partition.";

    if [[ "${BOOTLOADER:-}" == "efistub" ]]; then
        findmnt /mnt/boot >/dev/null || _error_exit "EFIStub requires EFI partition mounted on /mnt/boot";
    else
        if ! findmnt /mnt/boot/efi >/dev/null && ! findmnt /mnt/boot >/dev/null; then
             _error_exit "EFI partition not found on /mnt/boot or /mnt/boot/efi";
        fi
    fi
}

function _detect_existing_stack {
    printf "[*] Detecting environment...\n";
    FS_TYPE=$(findmnt -no FSTYPE /mnt);

    local root_dev;
    read -r root_dev < <(findmnt -no SOURCE /mnt);
    
    if [[ "${root_dev}" == /dev/mapper/* ]]; then
        USE_LUKS="yes";
        printf "[*] LUKS detected: %s\n" "${root_dev}";
    else
        USE_LUKS="no";
        LUKS_PASS="";
    fi

    DISK=$(lsblk -no PKNAME "${root_dev}" | head -n1 | awk '{print "/dev/"$1}');
    [[ -z "${DISK}" || "${DISK}" == "/dev/" ]] && DISK=$(echo "${root_dev}" | sed -E 's/p?[0-9]+$//');
    
    printf "[✓] Target disk identified as: %s\n" "${DISK}";
    _save_state;
}

function _ask_user_info {
    USER_NAME=$(dialog --stdout --title "User Account" --inputbox "Enter username for the new system:" 10 50);
    [[ -z "${USER_NAME}" ]] && _error_exit "Username cannot be empty";

    while true; do
        printf "Enter password for ${USER_NAME}: "; read -rs USER_PASS; echo;
        printf "Confirm password: "; read -rs USER_PASS_CONFIRM; echo;
        [[ "${USER_PASS}" == "${USER_PASS_CONFIRM}" && -n "${USER_PASS}" ]] && break
        printf "\e[1;31mPasswords do not match! Try again.\e[0m\n"
    done

    while true; do
        printf "Enter Root password: "; read -rs ROOT_PASS; echo;
        printf "Confirm Root password: "; read -rs ROOT_PASS_CONFIRM; echo;
        [[ "${ROOT_PASS}" == "${ROOT_PASS_CONFIRM}" && -n "${ROOT_PASS}" ]] && break
        printf "\e[1;31mPasswords do not match! Try again.\e[0m\n"
    done

    _save_state;
}

function main {
    _is_efi;
    _check_internet;

    INIT=$(dialog --stdout --title "Init System" --menu "Select your init:" 12 40 4 "openrc" "" "runit" "" "dinit" "" "s6" "");
    KERNEL_CHOICE=$(dialog --stdout --title "Kernel" --menu "Select kernel to install:" 12 40 4 "linux" "" "linux-lts" "" "xanmod" "" "tkg" "");
    BOOTLOADER=$(dialog --stdout --title "Bootloader" --menu "Select bootloader:" 12 40 3 "grub" "" "refind" "" "efistub" "");
    WM_DE=$(dialog --stdout --title "Interface" --menu "Select DE/WM:" 15 45 7 "xfce4" "" "hyprland" "" "i3wm" "" "dwm" "" "none" "");

    _verify_mounts;
    _detect_existing_stack;
    _ask_user_info;

    _ensure_tools;
    _install_base;
    _setup_bootloader;
    _prepare_handoff;

    artix-chroot /mnt /bin/bash <<EOF
echo "root:${ROOT_PASS}" | chpasswd
if ! id "${USER_NAME}" &>/dev/null; then
    useradd -m -G wheel,audio,storage -s "${USER_SHELL}" "${USER_NAME}"
    echo "${USER_NAME}:${USER_PASS}" | chpasswd
fi
EOF

    printf "\n[✓] Manual installation finished. Unmounting...\n";
    umount -R /mnt 2>/dev/null || true;
    
    dialog --title "Success" --msgbox "Manual installation complete! You can reboot now." 6 50
}

main;
