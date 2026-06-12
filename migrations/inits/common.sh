#!/usr/bin/env bash
set -Eeuo pipefail

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
    case "$init" in
        openrc) rc-update show -v 2>/dev/null | awk '/default|boot|nonetwork/ {print $1}' | sort -u ;;
        runit)  [[ -d /etc/runit/runsvdir/default ]] && ls /etc/runit/runsvdir/default/ 2>/dev/null ;;
        dinit)  [[ -d /etc/dinit.d/boot.d ]] && ls /etc/dinit.d/boot.d/ 2>/dev/null | sed 's/\.d$//' ;;
        s6)     s6-rc-db list services 2>/dev/null || true ;;
        systemd) systemctl list-unit-files --state=enabled 2>/dev/null | awk '/\.service/ {print $1}' ;;
        *)      return 1 ;;
    esac
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
    local init_suffix="${1}"  # openrc, runit, dinit, s6, systemd
    pacman -Qsq "${init_suffix}" 2>/dev/null || true
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

    local target_pkgs
    target_pkgs=$(echo "${init_pkgs}" | sed "s/${source_init}/${target_init}/g")
    log_info "Caching: ${target_pkgs}"
    pacman -Sw --noconfirm ${target_pkgs} 2>/dev/null || log_warn "Some packages could not be downloaded"
}

remove_source_init() {
    local src="${1}"
    case "$src" in
        systemd)
            log_info "Removing systemd and related packages..."
            pacman -Rdd --noconfirm systemd systemd-libs systemd-sysvcompat pacman-mirrorlist dbus 2>/dev/null || true
            rm -fv /etc/resolv.conf
            cp -vf /etc/pacman.d/mirrorlist.artix /etc/pacman.d/mirrorlist
            ;;
        *)
            local init_pkgs
            init_pkgs=$(list_init_packages "${src}")
            if [[ -n "${init_pkgs}" ]]; then
                log_info "Removing ${src} packages: ${init_pkgs}"
                pacman -Rdd --noconfirm ${init_pkgs} 2>/dev/null || log_warn "Some packages could not be removed"
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
        local target_pkgs
        target_pkgs=$(echo "${init_pkgs}" | sed "s/${source_init}/${target_init}/g")
        log_info "Installing target init packages: ${target_pkgs}"
        pacman -S --noconfirm ${target_pkgs} 2>/dev/null || {
            log_warn "Batch install failed — falling back to hardcoded package list"
            _install_target_init_fallback "${target_init}"
        }
    else
        log_warn "No ${source_init} packages to migrate — using hardcoded list"
        _install_target_init_fallback "${target_init}"
    fi
}

_install_target_init_fallback() {
    local init="${1}"
    local pkgs=()
    case "$init" in
        openrc) pkgs=(openrc elogind-openrc openrc-system) ;;
        runit)  pkgs=(runit elogind-runit runit-system) ;;
        dinit)  pkgs=(dinit dinit-base dinit-rc elogind-dinit dinit-system) ;;
        s6)     pkgs=(s6 s6-rc elogind-s6 s6-system) ;;
        *) die "Unknown init system: $init" ;;
    esac
    log_info "Installing target init packages (fallback): ${pkgs[*]}"
    pacman -S --noconfirm --needed "${pkgs[@]}" || die "Failed to install ${init}"
}

backup_init_config() {
    local init="${1}" backup_dir="${2}"
    mkdir -p "$backup_dir"
    case "$init" in
        openrc) cp -a /etc/runlevels "$backup_dir/" 2>/dev/null || true ;;
        runit)  cp -a /etc/runit/runsvdir "$backup_dir/" 2>/dev/null || true ;;
        dinit)  cp -a /etc/dinit.d "$backup_dir/" 2>/dev/null || true ;;
        s6)     cp -a /etc/s6 "$backup_dir/" 2>/dev/null || true ;;
        systemd) cp -a /etc/systemd "$backup_dir/" 2>/dev/null || true ;;
    esac
    log_info "Init configuration backed up to $backup_dir"
}

detect_custom_services() {
    local init="${1}"
    local -a custom=()
    local svc
    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        local owned=0
        case "$init" in
            openrc) pacman -Qo "/etc/init.d/$svc" &>/dev/null && owned=1 ;;
            runit)  pacman -Qo "/etc/runit/sv/$svc" &>/dev/null && owned=1 ;;
            dinit)  pacman -Qo "/etc/dinit.d/$svc" &>/dev/null && owned=1 ;;
            s6)     pacman -Qo "/etc/s6/sv/$svc" &>/dev/null && owned=1 ;;
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
            enable_service "$mapped" 2>/dev/null || { log_warn "  Failed to enable $mapped"; ((skipped++)); continue; }
            ((migrated++))
        else
            log_warn "  No mapping for $svc – skipping"
            ((skipped++))
        fi
    done <<< "$enabled_svcs"
    log_info "Step complete: $migrated services migrated, $skipped skipped"
}

prepare_artix_repos() {
    log_info "Replacing pacman.conf and mirrorlist with Artix versions..."
    mv -vf /etc/pacman.conf /etc/pacman.conf.arch
    curl -sL https://gitea.artixlinux.org/packages/pacman/raw/branch/master/pacman.conf -o /etc/pacman.conf
    mv -vf /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-arch
    curl -sL https://gitea.artixlinux.org/packages/artix-mirrorlist/raw/branch/master/mirrorlist -o /etc/pacman.d/mirrorlist
    cp -vf /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.artix

    if [[ "$(state_get ENABLE_ARCH_REPOS no)" == "yes" ]]; then
        log_info "Enabling Arch repositories in pacman.conf..."
        if ! grep -q '^\[extra\]' /etc/pacman.conf; then
            cat >> /etc/pacman.conf <<'EOF'
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
    pacman -Scc --noconfirm 2>/dev/null || true
    pacman -Syy --noconfirm
}

install_artix_keyring() {
    log_info "Temporarily lowering pacman security level..."
    sed -i 's/^SigLevel.*/SigLevel = Never/' /etc/pacman.conf

    log_info "Installing Artix PGP keyring..."
    pacman -S --noconfirm artix-keyring
    pacman-key --populate artix
    pacman-key --lsign-key 95AEC5D0C1E294FC9F82B253573A673A53C01BC2

    log_info "Restoring pacman security level..."
    sed -i 's/^SigLevel = Never/SigLevel = Required DatabaseOptional/' /etc/pacman.conf
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
    pacman -Sw --noconfirm "${pkgs[@]}" 2>/dev/null || log_warn "Some packages could not be downloaded"
}

remove_systemd() {
    log_info "Removing systemd and related packages..."
    pacman -Rdd --noconfirm systemd systemd-libs systemd-sysvcompat pacman-mirrorlist dbus 2>/dev/null || true
    rm -fv /etc/resolv.conf
    cp -vf /etc/pacman.d/mirrorlist.artix /etc/pacman.d/mirrorlist
}

reinstall_artix_packages() {
    log_info "Reinstalling all packages from Artix repositories..."
    export LC_ALL=C
    pacman -Sl system | grep installed | cut -d" " -f2 | pacman -S --noconfirm -
    pacman -Sl world  | grep installed | cut -d" " -f2 | pacman -S --noconfirm -
    pacman -Sl galaxy | grep installed | cut -d" " -f2 | pacman -S --noconfirm -
    if [[ "$(state_get ENABLE_ARCH_REPOS no)" == "yes" ]]; then
        pacman -Sl lib32 | grep installed | cut -d" " -f2 | pacman -S --noconfirm - 2>/dev/null || true
    fi
}

enable_lvm_services() {
    if [[ -f /etc/lvm/lvm.conf ]] || pacman -Q lvm2 &>/dev/null; then
        log_info "Enabling LVM services..."
        case "$(state_get INIT openrc)" in
            openrc)
                enable_service lvm boot
                enable_service device-mapper boot
                ;;
            runit)
                enable_service lvm2
                enable_service device-mapper
                ;;
            dinit)
                enable_service lvm2
                enable_service dmeventd
                ;;
            s6)
                ;;
        esac
    fi
}

cleanup_systemd_junk() {
    log_info "Removing systemd junk accounts and directories..."
    for user in journal journal-gateway timesync network bus-proxy journal-remote journal-upload resolve coredump; do
        userdel "systemd-$user" 2>/dev/null || true
    done
    rm -vfr /{etc,var/lib}/systemd 2>/dev/null || true
}

update_bootloader() {
    log_info "Recreating initramfs and updating bootloader..."
    if [[ -x /usr/bin/mkinitcpio ]]; then
        mkinitcpio -P 2>/dev/null || log_warn "mkinitcpio failed"
    fi
    if command -v grub-mkconfig &>/dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || log_warn "grub-mkconfig failed"
    elif command -v update-grub &>/dev/null; then
        update-grub 2>/dev/null || log_warn "update-grub failed"
    fi
    if [[ -d /boot/efi ]]; then
        log_info "Reinstalling GRUB for UEFI..."
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB 2>/dev/null || log_warn "grub-install failed"
    else
        log_info "Reinstalling GRUB for BIOS..."
        local disk
        disk="$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -n1)"
        if [[ -n "$disk" ]]; then
            grub-install "/dev/$disk" 2>/dev/null || log_warn "grub-install failed"
        fi
    fi
}

cold_reboot() {
    log_info "Init has been swapped — performing cold reboot via SysRq..."
    sync
    mount / -o remount,ro 2>/dev/null || true
    echo s >| /proc/sysrq-trigger 2>/dev/null || true
    echo u >| /proc/sysrq-trigger 2>/dev/null || true
    echo b >| /proc/sysrq-trigger 2>/dev/null || true
    reboot
}

run_init_migration() {
    local source_init="${1}" target_init="${2}"
    validate_migration "$source_init" "$target_init"

    if [[ "$source_init" == "systemd" ]]; then
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
        pacman -S --noconfirm base base-devel grub linux linux-headers mkinitcpio \
            rsync lsb-release esysusers etmpfiles artix-branding-base
        reinstall_artix_packages
    else
        local backup_dir="/root/init-backup-${source_init}-$(date +%Y%m%d-%H%M%S)"
        backup_init_config "$source_init" "$backup_dir"

        local -a custom_services
        mapfile -t custom_services < <(detect_custom_services "$source_init")
        if [[ ${#custom_services[@]} -gt 0 ]]; then
            log_warn "Custom services detected: ${custom_services[*]}"
            mkdir -p "$backup_dir/custom"
            for svc in "${custom_services[@]}"; do
                case "$source_init" in
                    openrc) cp -a "/etc/init.d/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                    runit)  cp -a "/etc/runit/sv/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                    dinit)  cp -a "/etc/dinit.d/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                    s6)     cp -a "/etc/s6/sv/$svc" "$backup_dir/custom/" 2>/dev/null || true ;;
                esac
            done
            log_info "Custom services saved to $backup_dir/custom/"
        fi

        cache_target_init_packages "$source_init" "$target_init"
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