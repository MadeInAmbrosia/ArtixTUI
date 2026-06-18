#!/usr/bin/env bash
set -Eeuo pipefail

generate_iso_package_list() {
    local init="${1}" kernel="${2}"

    local -a pkg_list=()

    pkg_list+=(
        base base-devel linux-firmware bash nano vim sudo git curl wget pciutils
        mkinitcpio efibootmgr dosfstools gptfdisk parted cryptsetup lvm2
        btrfs-progs xfsprogs f2fs-tools exfatprogs e2fsprogs
        gum artools openssl rsync
        bc cpio pahole libelf
    )
    pkg_list+=(intel-ucode amd-ucode)
    pkg_list+=("${kernel}" "${kernel}-headers")

    case "${init}" in
        openrc) pkg_list+=(openrc) ;;
        runit)  pkg_list+=(runit) ;;
        dinit)  pkg_list+=(dinit dinit-base dinit-rc) ;;
        s6)     pkg_list+=(s6 s6-rc) ;;
    esac

    pkg_list+=(dbus "dbus-${init}")

    local wm_de
    wm_de="$(state_get WM_DE none)"
    case "${wm_de}" in
        hyprland|sway|niri|mango)
            pkg_list+=(seatd "seatd-${init}") ;;
        *)
            pkg_list+=("elogind-${init}") ;;
    esac

    local priv_esc
    priv_esc="$(state_get PRIV_ESCALATION sudo)"
    pkg_list+=("${priv_esc}")

    local user_shell
    user_shell="$(state_get USER_SHELL bash)"
    case "${user_shell}" in
        zsh)  pkg_list+=(zsh) ;;
        fish) pkg_list+=(fish) ;;
    esac

    local network_stack
    network_stack="$(state_get NETWORK_STACK networkmanager)"
    case "${network_stack}" in
        networkmanager) pkg_list+=(networkmanager "networkmanager-${init}") ;;
        dhcpcd+iwd)     pkg_list+=(dhcpcd iwd "dhcpcd-${init}" "iwd-${init}") ;;
        connman)        pkg_list+=(connman "connman-${init}") ;;
    esac

    local audio_stack
    audio_stack="$(state_get AUDIO_STACK pipewire)"
    case "${audio_stack}" in
        pipewire)   pkg_list+=(pipewire pipewire-pulse pipewire-alsa wireplumber alsa-utils pavucontrol rtkit) ;;
        pulseaudio) pkg_list+=(pulseaudio pulseaudio-alsa alsa-utils pavucontrol) ;;
    esac

    case "${wm_de}" in
        kde)     pkg_list+=(plasma-desktop dolphin konsole sddm "sddm-${init}") ;;
        xfce)    pkg_list+=(xfce4 xfce4-goodies lightdm lightdm-gtk-greeter "lightdm-${init}") ;;
        lxqt)    pkg_list+=(lxqt sddm "sddm-${init}") ;;
        lxde)    pkg_list+=(lxde-common lxde lightdm lightdm-gtk-greeter "lightdm-${init}") ;;
        hyprland) pkg_list+=(hyprland swaybg swaylock waybar) ;;
        sway)    pkg_list+=(sway swaybg swaylock waybar) ;;
        niri)    pkg_list+=(niri swaybg swaylock) ;;
        i3wm)    pkg_list+=(i3-wm i3status i3lock dmenu xterm lightdm lightdm-gtk-greeter "lightdm-${init}") ;;
        dwm)     pkg_list+=(dwm dmenu xterm lightdm lightdm-gtk-greeter "lightdm-${init}") ;;
        vxwm)    pkg_list+=(base-devel git libx11 libxft libxinerama freetype2 xorg-server xorg-xinit) ;;
        icewm)   pkg_list+=(icewm lightdm lightdm-gtk-greeter "lightdm-${init}") ;;
        mango)   pkg_list+=(base-devel git) ;;
    esac

    local x_stack
    x_stack="$(state_get X_STACK xlibre)"
    case "${x_stack}" in
        xlibre) pkg_list+=(xlibre-xserver xlibre-xserver-common xlibre-input-libinput xlibre-input-evdev) ;;
        xorg)   pkg_list+=(xorg-server xorg-xinit xf86-input-libinput xf86-input-evdev) ;;
    esac

    local extras
    extras="$(state_get EXTRAS "")"
    for extra in ${extras}; do
        pkg_list+=("${extra}")
    done

    local iso_extras
    iso_extras="$(state_get ISO_EXTRA_PACKAGES "")"
    for extra in ${iso_extras}; do
        pkg_list+=("${extra}")
    done

    printf '%s\n' "${pkg_list[@]}" | sort -u
}

generate_artools_profile() {
    local out_dir="${1}" profile_name="${2}" init="${3}" kernel="${4}" boot_mode="${5:-live}"

    mkdir -p "${out_dir}"/{live-overlay,desktop-overlay,airootfs/etc}

    generate_iso_package_list "${init}" "${kernel}" > "${out_dir}/packages.x86_64"

    case "${init}" in
        openrc)
            mkdir -p "${out_dir}/live-overlay/etc/runlevels/default"
            for svc in NetworkManager elogind dbus; do
                ln -sf "/etc/init.d/${svc}" "${out_dir}/live-overlay/etc/runlevels/default/${svc}" 2>/dev/null || true
            done
            ;;
        dinit)
            mkdir -p "${out_dir}/live-overlay/etc/dinit.d/boot.d"
            for svc in NetworkManager elogind dbus; do
                ln -sf "/etc/dinit.d/${svc}" "${out_dir}/live-overlay/etc/dinit.d/boot.d/${svc}" 2>/dev/null || true
            done
            ;;
        runit)
            mkdir -p "${out_dir}/live-overlay/etc/runit/runsvdir/default"
            for svc in NetworkManager elogind dbus; do
                ln -sf "/etc/runit/sv/${svc}" "${out_dir}/live-overlay/etc/runit/runsvdir/default/${svc}" 2>/dev/null || true
            done
            ;;
        s6)
            log_info "s6 live overlay: services must be compiled by the user post-build"
            ;;
    esac

    if [[ "${boot_mode}" == "installer" ]]; then
        log_info "Configuring installer ISO auto‑boot..."
        case "${init}" in
            openrc)
                mkdir -p "${out_dir}/live-overlay/etc/local.d"
                cat > "${out_dir}/live-overlay/etc/local.d/artixforge.start" <<'EOF'
#!/bin/sh
clear
printf '\n\e[1;34m  Welcome to ArtixForge Installer\e[0m\n\n'
printf '  The installer will start automatically.\n'
printf '  Press Ctrl+C for a shell.\n\n'
sleep 2
cd /root/ArtixForge && ./install
EOF
                chmod +x "${out_dir}/live-overlay/etc/local.d/artixforge.start"
                ;;
            dinit)
                mkdir -p "${out_dir}/live-overlay/etc/dinit.d"
                cat > "${out_dir}/live-overlay/etc/dinit.d/artixforge" <<'EOF'
type = process
command = /root/ArtixForge/install
restart = false
logfile = /tmp/artixforge-installer.log
EOF
                mkdir -p "${out_dir}/live-overlay/etc/dinit.d/boot.d"
                ln -sf "../artixforge" "${out_dir}/live-overlay/etc/dinit.d/boot.d/artixforge" 2>/dev/null || true
                ;;
            runit)
                mkdir -p "${out_dir}/live-overlay/etc/runit/sv/artixforge"
                cat > "${out_dir}/live-overlay/etc/runit/sv/artixforge/run" <<'EOF'
#!/bin/sh
clear
printf '\n\e[1;34m  Welcome to ArtixForge Installer\e[0m\n\n'
printf '  The installer will start automatically.\n'
printf '  Press Ctrl+C for a shell.\n\n'
sleep 2
exec /root/ArtixForge/install
EOF
                chmod +x "${out_dir}/live-overlay/etc/runit/sv/artixforge/run"
                mkdir -p "${out_dir}/live-overlay/etc/runit/runsvdir/default"
                ln -sf "/etc/runit/sv/artixforge" "${out_dir}/live-overlay/etc/runit/runsvdir/default/artixforge" 2>/dev/null || true
                ;;
            s6)
                log_info "s6 installer mode: cannot auto-launch without compiled service database"
                mkdir -p "${out_dir}/live-overlay/etc"
                cat > "${out_dir}/live-overlay/etc/motd" <<'EOF'

  Welcome to ArtixForge Installer (s6)
  
  The installer is available at: /root/ArtixForge/install
  Run: cd /root/ArtixForge && ./install

EOF
                ;;
        esac
        rm -f "${out_dir}/live-overlay/etc/runlevels/default/lightdm" 2>/dev/null || true
        rm -f "${out_dir}/live-overlay/etc/runlevels/default/sddm" 2>/dev/null || true
        rm -f "${out_dir}/live-overlay/etc/dinit.d/boot.d/lightdm" 2>/dev/null || true
        rm -f "${out_dir}/live-overlay/etc/dinit.d/boot.d/sddm" 2>/dev/null || true
        rm -f "${out_dir}/live-overlay/etc/runit/runsvdir/default/lightdm" 2>/dev/null || true
        rm -f "${out_dir}/live-overlay/etc/runit/runsvdir/default/sddm" 2>/dev/null || true
    fi

    cat > "${out_dir}/profile.conf" <<EOF
initsys="${init}"
kernel="${kernel}"
username="artix"
password="artix"
dist_release="artixforge-${profile_name,,}"
dist_branding="${profile_name}"
EOF

    mkdir -p "${out_dir}/airootfs/root"
    cp -a "${BASE_DIR}" "${out_dir}/airootfs/root/ArtixForge"
    log_info "ArtixForge copied into ISO at /root/ArtixForge"

    log_info "Artools profile generated: ${out_dir}"
}