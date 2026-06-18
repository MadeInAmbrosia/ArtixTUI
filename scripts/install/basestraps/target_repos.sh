#!/usr/bin/env bash
set -Eeuo pipefail

basestrap_target_repo_cachyos() {
    if ! grep -q '^\[cachyos\]' /mnt/etc/pacman.conf 2>/dev/null; then
        mkdir -p /mnt/etc/pacman.d
        cp /etc/pacman.d/cachyos-mirrorlist /mnt/etc/pacman.d/ 2>/dev/null || true
        cp /etc/pacman.d/cachyos-v3-mirrorlist /mnt/etc/pacman.d/ 2>/dev/null || true
        cp /etc/pacman.d/cachyos-v4-mirrorlist /mnt/etc/pacman.d/ 2>/dev/null || true

        local cpu_level
        cpu_level=$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -oP 'x86-64-v[2-4]' | head -n1 || true)

        if [[ "${cpu_level}" == "x86-64-v4" ]]; then
            local cpu_model vendor
            cpu_model=$(grep -m1 'model' /proc/cpuinfo | awk '{print $3}')
            vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
            if [[ "${vendor}" == "GenuineIntel" && "${cpu_model}" -ge 151 ]]; then
                log_warn "Intel 12th gen+ detected — AVX-512 is fused off, using v3 instead of v4"
                cpu_level="x86-64-v3"
            fi
        fi

        if [[ "${cpu_level}" == "x86-64-v4" ]]; then
            if ! grep -q '^Architecture =.*x86_64_v4' /mnt/etc/pacman.conf; then
                sed -i '/^\[options\]/a Architecture = x86_64 x86_64_v4' /mnt/etc/pacman.conf
            fi
            cat <<'EOF' >> /mnt/etc/pacman.conf
[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

EOF
        elif [[ "${cpu_level}" == "x86-64-v3" ]]; then
            cat <<'EOF' >> /mnt/etc/pacman.conf
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

EOF
        fi

        cat <<'EOF' >> /mnt/etc/pacman.conf
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
    fi
}

basestrap_target_repo_bazzite() {
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
}

basestrap_target_repo_xanmod() {
    if ! grep -q '^\[chaotic-aur\]' /mnt/etc/pacman.conf 2>/dev/null; then
        mkdir -p /mnt/etc/pacman.d
        cp /etc/pacman.d/chaotic-mirrorlist /mnt/etc/pacman.d/ 2>/dev/null || true
        cat <<'EOF' >> /mnt/etc/pacman.conf
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    fi
}