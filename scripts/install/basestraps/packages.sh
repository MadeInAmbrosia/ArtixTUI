#!/usr/bin/env bash
set -Eeuo pipefail

basestrap_kernel_standard() {
    local -n pkgs_ref="${1}"
    local skip="${2}"
    if [[ ${skip} -eq 1 ]]; then
        log_info "Skipping binary ${kernel} kernel (fallback disabled)"
    else
        pkgs_ref+=("${KERNEL_PACKAGE}" "${KERNEL_HEADERS}")
    fi
}

basestrap_kernel_linux_libre() {
    local -n pkgs_ref="${1}"
    local skip="${2}"
    if [[ ${skip} -eq 1 ]]; then
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
        pkgs_ref+=(linux-libre linux-libre-headers)
        log_warn "linux-libre removes non-free firmware/drivers. NVIDIA, Wi‑Fi, Bluetooth may stop working."
    fi
}

basestrap_kernel_cachyos() {
    local -n pkgs_ref="${1}"
    local skip="${2}"
    if [[ ${skip} -eq 1 ]]; then
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
        pacman -U --noconfirm \
            "https://mirror.cachyos.org/repo/x86_64/cachyos/${cachyos_keyring}" \
            "https://mirror.cachyos.org/repo/x86_64/cachyos/${cachyos_mirrorlist}" || {
            log_error "Failed to install CachyOS bootstrap packages — mirror may be down"
            die 'CachyOS repository setup failed'
        }

        local cpu_level
        cpu_level=$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -oP 'x86-64-v[2-4]' | head -n1 || true)

        if [[ "${cpu_level}" == "x86-64-v4" ]]; then
            cat <<'EOF' >> /etc/pacman.conf
[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

EOF
            pacman -U --noconfirm "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst" 2>/dev/null || true
        elif [[ "${cpu_level}" == "x86-64-v3" ]]; then
            cat <<'EOF' >> /etc/pacman.conf
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

EOF
            pacman -U --noconfirm "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-22-1-any.pkg.tar.zst" 2>/dev/null || true
        fi

        if ! grep -q '^\[cachyos\]' /etc/pacman.conf; then
            cat <<'EOF' >> /etc/pacman.conf
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
        fi
        pkgs_ref+=("${kernel}" "${kernel}-headers")
    fi
}

basestrap_kernel_bazzite() {
    local -n pkgs_ref="${1}"
    local skip="${2}"
    if [[ ${skip} -eq 1 ]]; then
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
        pkgs_ref+=(base-devel git mkinitcpio)
    fi
}

basestrap_kernel_xanmod() {
    local -n pkgs_ref="${1}"
    local skip="${2}"
    if [[ ${skip} -eq 1 ]]; then
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
        pkgs_ref+=("${KERNEL_PACKAGE}" "${KERNEL_HEADERS}")
    fi
}

basestrap_kernel_tkg() {
    local -n pkgs_ref="${1}"
    log_info "Setting up TKG build dependencies..."
    pkgs_ref+=(bc cpio flex libelf pahole base-devel git dkms)
}