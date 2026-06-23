#!/usr/bin/env bash
set -Eeuo pipefail

ata_backup_all() {
    local backup_dir="${1}"
    mkdir -p "${backup_dir}"
    chmod 700 "${backup_dir}"

    log_info "Creating backup at ${backup_dir}..."

    # /home
    while IFS= read -r user; do
        [[ -d "/home/${user}" ]] && cp -a "/home/${user}" "${backup_dir}/home/${user}"
    done < /tmp/ata-users.txt

    # /etc
    cp -a /etc "${backup_dir}/etc"

    # Pacman database
    cp -a /var/lib/pacman "${backup_dir}/var-lib-pacman"

    # Cron spool
    cp -a /var/spool/cron "${backup_dir}/var-spool-cron" 2>/dev/null || true

    # Boot
    cp -a /boot "${backup_dir}/boot"

    # /usr/local
    [[ -d /usr/local ]] && cp -a /usr/local "${backup_dir}/usr-local"

    # Network credentials (secured)
    mkdir -p "${backup_dir}/network-configs"
    for d in /etc/systemd/network /var/lib/systemd/network /etc/NetworkManager/system-connections /etc/netctl /var/lib/iwd; do
        [[ -d "$d" ]] && cp -a "$d" "${backup_dir}/network-configs/"
    done
    chmod -R 700 "${backup_dir}/network-configs"

    # Journal export
    if command -v journalctl >/dev/null 2>&1; then
        log_info "Exporting system journal..."
        journalctl --no-pager --output=short-full > "${backup_dir}/journal-full.txt" 2>/dev/null || true
        journalctl --export > "${backup_dir}/journal-export.bin" 2>/dev/null || true
    fi

    # Detection lists
    mkdir -p "${backup_dir}/lists"
    for f in /tmp/ata-*.txt /tmp/ata-*.conf /tmp/ata-*.rules; do
        [[ -f "$f" ]] && cp "$f" "${backup_dir}/lists/"
    done

    log_info "Backup saved to ${backup_dir}"
}