#!/usr/bin/env bash
set -Eeuo pipefail

MIG_ROOT=""
if [[ -d /run/artix/sfs/rootfs ]]; then
    if ! mountpoint -q /mnt; then
        tui_msg "Live ISO Detected" "Init migration from live ISO requires the target system mounted at /mnt."
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

_pacman() {
    if [[ -n "${MIG_ROOT}" ]]; then
        artix-chroot "${MIG_ROOT}" pacman "$@"
    else
        pacman "$@"
    fi
}

HUB_INIT="openrc"

declare -A OPENRC_TO_DINIT=(
    ["NetworkManager"]="NetworkManager"
    ["networkmanager"]="NetworkManager"
    ["dhcpcd"]="dhcpcd"
    ["iwd"]="iwd"
    ["sshd"]="sshd"
    ["cronie"]="cronie"
    ["dbus"]="dbus"
    ["elogind"]="elogind"
    ["seatd"]="seatd"
    ["acpid"]="acpid"
    ["alsa"]="alsa"
    ["bluetoothd"]="bluetoothd"
    ["connmand"]="connmand"
    ["ufw"]="ufw"
    ["firewalld"]="firewalld"
    ["ntpd"]="ntpd"
    ["syslog-ng"]="syslog-ng"
    ["lvm2-lvmetad"]="lvm2"
    ["dmcrypt"]="dmcrypt"
    ["zfs-zed"]="zfs-zed"
)

declare -A OPENRC_TO_RUNIT=(
    ["NetworkManager"]="NetworkManager"
    ["networkmanager"]="NetworkManager"
    ["dhcpcd"]="dhcpcd"
    ["iwd"]="iwd"
    ["sshd"]="sshd"
    ["cronie"]="cronie"
    ["dbus"]="dbus"
    ["elogind"]="elogind"
    ["seatd"]="seatd"
    ["acpid"]="acpid"
    ["alsa"]="alsa"
    ["bluetoothd"]="bluetoothd"
    ["connmand"]="connmand"
    ["ufw"]="ufw"
    ["firewalld"]="firewalld"
    ["ntpd"]="ntpd"
    ["syslog-ng"]="syslog-ng"
)

declare -A OPENRC_TO_S6=(
    ["NetworkManager"]="NetworkManager"
    ["networkmanager"]="NetworkManager"
    ["dhcpcd"]="dhcpcd"
    ["iwd"]="iwd"
    ["sshd"]="sshd"
    ["cronie"]="cronie"
    ["dbus"]="dbus"
    ["elogind"]="elogind"
    ["seatd"]="seatd"
    ["acpid"]="acpid"
    ["alsa"]="alsa"
    ["bluetoothd"]="bluetoothd"
    ["connmand"]="connmand"
    ["ufw"]="ufw"
    ["firewalld"]="firewalld"
    ["ntpd"]="ntpd"
    ["syslog-ng"]="syslog-ng"
)

declare -A SYSTEMD_TO_OPENRC=(
    ["NetworkManager.service"]="NetworkManager"
    ["networkmanager.service"]="NetworkManager"
    ["dhcpcd.service"]="dhcpcd"
    ["iwd.service"]="iwd"
    ["sshd.service"]="sshd"
    ["cronie.service"]="cronie"
    ["dbus.service"]="dbus"
    ["elogind.service"]="elogind"
    ["seatd.service"]="seatd"
    ["acpid.service"]="acpid"
    ["alsa-restore.service"]="alsa"
    ["bluetooth.service"]="bluetoothd"
    ["connman.service"]="connmand"
    ["ufw.service"]="ufw"
    ["firewalld.service"]="firewalld"
    ["ntpd.service"]="ntpd"
    ["syslog-ng.service"]="syslog-ng"
)

declare -A DINIT_TO_OPENRC=()
for key in "${!OPENRC_TO_DINIT[@]}"; do
    DINIT_TO_OPENRC["${OPENRC_TO_DINIT[$key]}"]="$key"
done

declare -A RUNIT_TO_OPENRC=()
for key in "${!OPENRC_TO_RUNIT[@]}"; do
    RUNIT_TO_OPENRC["${OPENRC_TO_RUNIT[$key]}"]="$key"
done

declare -A S6_TO_OPENRC=()
for key in "${!OPENRC_TO_S6[@]}"; do
    S6_TO_OPENRC["${OPENRC_TO_S6[$key]}"]="$key"
done

get_migration_table() {
    local src="${1}" tgt="${2}"
    local table_name="${src^^}_TO_${tgt^^}"
    declare -p "$table_name" &>/dev/null && echo "$table_name" || echo ""
}

list_enabled_services() {
    local init="${1:-openrc}"
    if [[ -n "${MIG_ROOT}" ]]; then
        case "$init" in
            openrc) 
                if ! artix-chroot "${MIG_ROOT}" command -v rc-update &>/dev/null; then
                    echo ""
                    return 0
                fi
                artix-chroot "${MIG_ROOT}" rc-update show -v 2>/dev/null | awk '/default|boot|nonetwork/ {print $1}' | sort -u
                ;;
            runit)  [[ -d "${MIG_ROOT}/etc/runit/runsvdir/default" ]] && ls "${MIG_ROOT}/etc/runit/runsvdir/default/" 2>/dev/null || echo "" ;;
            dinit)  [[ -d "${MIG_ROOT}/etc/dinit.d/boot.d" ]] && ls "${MIG_ROOT}/etc/dinit.d/boot.d/" 2>/dev/null | sed 's/\.d$//' || echo "" ;;
            s6)     artix-chroot "${MIG_ROOT}" s6-rc-db list services 2>/dev/null || echo "" ;;
            systemd) artix-chroot "${MIG_ROOT}" systemctl list-unit-files --state=enabled 2>/dev/null | awk '/\.service/ {print $1}' || echo "" ;;
            *)      echo "" ;;
        esac
    else
        case "$init" in
            openrc)
                if ! command -v rc-update &>/dev/null; then
                    echo ""
                    return 0
                fi
                rc-update show -v 2>/dev/null | awk '/default|boot|nonetwork/ {print $1}' | sort -u
                ;;
            runit)  [[ -d /etc/runit/runsvdir/default ]] && ls /etc/runit/runsvdir/default/ 2>/dev/null || echo "" ;;
            dinit)  [[ -d /etc/dinit.d/boot.d ]] && ls /etc/dinit.d/boot.d/ 2>/dev/null | sed 's/\.d$//' || echo "" ;;
            s6)     s6-rc-db list services 2>/dev/null || echo "" ;;
            systemd) systemctl list-unit-files --state=enabled 2>/dev/null | awk '/\.service/ {print $1}' || echo "" ;;
            *)      echo "" ;;
        esac
    fi
}

map_service() {
    local src="${1}" tgt="${2}" svc="${3}"
    local table_name
    table_name=$(get_migration_table "$src" "$tgt")
    if [[ -n "$table_name" ]]; then
        local mapped
        mapped=$(eval "echo \${$table_name[$svc]:-}")
        [[ -n "$mapped" ]] && echo "$mapped" && return 0
    fi
    return 1
}

list_init_packages() {
    local init_suffix="${1}"
    _pacman -Qsq "${init_suffix}" 2>/dev/null || true
}

cache_target_init_packages() {
    local source_init="${1}" target_init="${2}"
    log_info "Downloading target init packages before removing ${source_init}..."
    local init_pkgs
    init_pkgs=$(list_init_packages "${source_init}")
    if [[ -z "${init_pkgs}" ]]; then
        log_warn "No ${source_init} packages found — skipping download"
        return 0
    fi

    local target_pkgs=""
    while IFS= read -r pkg; do
        local new_pkg="${pkg/${source_init}/${target_init}}"
        target_pkgs+=" ${new_pkg}"
    done <<< "$init_pkgs"
    target_pkgs="${target_pkgs# }"

    if [[ -n "$target_pkgs" ]]; then
        log_info "Caching: ${target_pkgs}"
        _pacman -Sw --noconfirm ${target_pkgs} 2>/dev/null || log_warn "Some packages could not be downloaded"
    fi
}

remove_source_init() {
    local src="${1}"
    case "$src" in
        systemd)
            log_info "Removing systemd and related packages..."
            _pacman -Rdd --noconfirm systemd systemd-libs systemd-sysvcompat pacman-mirrorlist dbus 2>/dev/null || true
            rm -fv "${MIG_ROOT}/etc/resolv.conf" 2>/dev/null || true
            cp -vf "${MIG_ROOT}/etc/pacman.d/mirrorlist.artix" "${MIG_ROOT}/etc/pacman.d/mirrorlist" 2>/dev/null || true
            ;;
        *)
            local init_pkgs
            init_pkgs=$(list_init_packages "${src}")
            if [[ -n "${init_pkgs}" ]]; then
                log_info "Removing ${src} packages: ${init_pkgs}"
                _pacman -Rdd --noconfirm ${init_pkgs} 2>/dev/null || log_warn "Some packages could not be removed"
            else
                log_warn "No ${src} packages found to remove"
            fi
            ;;
    esac
}

install_target_init() {
    local source_init="${1}" target_init="${2}"
    local init_pkgs
    init_pkgs=$(list_init_packages "${source_init}" 2>/dev/null || true)

    if [[ -n "${init_pkgs}" ]]; then
        local target_pkgs=""
        while IFS= read -r pkg; do
            local new_pkg="${pkg/${source_init}/${target_init}}"
            target_pkgs+=" ${new_pkg}"
        done <<< "$init_pkgs"
        target_pkgs="${target_pkgs# }"

        if [[ -n "$target_pkgs" ]]; then
            log_info "Installing target init packages: ${target_pkgs}"
            _pacman -S --noconfirm ${target_pkgs} 2>/dev/null || {
                log_warn "Batch install failed — falling back to hardcoded package list"
                _install_target_init_fallback "${target_init}"
            }
        else
            _install_target_init_fallback "${target_init}"
        fi
    else
        log_warn "No ${source_init} packages to migrate — using hardcoded list"
        _install_target_init_fallback "${target_init}"
    fi
}

_install_target_init_fallback() {
    local init="${1}"
    local pkgs=()
    case "$init" in
        openrc) pkgs=(openrc elogind-openrc) ;;
        runit)  pkgs=(runit elogind-runit) ;;
        dinit)  pkgs=(dinit dinit-base dinit-rc elogind-dinit) ;;
        s6)     pkgs=(s6 s6-rc elogind-s6) ;;
        *) die "Unknown init system: $init" ;;
    esac
    log_info "Installing target init packages (fallback): ${pkgs[*]}"
    
    if [[ "$init" == "openrc" ]]; then
        _pacman -Rdd --noconfirm cryptsetup-scripts 2>/dev/null || true
    fi
    
    _pacman -S --noconfirm --needed "${pkgs[@]}" || die "Failed to install ${init}"
}

backup_init_config() {
    local init="${1}" backup_dir="${2}"
    mkdir -p "$backup_dir"
    case "$init" in
        openrc) cp -a "${MIG_ROOT}/etc/runlevels" "$backup_dir/" 2>/dev/null || true ;;
        runit)  cp -a "${MIG_ROOT}/etc/runit/runsvdir" "$backup_dir/" 2>/dev/null || true ;;
        dinit)  cp -a "${MIG_ROOT}/etc/dinit.d" "$backup_dir/" 2>/dev/null || true ;;
        s6)     cp -a "${MIG_ROOT}/etc/s6" "$backup_dir/" 2>/dev/null || true ;;
        systemd) cp -a "${MIG_ROOT}/etc/systemd" "$backup_dir/" 2>/dev/null || true ;;
    esac
    log_info "Init configuration backed up to $backup_dir"
}

detect_custom_services() {
    local init="${1}"
    local -a custom=()
    local -a known_services=(NetworkManager networkmanager dhcpcd iwd sshd cronie dbus elogind logind seatd acpid alsa bluetoothd connmand firewalld ntpd syslog-ng lvm2 dmcrypt zfs-zed lightdm agetty bootmisc binfmt esysusers etmpfiles fsck hostname hwclock keymaps localmount loopback modules mtab netmount procfs root save-keymaps save-termencoding seedrng swap sysctl termencoding)
    local svc
    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        # Skip known services that might be misdetected
        for known in "${known_services[@]}"; do
            [[ "$svc" == "$known" ]] && continue 2
        done
        local owned=0
        case "$init" in
            openrc) _pacman -Qo "${MIG_ROOT}/etc/init.d/$svc" &>/dev/null && owned=1 ;;
            runit)  _pacman -Qo "${MIG_ROOT}/etc/runit/sv/$svc" &>/dev/null && owned=1 ;;
            dinit)  _pacman -Qo "${MIG_ROOT}/etc/dinit.d/$svc" &>/dev/null && owned=1 ;;
            s6)     _pacman -Qo "${MIG_ROOT}/etc/s6/sv/$svc" &>/dev/null && owned=1 ;;
        esac
        [[ $owned -eq 0 ]] && custom+=("$svc")
    done < <(list_enabled_services "$init")
    printf '%s\n' "${custom[@]}"
}

validate_migration() {
    local src="${1}" tgt="${2}"
    [[ "$src" != "$tgt" ]] || die "Source and target init are the same: $src"
    command -v pacman &>/dev/null || die "This migration requires pacman"
}

has_direct_table() {
    local src="${1}" tgt="${2}"
    local table_name="${src^^}_TO_${tgt^^}"
    declare -p "$table_name" &>/dev/null && return 0 || return 1
}

_enable_service() {
    local svc="$1" init="${2:-${INIT:-openrc}}"
    if [[ -n "${MIG_ROOT}" ]]; then
        artix-chroot "${MIG_ROOT}" bash -c "
            source /usr/local/lib/artix-installer/services.sh 2>/dev/null || \
            source /root/ArtixForge/scripts/install/services.sh
            export INIT='${init}'
            enable_service '${svc}'
        " 2>/dev/null || log_warn "Could not enable $svc service"
    else
        export INIT="${init}"
        enable_service "$svc" 2>/dev/null || log_warn "Could not enable $svc service"
    fi
}

_run_single_migration() {
    local source_init="${1}" target_init="${2}"
    log_info "Migrating services from $source_init to $target_init..."
    local enabled_svcs
    enabled_svcs=$(list_enabled_services "$source_init")
    local migrated=0 skipped=0
    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        local mapped
        mapped=$(map_service "$source_init" "$target_init" "$svc" 2>/dev/null || true)
        if [[ -n "$mapped" ]]; then
            log_info "  Migrating: $svc → $mapped"
            _enable_service "$mapped" "$target_init"
            migrated=$((migrated + 1))
        else
            log_warn "  No mapping for $svc – skipping"
            skipped=$((skipped + 1))
        fi
    done <<< "$enabled_svcs"
    log_info "Step complete: $migrated services migrated, $skipped skipped"
}

prepare_artix_repos() {
    log_info "Replacing pacman.conf and mirrorlist with Artix versions..."
    mv -vf "${MIG_ROOT}/etc/pacman.conf" "${MIG_ROOT}/etc/pacman.conf.arch" 2>/dev/null || true
    curl -sL https://gitea.artixlinux.org/packages/pacman/raw/branch/master/pacman.conf -o "${MIG_ROOT}/etc/pacman.conf"
    mv -vf "${MIG_ROOT}/etc/pacman.d/mirrorlist" "${MIG_ROOT}/etc/pacman.d/mirrorlist-arch" 2>/dev/null || true
    curl -sL https://gitea.artixlinux.org/packages/artix-mirrorlist/raw/branch/master/mirrorlist -o "${MIG_ROOT}/etc/pacman.d/mirrorlist"
    cp -vf "${MIG_ROOT}/etc/pacman.d/mirrorlist" "${MIG_ROOT}/etc/pacman.d/mirrorlist.artix" 2>/dev/null || true

    if [[ "$(state_get ENABLE_ARCH_REPOS no)" == "yes" ]]; then
        log_info "Enabling Arch repositories in pacman.conf..."
        if ! grep -q '^\[extra\]' "${MIG_ROOT}/etc/pacman.conf" 2>/dev/null; then
            cat >> "${MIG_ROOT}/etc/pacman.conf" <<'EOF'
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
        fi
    fi
}

clean_pacman_cache() {
    log_info "Cleaning all pacman caches and forcing sync..."
    _pacman -Scc --noconfirm 2>/dev/null || true
    _pacman -Syy --noconfirm
}

install_artix_keyring() {
    log_info "Temporarily lowering pacman security level..."
    sed -i 's/^SigLevel.*/SigLevel = Never/' "${MIG_ROOT}/etc/pacman.conf"

    log_info "Installing Artix PGP keyring..."
    _pacman -S --noconfirm artix-keyring
    _chroot pacman-key --populate artix
    _chroot pacman-key --lsign-key 95AEC5D0C1E294FC9F82B253573A673A53C01BC2

    log_info "Restoring pacman security level..."
    sed -i 's/^SigLevel = Never/SigLevel = Required DatabaseOptional/' "${MIG_ROOT}/etc/pacman.conf"
}

cache_artix_packages() {
    local init="${1:-openrc}"
    log_info "Downloading base Artix packages into cache..."
    local pkgs=(base base-devel grub linux linux-headers mkinitcpio
                 rsync lsb-release esysusers etmpfiles artix-branding-base)
    case "$init" in
        openrc) pkgs+=(openrc elogind-openrc openrc-system) ;;
        runit)  pkgs+=(runit elogind-runit runit-system) ;;
        dinit)  pkgs+=(dinit elogind-dinit dinit-system) ;;
        s6)     pkgs+=(s6-base elogind-s6 s6-system) ;;
    esac
    _pacman -Sw --noconfirm "${pkgs[@]}" 2>/dev/null || log_warn "Some packages could not be downloaded"
}

remove_systemd() {
    log_info "Removing systemd and related packages..."
    _pacman -Rdd --noconfirm systemd systemd-libs systemd-sysvcompat pacman-mirrorlist dbus 2>/dev/null || true
    rm -fv "${MIG_ROOT}/etc/resolv.conf" 2>/dev/null || true
    cp -vf "${MIG_ROOT}/etc/pacman.d/mirrorlist.artix" "${MIG_ROOT}/etc/pacman.d/mirrorlist" 2>/dev/null || true
}

reinstall_artix_packages() {
    log_info "Reinstalling all packages from Artix repositories..."
    export LC_ALL=C
    _pacman -Sl system | grep installed | cut -d" " -f2 | _pacman -S --noconfirm -
    _pacman -Sl world  | grep installed | cut -d" " -f2 | _pacman -S --noconfirm -
    _pacman -Sl galaxy | grep installed | cut -d" " -f2 | _pacman -S --noconfirm -
    if [[ "$(state_get ENABLE_ARCH_REPOS no)" == "yes" ]]; then
        _pacman -Sl lib32 | grep installed | cut -d" " -f2 | _pacman -S --noconfirm - 2>/dev/null || true
    fi
}

enable_lvm_services() {
    if [[ -f "${MIG_ROOT}/etc/lvm/lvm.conf" ]] || _pacman -Q lvm2 &>/dev/null; then
        log_info "Enabling LVM services..."
        local init
        init=$(detect_init 2>/dev/null || state_get INIT openrc)
        case "$init" in
            openrc)
                _enable_service lvm boot "$init"
                _enable_service device-mapper boot "$init"
                ;;
            runit)
                _enable_service lvm2 "$init"
                _enable_service device-mapper "$init"
                ;;
            dinit)
                _enable_service lvm2 "$init"
                _enable_service dmeventd "$init"
                ;;
            s6)
                ;;
        esac
    fi
}

cleanup_systemd_junk() {
    log_info "Removing systemd junk accounts and directories..."
    for user in journal journal-gateway timesync network bus-proxy journal-remote journal-upload resolve coredump; do
        _chroot userdel "systemd-$user" 2>/dev/null || true
    done
    rm -vfr "${MIG_ROOT}/"{etc,var/lib}/systemd 2>/dev/null || true
}

update_bootloader() {
    log_info "Recreating initramfs and updating bootloader..."
    if [[ -x "${MIG_ROOT}/usr/bin/mkinitcpio" ]]; then
        _chroot mkinitcpio -P 2>/dev/null || log_warn "mkinitcpio failed"
    fi
    if _chroot command -v grub-mkconfig &>/dev/null; then
        _chroot grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || log_warn "grub-mkconfig failed"
    elif _chroot command -v update-grub &>/dev/null; then
        _chroot update-grub 2>/dev/null || log_warn "update-grub failed"
    fi
    if [[ -d "${MIG_ROOT}/boot/efi" ]]; then
        log_info "Reinstalling GRUB for UEFI..."
        _chroot grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB 2>/dev/null || log_warn "grub-install failed"
    else
        log_info "Reinstalling GRUB for BIOS..."
        local disk
        disk="$(lsblk -no PKNAME "$(findmnt -no SOURCE "${MIG_ROOT}/" 2>/dev/null)" 2>/dev/null | head -n1)"
        if [[ -n "$disk" ]]; then
            _chroot grub-install "/dev/$disk" 2>/dev/null || log_warn "grub-install failed"
        fi
    fi
}

cold_reboot() {
    log_info "Init has been swapped — performing cold reboot via SysRq..."
    sync
    mount "${MIG_ROOT}/" -o remount,ro 2>/dev/null || true
    echo s >| /proc/sysrq-trigger 2>/dev/null || true
    echo u >| /proc/sysrq-trigger 2>/dev/null || true
    echo b >| /proc/sysrq-trigger 2>/dev/null || true
    reboot
}

run_init_migration() {
    local source_init="${1}" target_init="${2}"
    validate_migration "$source_init" "$target_init"

    if [[ "$source_init" == "systemd" ]]; then
        if [[ -n "${MIG_ROOT}" ]]; then
            die "Systemd→Artix migration must be run from the installed system, not the live ISO."
        fi
        log_info "Starting migration from Arch/systemd to Artix/${target_init}..."
        if ! tui_yesno "Full Migration" "This will replace your entire system with Artix.\n\nProceed?"; then
            log_info "Migration cancelled."
            return 0
        fi

        prepare_artix_repos
        clean_pacman_cache
        install_artix_keyring
        cache_artix_packages "$target_init"
        remove_systemd
        install_target_init "$source_init" "$target_init"
        log_info "Installing base Artix packages..."
        _pacman -S --noconfirm base base-devel grub linux linux-headers mkinitcpio \
            rsync lsb-release esysusers etmpfiles artix-branding-base
        reinstall_artix_packages
    else
        local backup_dir="${MIG_ROOT}/root/init-backup-${source_init}-$(date +%Y%m%d-%H%M%S)"
        backup_init_config "$source_init" "$backup_dir"

        local -a custom_services
        mapfile -t custom_services < <(detect_custom_services "$source_init")
        if [[ ${#custom_services[@]} -gt 0 ]]; then
            log_warn "Custom services detected: ${custom_services[*]}"
            mkdir -p "$backup_dir/custom"
            for svc in "${custom_services[@]}"; do
                case "$source_init" in
                    openrc) cp -a "${MIG_ROOT}/etc/init.d/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                    runit)  cp -a "${MIG_ROOT}/etc/runit/sv/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                    dinit)  cp -a "${MIG_ROOT}/etc/dinit.d/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                    s6)     cp -a "${MIG_ROOT}/etc/s6/sv/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                esac
            done
            log_info "Custom services saved to $backup_dir/custom/"
        fi

        cache_target_init_packages "$source_init" "$target_init"

        local enabled_svcs
        enabled_svcs=$(list_enabled_services "$source_init")
        local svc_pkgs=""
        while IFS= read -r svc; do
            [[ -z "$svc" ]] && continue
            local mapped
            mapped=$(map_service "$source_init" "$target_init" "$svc" 2>/dev/null || true)
            if [[ -n "$mapped" ]]; then
                svc_pkgs+=" ${mapped}-${target_init}"
            fi
        done <<< "$enabled_svcs"
        if [[ -n "$svc_pkgs" ]]; then
            log_info "Installing service packages: ${svc_pkgs}"
            _pacman -S --noconfirm --needed ${svc_pkgs} 2>/dev/null || log_warn "Some service packages could not be installed"
        fi

        remove_source_init "$source_init"
        install_target_init "$source_init" "$target_init"
    fi

    if has_direct_table "$source_init" "$target_init"; then
        log_info "Direct migration: $source_init → $target_init"
        _run_single_migration "$source_init" "$target_init"
    elif [[ "$source_init" != "$HUB_INIT" && "$target_init" != "$HUB_INIT" ]]; then
        log_info "Chaining through $HUB_INIT"
        _run_single_migration "$source_init" "$HUB_INIT"
        _run_single_migration "$HUB_INIT" "$target_init"
    elif [[ "$source_init" != "$HUB_INIT" && "$target_init" == "$HUB_INIT" ]]; then
        _run_single_migration "$source_init" "$HUB_INIT"
    elif [[ "$source_init" == "$HUB_INIT" && "$target_init" != "$HUB_INIT" ]]; then
        _run_single_migration "$HUB_INIT" "$target_init"
    fi

    enable_lvm_services
    [[ "$source_init" == "systemd" ]] && cleanup_systemd_junk
    update_bootloader

    log_info "Init migration complete."

    if [[ "$source_init" != "systemd" ]]; then
        if tui_yesno "Reboot" "A cold reboot is required. Proceed?"; then
            cold_reboot
        else
            log_warn "You must cold reboot manually to complete the migration."
            log_warn "Run: sync && echo b > /proc/sysrq-trigger"
        fi
    else
        if tui_yesno "Reboot" "Reboot now?"; then
            reboot
        fi
    fi
}

tui_init_migration_menu() {
    detect_init >/dev/null 2>&1 || true
    local current_init
    current_init=$(state_get INIT openrc)
    tui_msg_quick "Current Init" "Detected init system: ${current_init}"

    local source_init target_init
    source_init=$(tui_menu "Source Init" "Select current init system:" \
        "openrc" "runit" "dinit" "s6" "systemd") || return 1
    target_init=$(tui_menu "Target Init" "Select new init system:" \
        "openrc" "runit" "dinit" "s6") || return 1
    [[ "$source_init" != "$target_init" ]] || die "Source and target are the same."

    local script="${MIGRATIONS_DIR}/inits/${source_init}-to-${target_init}.sh"
    if [[ -f "$script" ]]; then
        source "$script"
    else
        log_info "No direct script for $source_init → $target_init – chaining through $HUB_INIT"
        local step1="${MIGRATIONS_DIR}/inits/${source_init}-to-${HUB_INIT}.sh"
        local step2="${MIGRATIONS_DIR}/inits/${HUB_INIT}-to-${target_init}.sh"
        [[ -f "$step1" ]] && { log_info "Running: $source_init → $HUB_INIT"; source "$step1"; }
        [[ -f "$step2" ]] && { log_info "Running: $HUB_INIT → $target_init"; source "$step2"; }
    fi
    log_info "Init migration complete. Please reboot."
}