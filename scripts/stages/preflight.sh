#!/usr/bin/env bash
set -Eeuo pipefail;

_preflight_rank_mirrors() {
    local mirrorlist="/etc/pacman.d/mirrorlist"
    local backup="${mirrorlist}.orig"

    if ! tui_yesno "Mirror Ranking" "Rank mirrors for faster downloads?"; then
        log_info "Skipping mirror ranking."
        return 0
    fi

    log_info "Ranking mirrors..."
    pacman -S --noconfirm --needed pacman-contrib || die "Failed to install pacman-contrib"

    local ranked="/tmp/mirrorlist.ranked"
    if rankmirrors -n 6 "${backup}" > "${ranked}" 2>/dev/null; then
        if [[ -s "${ranked}" ]]; then
            cp "${ranked}" "${mirrorlist}"
            log_info "Mirror ranking completed."
        else
            log_warn "rankmirrors produced empty output – keeping original mirrorlist."
        fi
    else
        log_warn "rankmirrors failed – keeping original mirrorlist."
    fi
    rm -f "${ranked}"

    pacman -Sy --noconfirm || log_warn "Failed to refresh package database after ranking."
}

stage_preflight() {
    if stage_should_skip preflight; then
        return 0;
    fi;

    require_root;
    require_internet;

    if [[ "${ARTIX_BOOT_MODE:-uefi}" == "uefi" ]]; then
        modprobe fat 2>/dev/null || true
        modprobe vfat 2>/dev/null || true
        if ! grep -q 'vfat' /proc/filesystems 2>/dev/null; then
            log_warn "VFAT kernel module unavailable — attempting to install linux kernel modules..."
            pacman -Sy --noconfirm --needed linux 2>/dev/null || true
            modprobe vfat 2>/dev/null || true
            if ! grep -q 'vfat' /proc/filesystems 2>/dev/null; then
                die "VFAT kernel support is required for EFI partition. Your live ISO's kernel lacks VFAT support. Try a different ISO."
            fi
        fi
    fi

    local original_mirrorlist="/etc/pacman.d/mirrorlist.orig"
    if [[ ! -f "${original_mirrorlist}" ]]; then
        cp /etc/pacman.d/mirrorlist "${original_mirrorlist}" 2>/dev/null || true
    fi

    _preflight_rank_mirrors

    local pacman_conf_backup='/tmp/pacman.conf.artixtui.bak'
    if [[ ! -f "${pacman_conf_backup}" ]]; then
        cp /etc/pacman.conf "${pacman_conf_backup}"
    fi

    local pkgs=();
    local fs_type;
    local target_kernel;
    local live_kernel_pkg="";
    fs_type="$(state_get FS_TYPE ext4)";
    target_kernel="$(state_get KERNEL_CHOICE linux)";

    command_exists sgdisk       || pkgs+=(gptfdisk);
    command_exists partprobe    || pkgs+=(parted);
    command_exists cryptsetup   || pkgs+=(cryptsetup);
    command_exists mount        || pkgs+=(util-linux);
    command_exists mkfs.fat     || pkgs+=(dosfstools);
    command_exists lsblk        || pkgs+=(util-linux);
    command_exists wipefs       || pkgs+=(util-linux);
    command_exists btrfs        || pkgs+=(btrfs-progs);

    [[ "$(state_get USE_LVM no)" == "yes" ]] && { command_exists pvcreate || pkgs+=(lvm2); }

    if [[ "$(state_get POWER_USER no)" == "yes" ]]; then
        for tool in bc flex bison openssl; do
            command -v "${tool}" &>/dev/null || pkgs+=("${tool}")
        done
    fi

    case "$(uname -r)" in
        *lts*)       live_kernel_pkg="linux-lts" ;;
        *zen*)       live_kernel_pkg="linux-zen" ;;
        *hardened*)  live_kernel_pkg="linux-hardened" ;;
        *)           live_kernel_pkg="linux" ;;
    esac

    case "${fs_type}" in
        xfs)      command_exists mkfs.xfs || pkgs+=(xfsprogs) ;;
        f2fs)     command_exists mkfs.f2fs || pkgs+=(f2fs-tools) ;;
        bcachefs)
            if ! command_exists mkfs.bcachefs || ! modprobe bcachefs 2>/dev/null; then
                log_info "Building bcachefs-tools from source..."
                local bcachefs_src='/tmp/bcachefs-tools-src'
                rm -rf "${bcachefs_src}"
                pacman -S --noconfirm --needed base-devel git rust clang liburcu libaio keyutils lz4 zstd libscrypt
                git clone --depth 1 https://evilpiepirate.org/git/bcachefs-tools.git "${bcachefs_src}" || {
                    die "Failed to clone bcachefs-tools source repository"
                }
                make -C "${bcachefs_src}" -j$(nproc) || die "Failed to build bcachefs-tools"
                make -C "${bcachefs_src}" install || die "Failed to install bcachefs-tools"
                rm -rf "${bcachefs_src}"
                if ! command -v mkfs.bcachefs >/dev/null 2>&1; then
                    die "mkfs.bcachefs still unavailable after building"
                fi
                log_info "bcachefs-tools built and installed successfully"
            fi
            modprobe bcachefs 2>/dev/null || {
                log_warn "bcachefs kernel module not available. DKMS may be required."
            }
            ;;
        zfs)
            if [[ "${target_kernel}" != "linux" &&
                  "${target_kernel}" != "linux-lts" &&
                  "${target_kernel}" != "linux-zen" &&
                  "${target_kernel}" != "linux-hardened" ]]; then
                die "ZFS is only supported with linux, linux-lts, linux-zen, or linux-hardened kernels."
            fi

            if ! grep -q '^\[archzfs\]' /etc/pacman.conf; then
                pacman-key --recv-keys F75D9D76 --keyserver hkp://keyserver.ubuntu.com
                pacman-key --lsign-key F75D9D76
                cat <<'EOF' >> /etc/pacman.conf

[archzfs]
Server = https://archzfs.com/$repo/x86_64
EOF
                pacman -Sy --noconfirm
                pacman -Sl archzfs >/dev/null 2>&1 || die "archzfs repository unusable"
            fi

            pkgs+=(archzfs/zfs-dkms archzfs/zfs-utils base-devel)
            ;;
    esac

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        log_info "Installing required tools: ${pkgs[*]}"
        if ! gum spin --spinner dot --title "Preflight – installing dependencies" -- \
            pacman -S --noconfirm --needed "${pkgs[@]}"; then
            log_warn "Package installation failed — restoring original mirrors and retrying."
            if [[ -f "${original_mirrorlist}" ]]; then
                cp "${original_mirrorlist}" /etc/pacman.d/mirrorlist
                pacman -Sy --noconfirm || true
            fi
            if ! gum spin --spinner dot --title "Preflight – retrying" -- \
                pacman -S --noconfirm --needed "${pkgs[@]}"; then
                log_error "Failed to install: ${pkgs[*]}"
                die "Package installation failed. Check network and mirrorlist."
            fi
        fi
        log_info "Preflight dependencies installed.";
        for pkg in "${pkgs[@]}"; do
            local pkg_name="${pkg##*/}"
            pacman -Q "${pkg_name}" &>/dev/null || die "Failed to install ${pkg}"
        done
    fi;

    if [[ "${fs_type}" == 'zfs' ]]; then
        log_info "Kernel: $(uname -r)"
        log_info "Installed ZFS packages:"
        pacman -Q | grep '^zfs' || true
        log_info "Available ZFS modules:"
        find /usr/lib/modules -iname 'zfs.ko*' 2>/dev/null || true
        depmod -a

        if ! modprobe zfs 2>/dev/null; then
            log_error "Failed to load ZFS kernel module."
            log_error "DKMS status:"
            dkms status 2>/dev/null || true
            die "ZFS kernel module not available. DKMS build may have failed or kernel $(uname -r) is unsupported."
        fi
        log_info "ZFS kernel module loaded successfully."
    fi

    if [[ "${fs_type}" == 'bcachefs' ]]; then
        local bcachefs_ver kernel_ver
        if command -v bcachefs >/dev/null; then
            bcachefs_ver=$(bcachefs version 2>/dev/null | grep -oP '\d+\.\d+' | head -1) || true
            if [[ -n "${bcachefs_ver}" ]]; then
                kernel_ver=$(uname -r | cut -d. -f1,2)
                if [[ "$(printf '%s\n' "${bcachefs_ver}" "${kernel_ver}" | sort -V | head -n1)" != "${bcachefs_ver}" ]]; then
                    log_warn "bcachefs-tools version ${bcachefs_ver} may be older than kernel ${kernel_ver}."
                    log_warn "Update the live ISO or bcachefs-tools to avoid superblock errors."
                fi
            fi
        fi
    fi

    if [[ "${ARTIX_BOOT_MODE:-uefi}" == "bios" ]]; then
        local parted_ver
        parted_ver=$(parted --version | head -1 | awk '{print $NF}')
        if [[ "${parted_ver}" > "3.4" ]]; then
            log_warn "parted ${parted_ver} may create partitions GRUB cannot read."
            if tui_yesno "Downgrade parted" "Downgrade parted to 3.4-2 for compatibility?"; then
                pacman -U --noconfirm "https://archive.artixlinux.org/packages/p/parted/parted-3.4-2-x86_64.pkg.tar.zst" || log_warn "Downgrade failed – continuing"
            fi
        fi
    fi

    check_disk_space 3 /mnt
    stage_mark_done preflight;
}