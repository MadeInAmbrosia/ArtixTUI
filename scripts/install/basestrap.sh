#!/usr/bin/env bash
set -Eeuo pipefail

install_base_system() {
    local init kernel fs_type bootloader network_stack user_shell display_manager wm_de locale keymap timezone microcode_override

    init="$(state_get INIT)"
    kernel="$(state_get KERNEL_CHOICE linux)"
    fs_type="$(state_get FS_TYPE ext4)"
    bootloader="$(state_get BOOTLOADER grub)"
    network_stack="$(state_get NETWORK_STACK dhcpcd+iwd)"
    user_shell="$(state_get USER_SHELL bash)"
    display_manager="$(state_get DISPLAY_MANAGER none)"
    wm_de="$(state_get WM_DE none)"
    locale="$(state_get LOCALE en_US.UTF-8)"
    keymap="$(state_get KEYMAP us)"
    timezone="$(state_get TIMEZONE UTC)"
    microcode_override="$(state_get MICROCODE_OVERRIDE auto)"

    detect_kernel_package "${kernel}"

    local ucode='amd-ucode'
    grep -q 'GenuineIntel' /proc/cpuinfo && ucode='intel-ucode'

    case "${microcode_override}" in
        intel) ucode='intel-ucode' ;;
        amd)   ucode='amd-ucode' ;;
        none)  ucode='' ;;
    esac

    local priv_esc
    priv_esc="$(state_get PRIV_ESCALATION sudo)"

    local init_pkg="${init}"
    local seatd_suffix="${init}"
    local elogind_suffix="${init}"
    if [[ "${init}" == "busybox" ]]; then
        init_pkg=""
        seatd_suffix=""
        elogind_suffix=""
    fi

    local pkgs=(
        base base-devel linux-firmware bash nano vim "${priv_esc}"
        git curl wget pciutils "${init_pkg}" dbus efibootmgr dosfstools mkinitcpio
    )
    [[ -n "${ucode}" ]] && pkgs+=("${ucode}")

    case "${wm_de}" in
        hyprland|mango|niri|sway)
            [[ -n "${seatd_suffix}" ]] && pkgs+=(seatd "seatd-${seatd_suffix}") ;;
        *)
            [[ -n "${elogind_suffix}" ]] && pkgs+=("elogind-${elogind_suffix}") ;;
    esac

    case "${user_shell}" in
        bash) ;;
        zsh)  pkgs+=(zsh) ;;
        fish) pkgs+=(fish) ;;
        *)    die "unsupported shell: ${user_shell}" ;;
    esac

    local skip_binary_kernel=0
    [[ "$(state_get POWER_USER no)" == "yes" && "$(state_get KEEP_BINARY_KERNEL yes)" == "no" ]] && skip_binary_kernel=1

    case "${kernel}" in
        linux|linux-zen|linux-lts|linux-hardened)
            if [[ $skip_binary_kernel -eq 1 ]]; then
                log_info "Skipping binary ${kernel} kernel (fallback disabled)"
            else
                pkgs+=("${KERNEL_PACKAGE}" "${KERNEL_HEADERS}")
            fi
            ;;
        linux-libre)
            if [[ $skip_binary_kernel -eq 1 ]]; then
                log_info "Skipping binary linux-libre kernel (fallback disabled)"
            else
                log_info "Enabling linux-libre repository..."
                if ! grep -q '^\[libre\]' /etc/pacman.conf; then
                    cat <<'EOF' >> /etc/pacman.conf
[libre]
SigLevel = Never
Server = https://repo.parabola.nu/libre/os/x86_64
EOF
                fi
                pkgs+=(linux-libre linux-libre-headers)
                log_warn "linux-libre removes non-free firmware/drivers. NVIDIA, Wi‑Fi, Bluetooth may stop working."
            fi
            ;;
        linux-cachyos-bore)
            if [[ $skip_binary_kernel -eq 1 ]]; then
                log_info "Skipping binary cachyos kernel (fallback disabled)"
            else
                log_info "Setting up CachyOS repository..."
                pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
                pacman-key --lsign-key F3B607488DB35A47
                local cachyos_keyring cachyos_mirrorlist
                cachyos_keyring=$(curl -sL 'https://mirror.cachyos.org/repo/x86_64/cachyos/' | grep -oP 'cachyos-keyring-\d+.*?\.pkg\.tar\.zst' | sort -V | tail -1)
                cachyos_mirrorlist=$(curl -sL 'https://mirror.cachyos.org/repo/x86_64/cachyos/' | grep -oP 'cachyos-mirrorlist-\d+.*?\.pkg\.tar\.zst' | sort -V | tail -1)
                if [[ -z "${cachyos_keyring}" || -z "${cachyos_mirrorlist}" ]]; then
                    log_warn "Could not scrape CachyOS mirror — trying static fallback URLs"
                    cachyos_keyring="cachyos-keyring-20250101-1-any.pkg.tar.zst"
                    cachyos_mirrorlist="cachyos-mirrorlist-20250101-1-any.pkg.tar.zst"
                fi
                pacman -U --noconfirm "https://mirror.cachyos.org/repo/x86_64/cachyos/${cachyos_keyring}" "https://mirror.cachyos.org/repo/x86_64/cachyos/${cachyos_mirrorlist}" || {
                    log_error "Failed to install CachyOS bootstrap packages — mirror may be down"
                    die 'CachyOS repository setup failed'
                }
                if ! grep -q '^\[cachyos\]' /etc/pacman.conf; then
                    cat <<'EOF' >> /etc/pacman.conf
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
                fi
                pkgs+=(linux-cachyos-bore linux-cachyos-bore-headers)
            fi
            ;;
        linux-bazzite-bin)
            if [[ $skip_binary_kernel -eq 1 ]]; then
                log_info "Skipping binary bazzite kernel (fallback disabled)"
            else
                log_info "Setting up Bazzite kernel AUR build..."
                if ! pacman -Q artix-archlinux-support >/dev/null 2>&1; then
                    pacman -S --noconfirm --needed artix-archlinux-support
                fi
                local arch_mirrorlist='/etc/pacman.d/mirrorlist-arch'
                if [[ ! -f "${arch_mirrorlist}" ]]; then
                    install -Dm644 /dev/null "${arch_mirrorlist}"
                    cat > "${arch_mirrorlist}" <<'MIRROR_EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRROR_EOF
                fi
                if ! grep -q '^\[extra\]' /etc/pacman.conf; then
                    cat <<'EOF' >> /etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
                fi
                if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
                    cat <<'EOF' >> /etc/pacman.conf
[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
                fi
                pkgs+=(base-devel git mkinitcpio)
            fi
            ;;
        xanmod)
            if [[ $skip_binary_kernel -eq 1 ]]; then
                log_info "Skipping binary xanmod kernel (fallback disabled)"
            else
                log_info "Setting up Chaotic-AUR for XanMod..."
                export GNUPGHOME="/etc/pacman.d/gnupg"
                mkdir -p "${GNUPGHOME}"
                chmod 700 "${GNUPGHOME}"
                pacman-key --init
                pacman-key --populate artix
                pacman-key --recv-keys 3056513887B78AEB --keyserver hkp://keyserver.ubuntu.com
                pacman-key --lsign-key 3056513887B78AEB
                pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
                if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
                    cat <<'EOF' >> /etc/pacman.conf
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
                fi
                pkgs+=("${KERNEL_PACKAGE}" "${KERNEL_HEADERS}")
            fi
            ;;
        tkg)
            log_info "Setting up TKG build dependencies..."
            pkgs+=(bc cpio flex libelf pahole base-devel git dkms)
            ;;
        *)
            die "unsupported kernel: ${kernel}" ;;
    esac

    case "${network_stack}" in
        dhcpcd+iwd)     pkgs+=(dhcpcd iwd "dhcpcd-${init}" "iwd-${init}") ;;
        networkmanager) pkgs+=(networkmanager "networkmanager-${init}") ;;
        connman)        pkgs+=(connman "connman-${init}") ;;
        none) ;;
    esac

    case "${fs_type}" in
        btrfs)
            pkgs+=(btrfs-progs snapper snap-pac grub-btrfs)
            if [[ "$(state_get BOOTLOADER grub)" == "limine" ]]; then
                pkgs+=(limine-snapper-sync)
            fi
            ;;
        ext4)      pkgs+=(e2fsprogs) ;;
        xfs)       pkgs+=(xfsprogs) ;;
        f2fs)      pkgs+=(f2fs-tools) ;;
        bcachefs)  pkgs+=(bcachefs-tools bcachefs-dkms) ;;
        exfat)     pkgs+=(exfatprogs) ;;
        zfs)
            log_info "Setting up OpenZFS repository..."
            if ! grep -q '^\[archzfs\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf
[archzfs]
Server = https://archzfs.com/$repo/x86_64
EOF
            fi
            pacman-key --recv-keys F75D9D76 --keyserver hkp://keyserver.ubuntu.com
            pacman-key --lsign-key F75D9D76
            pkgs+=(dkms zfs-dkms zfs-utils zfs-initramfs)
            log_warn "ZFS support is experimental. DKMS rebuilds may be required."
            ;;
        *) die "unsupported filesystem: ${fs_type}" ;;
    esac

    case "${bootloader}" in
        grub)    pkgs+=(grub os-prober) ;;
        refind)  pkgs+=(refind) ;;
        efistub) ;;
        limine)  pkgs+=(limine) ;;
    esac

    if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
        pkgs+=(lvm2 "lvm2-${init}")
    fi

    if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
        pkgs+=(cryptsetup "cryptsetup-${init}")
    fi

    if [[ "$(state_get GENERATE_UKI no)" == "yes" ]]; then
        pkgs+=(eukify)
    fi

    printf '%s\n' "${pkgs[@]}" > "${PWD}/artix-pkgs.log"

    local debug_log="${PWD}/basestrap-debug.log"
    : > "${debug_log}"

    export GNUPGHOME="${GNUPGHOME:-/etc/pacman.d/gnupg}"
    mkdir -p "${GNUPGHOME}"
    chmod 700 "${GNUPGHOME}"
    log_info "Initializing Artix keyring..."
    pacman-key --init
    pacman-key --populate artix

    if [[ "$(state_get ENABLE_ARCH_REPOS no)" == 'yes' ]]; then
        log_info "Installing Arch repository support..."
        pacman -S --noconfirm --needed artix-archlinux-support
        local arch_mirrorlist='/etc/pacman.d/mirrorlist-arch'
        if [[ ! -f "${arch_mirrorlist}" ]]; then
            install -Dm644 /dev/null "${arch_mirrorlist}"
            cat > "${arch_mirrorlist}" <<'MIRROR_EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRROR_EOF
        fi

        if ! grep -q '^\[extra\]' /etc/pacman.conf; then
            cat <<'EOF' >> /etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
        fi
        if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
            cat <<'EOF' >> /etc/pacman.conf
[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
        fi
        log_info "Synchronizing package databases..."
        if ! pacman -Sy --noconfirm; then
            die "Failed to sync package databases — check mirrorlist configuration"
        fi
        log_info "Installing Arch Linux keyring..."
        pacman -S --noconfirm --needed archlinux-keyring
    fi

    log_info "Starting basestrap..."
    printf '%s\n' "${pkgs[@]}" >> "${debug_log}"
    clean_pacman_lock /mnt/var/lib/pacman/db.lck
    if ! xtrace_safe basestrap /mnt "${pkgs[@]}" \
        2>&1 | tee -a "${debug_log}" \
        | while IFS= read -r line; do
            log_info "${line}"
        done; then
        recoverable_error "basestrap failed – the installer can update itself and retry"
    fi
    [[ -x /mnt/bin/bash ]] || die "/mnt/bin/bash missing after basestrap"
    [[ -f /mnt/etc/os-release ]] || die "target root invalid after basestrap"

    if ! grep -q '^Architecture' /mnt/etc/pacman.conf 2>/dev/null; then
        sed -i '1s/^/[options]\nArchitecture = auto\n\n/' /mnt/etc/pacman.conf
    fi

    case "${kernel}" in
        linux-cachyos-bore)
            if ! grep -q '^\[cachyos\]' /mnt/etc/pacman.conf 2>/dev/null; then
                mkdir -p /mnt/etc/pacman.d
                cp /etc/pacman.d/cachyos-mirrorlist /mnt/etc/pacman.d/ 2>/dev/null || true
                cat <<'EOF' >> /mnt/etc/pacman.conf
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
            fi
            ;;
        linux-bazzite-bin)
            if ! grep -q '^\[extra\]' /mnt/etc/pacman.conf 2>/dev/null; then
                mkdir -p /mnt/etc/pacman.d
                cp /etc/pacman.d/mirrorlist-arch /mnt/etc/pacman.d/ 2>/dev/null || true
                cat <<'EOF' >> /mnt/etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
            fi
            ;;
        xanmod)
            if ! grep -q '^\[chaotic-aur\]' /mnt/etc/pacman.conf 2>/dev/null; then
                mkdir -p /mnt/etc/pacman.d
                cp /etc/pacman.d/chaotic-mirrorlist /mnt/etc/pacman.d/ 2>/dev/null || true
                cat <<'EOF' >> /mnt/etc/pacman.conf
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
            fi
            ;;
    esac

    log_info "Configuring locale..."
    artix-chroot /mnt /bin/bash -c "
        grep -q '^${locale} UTF-8' /etc/locale.gen || echo '${locale} UTF-8' >> /etc/locale.gen
        locale-gen
        cat > /etc/locale.conf <<EOF
LANG=${locale}
EOF
    "

    log_info "Configuring keymap..."
    cat <<EOF > /mnt/etc/vconsole.conf
KEYMAP=${keymap}
EOF

    log_info "Configuring timezone..."
    artix-chroot /mnt ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
    artix-chroot /mnt hwclock --systohc

    if [[ "${fs_type}" == 'zfs' ]]; then
        local INST_UUID
        INST_UUID="$(state_get ZFS_UUID)"
        [[ -n "${INST_UUID}" ]] || die "ZFS UUID not found in state"

        log_info "Generating hostid for ZFS..."
        artix-chroot /mnt zgenhostid

        log_info "Adding ZFS hook to mkinitcpio..."
        artix-chroot /mnt sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)/' /etc/mkinitcpio.conf

        log_info "Generating ZFS fstab entries..."
        cat > /mnt/etc/fstab <<EOF
bpool_${INST_UUID}/BOOT/default /boot zfs rw,xattr,posixacl 0 0
EOF
        local efi_part
        efi_part=$(get_partition_name "$(state_get DISK)" 1)
        echo "UUID=$(blkid -s UUID -o value "${efi_part}") /boot/efi vfat umask=0022,fmask=0022,dmask=0022 0 1" >> /mnt/etc/fstab

        log_info "Adding archzfs repository to target..."
        if ! grep -q '^\[archzfs\]' /mnt/etc/pacman.conf 2>/dev/null; then
            cat >> /mnt/etc/pacman.conf <<'EOF'
[archzfs]
Server = https://archzfs.com/$repo/$arch
Server = https://mirror.sum7.eu/archlinux/archzfs/$repo/$arch
Server = https://mirror.biocrafting.net/archlinux/archzfs/$repo/$arch
Server = https://mirror.in.themindsmaze.com/archzfs/$repo/$arch
EOF
        fi

        log_info "Creating zfs-mount init script..."
        cat > /mnt/etc/init.d/zfs-mount <<'ZFSMOUNT'
#!/usr/bin/openrc-run

start() {
    /usr/bin/zfs mount -a
}
ZFSMOUNT
        chmod +x /mnt/etc/init.d/zfs-mount
        enable_service_boot zfs-mount

        log_info "Generating ZFS pool cache..."
        artix-chroot /mnt zpool set cachefile=/etc/zfs/zpool.cache "bpool_${INST_UUID}"
        artix-chroot /mnt zpool set cachefile=/etc/zfs/zpool.cache "rpool_${INST_UUID}"

        echo 'export ZPOOL_VDEV_NAME_PATH=YES' >> /mnt/etc/profile
    fi

    if [[ "${fs_type}" == 'bcachefs' ]]; then
        log_info "Adding Bcachefs hook to mkinitcpio..."
        artix-chroot /mnt sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block keyboard bcachefs filesystems)/' /etc/mkinitcpio.conf
    fi

    if [[ "$(state_get USE_LVM no)" == "yes" ]]; then
        log_info "Adding LVM hook to mkinitcpio..."
        artix-chroot /mnt sed -i '/^HOOKS=/s/\(block\)/\1 lvm2/' /etc/mkinitcpio.conf
        log_info "Enabling LVM boot service..."
        enable_service_boot lvm
    fi

    if [[ "$(state_get USE_LUKS no)" == "yes" ]]; then
        log_info "Adding encrypt hook to mkinitcpio..."
        artix-chroot /mnt sed -i '/^HOOKS=/s/\(block\)/\1 encrypt/' /etc/mkinitcpio.conf
        log_info "Enabling LUKS boot services..."
        enable_service_boot dmcrypt
        enable_service_boot device-mapper
    fi

    if ! grep -q 'virtio_blk' /mnt/etc/mkinitcpio.conf 2>/dev/null; then
        log_info "Adding virtio_blk to initramfs MODULES..."
        artix-chroot /mnt sed -i 's/^MODULES=(/MODULES=(virtio_blk /' /etc/mkinitcpio.conf
    fi

    if [[ "${kernel}" == 'tkg' ]]; then
        log_info "Building TKG kernel (using TKG patches, AF's poweruser process)..."

        local tkg_dir="/tmp/linux-tkg"
        local kernel_src="/tmp/linux-custom"
        rm -rf "${tkg_dir}" "${kernel_src}"

        git clone --depth 1 https://github.com/Frogging-Family/linux-tkg.git "${tkg_dir}"

        local artix_kver=$(pacman -Si linux 2>/dev/null | grep Version | awk '{print $3}' | cut -d- -f1)
        [[ -z "${artix_kver}" ]] && artix_kver=$(uname -r | cut -d- -f1)

        git clone --depth 1 --branch "v${artix_kver}" \
            https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "${kernel_src}" 2>/dev/null || \
        git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "${kernel_src}"

        cd "${kernel_src}"

        local kver=$(make kernelversion | cut -d. -f1-2)
        local patch_dir="${tkg_dir}/linux-tkg-patches/${kver}"
        if [[ -d "${patch_dir}" ]]; then
            log_info "Applying TKG patches for kernel ${kver}..."
            for patch in "${patch_dir}"/*.patch; do
                patch -Np1 < "$patch" || log_warn "Patch ${patch} failed – continuing"
            done
        fi

        make defconfig
        make -j$(nproc)
        make modules_install
        make install

        local kver_full=$(ls /lib/modules/ | grep -E '^[0-9]' | tail -1)
        if [[ -n "${kver_full}" ]]; then
            cp -a /lib/modules/"${kver_full}" /mnt/lib/modules/
            cp /boot/vmlinuz-* /mnt/boot/ 2>/dev/null || true
            cp /boot/initramfs-*.img /mnt/boot/ 2>/dev/null || true
            cp /boot/System.map-* /mnt/boot/ 2>/dev/null || true
            cp /boot/config-* /mnt/boot/ 2>/dev/null || true
            artix-chroot /mnt mkinitcpio -P
            if [[ -d /mnt/boot/grub ]]; then
                artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            fi
            log_info "TKG kernel (${kver_full}) installed"
        else
            die "TKG build failed – no kernel modules found"
        fi

        rm -rf "${tkg_dir}" "${kernel_src}"
        log_info "TKG build complete."
    fi

    if [[ "${fs_type}" != 'zfs' ]]; then
        log_info "Generating fstab..."
        fstabgen -U /mnt > /mnt/etc/fstab
    fi

    if [[ -d /mnt/repo ]]; then
        log_info "Offline mode: copying local repository to target..."
        mkdir -p /mnt/mnt/repo
        cp -a /mnt/repo/. /mnt/mnt/repo/ 2>/dev/null || true
        if ! grep -q '\[custom\]' /mnt/etc/pacman.conf 2>/dev/null; then
            cat >> /mnt/etc/pacman.conf <<'EOF'

[custom]
SigLevel = Optional
Server = file:///mnt/repo/
EOF
        fi
        log_info "Target system configured for offline package access"
    fi

    log_info "Base system installation complete."
}