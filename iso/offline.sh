#!/usr/bin/env bash
set -Eeuo pipefail

build_offline_repo() {
    local repo_dir="${1}"
    mkdir -p "${repo_dir}"

    local blank_db="/tmp/blank_db"
    mkdir -p "${blank_db}"

    log_info "Downloading all packages for offline installation..."

    local -a offline_pkgs=(
        base base-devel linux-firmware bash nano vim sudo git curl wget pciutils
        mkinitcpio efibootmgr dosfstools gptfdisk parted cryptsetup lvm2
        btrfs-progs xfsprogs f2fs-tools exfatprogs e2fsprogs
        gum artools openssl rsync bc cpio pahole libelf
        intel-ucode amd-ucode
        grub os-prober refind limine
        networkmanager dhcpcd iwd connman
        pipewire pipewire-pulse pipewire-alsa wireplumber alsa-utils pavucontrol rtkit pipewire-jack
        pulseaudio pulseaudio-alsa
        xlibre-xserver xlibre-xserver-common xlibre-input-libinput xlibre-input-evdev
        xorg-server xorg-xinit xf86-input-libinput xf86-input-evdev
        plasma-desktop dolphin konsole sddm
        xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
        lxqt lxde-common lxde
        hyprland sway swaybg swaylock waybar foot niri
        i3-wm i3status i3lock dmenu xterm dwm icewm
        seatd elogind dbus
        eukify
        zfs-dkms zfs-utils bcachefs-tools
        git flatpak fastfetch firewalld bluez zram-tools
        fzf zoxide starship eza btop htop nvtop tmux
        nano neovim micro helix
        firefox chromium qutebrowser
        ranger lf nnn thunar
        alacritty kitty foot
        mpv feh
    )

    pacman -Syw --cachedir "${repo_dir}" --dbpath "${blank_db}" --noconfirm "${offline_pkgs[@]}" 2>/dev/null || {
        log_warn "Some packages could not be downloaded – continuing with what we have"
    }

    if compgen -G "${repo_dir}/*.pkg.tar.*" >/dev/null 2>&1; then
        repo-add "${repo_dir}/custom.db.tar.zst" "${repo_dir}"/*.pkg.tar.* 2>/dev/null || true
        log_info "Offline repository created: ${repo_dir}"
    else
        log_warn "No packages downloaded – offline repository empty"
    fi
}