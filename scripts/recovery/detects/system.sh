#!/usr/bin/env bash
set -Eeuo pipefail

detect_init() {
    if [[ -d "${ROOT}/etc/runit" ]]; then
        state_set INIT runit
    elif [[ -d "${ROOT}/etc/dinit.d" ]]; then
        state_set INIT dinit
    elif [[ -d "${ROOT}/etc/s6" ]]; then
        state_set INIT s6
    else
        state_set INIT openrc
    fi
}

detect_filesystem() {
    local fs
    fs="$(findmnt -no FSTYPE "${ROOT}" 2>/dev/null || true)"
    [[ -n "${fs}" ]] || fs='ext4'
    state_set FS_TYPE "${fs}"
}

detect_zfs() {
    if pacman_root_has zfs-utils || pacman_root_has zfs-dkms; then
        state_set FS_TYPE zfs
    fi
}

detect_lvm() {
    if [[ -f "${ROOT}/etc/lvm/lvm.conf" ]] || pacman_root_has lvm2; then
        state_set USE_LVM yes
    else
        state_set USE_LVM no
    fi
}

detect_bootloader() {
    if [[ -d "${ROOT}/boot/grub" ]] || [[ -f "${ROOT}/boot/grub/grub.cfg" ]]; then
        state_set BOOTLOADER grub
    elif [[ -d "${ROOT}/boot/EFI/refind" ]] || [[ -f "${ROOT}/boot/refind_linux.conf" ]]; then
        state_set BOOTLOADER refind
    elif [[ -f "${ROOT}/boot/efi/EFI/BOOT/BOOTX64.EFI" ]] || [[ -f "${ROOT}/boot/limine.conf" ]] || [[ -f "${ROOT}/boot/efi/limine.conf" ]]; then
        state_set BOOTLOADER limine
    else
        state_set BOOTLOADER efistub
    fi
}

detect_uki() {
    if [[ -f "${ROOT}/boot/efi/EFI/Artix/linux-custom.efi" ]] || \
        compgen -G "${ROOT}/boot/efi/EFI/Linux/artix-*.efi" >/dev/null 2>&1 || \
        grep -qE 'default_uki|uki_output' "${ROOT}/etc/mkinitcpio.d/"*.preset 2>/dev/null; then
        state_set GENERATE_UKI yes
    else
        state_set GENERATE_UKI no
    fi
}

detect_kernel() {
    if [[ -f "${ROOT}/boot/vmlinuz-linux-custom" ]]; then
        state_set KERNEL_CHOICE linux-custom
        return 0
    fi

    local -a kernel_list=(
        linux-zen linux-lts linux-hardened linux-libre
        linux-cachyos-bmq linux-cachyos-eevdf linux-cachyos-rt-bore
        linux-cachyos-hardened linux-cachyos-lts linux-cachyos-server
        linux-cachyos-deckify linux-cachyos-bore linux-cachyos
        linux-bazzite-bin
        linux-xanmod-x64v4 linux-xanmod-x64v3 linux-xanmod-x64v2 linux-xanmod
        linux-tkg linux-tkg-bore linux
    )

    for k in "${kernel_list[@]}"; do
        if pacman_root_has "${k}"; then
            state_set KERNEL_CHOICE "${k#linux-}"
            return 0
        fi
    done

    if [[ -d "${ROOT}/opt/linux-tkg" ]]; then
        state_set KERNEL_CHOICE tkg
        return 0
    fi

    local kver
    kver=$(ls "${ROOT}/boot/vmlinuz-"* 2>/dev/null | head -n1 | sed 's/.*vmlinuz-//')
    case "${kver}" in
        *zen*)      state_set KERNEL_CHOICE linux-zen ;;
        *lts*)      state_set KERNEL_CHOICE linux-lts ;;
        *hardened*) state_set KERNEL_CHOICE linux-hardened ;;
        *)          state_set KERNEL_CHOICE linux ;;
    esac
}