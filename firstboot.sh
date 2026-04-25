#!/usr/bin/env bash
set -eo pipefail;

[[ -f /etc/install_config.conf ]] && source /etc/install_config.conf;

INIT="openrc";
[[ -d /run/runit ]] && INIT="runit";
[[ -d /run/dinit ]] && INIT="dinit";
[[ -d /run/s6    ]] && INIT="s6";

DRV_CHOICE=1;

_tui_msg() { dialog --title "${1}" --msgbox "${2}" 12 60; }
_tui_yesno() { dialog --title "${1}" --yesno "${2}" 8 50; }
_tui_menu() { dialog --stdout --title "${1}" --menu "${2}" 15 55 5 "${@:3}"; }

function _error_exit {
    local reason="${1}";
    dialog --title "Error" --msgbox "${reason^}" 8 50;
    exit 1;
}

function _enable_arch_repos {
    if _tui_yesno "Arch Repos" "Would you like to enable official Arch Linux repositories (Extra, Community, Multilib)?"; then
        (
            printf "[*] Installing archlinux-mirrorlist and keyring...\n"
            pacman -Sy --noconfirm artix-archlinux-support &>/dev/null

            printf "[*] Configuring /etc/pacman.conf...\n"
            if ! grep -q "\[extra\]" /etc/pacman.conf; then
                cat <<REPOS >> /etc/pacman.conf

[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
REPOS
            fi

            printf "[*] Syncing databases...\n"
            pacman -Sy --noconfirm &>/dev/null
            pacman-key --populate archlinux &>/dev/null
        ) 2>&1 | dialog --title "Enabling Arch Repos" --programbox 20 80
    fi
}


function _setup_networking {
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        local is_vm=false
        if grep -qaE "virt|vmware|kvm|qemu|oracle" /sys/class/dmi/id/product_name 2>/dev/null || \
           grep -qaE "virt|vmware|kvm|qemu|oracle" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            is_vm=true
        fi

        if [[ "${is_vm}" == "true" ]]; then
            _tui_msg "Networking" "Virtual Machine detected. Attempting to start dhcpcd..."
            case "${INIT}" in
                openrc) rc-service dhcpcd restart 2>/dev/null || true ;;
                runit)  sv restart dhcpcd 2>/dev/null || true ;;
                dinit)  dinitctl start dhcpcd 2>/dev/null || true ;;
                s6)     s6-rc -u change dhcpcd 2>/dev/null || true ;;
            esac
            sleep 3
        fi

        if ! ping -c 1 8.8.8.8 &>/dev/null; then
            local wifi_dev
            wifi_dev=$(ip link property | grep -oP '(?<=dev )wlp\S+|wlan\S+' | head -n 1 || echo "")

            local msg="No internet detected. Connectivity options:\n\n"
            if [[ -n "${wifi_dev}" ]]; then
                msg+="[ WIFI - iwctl ]\n1. station ${wifi_dev} scan\n2. station ${wifi_dev} get-networks\n3. station ${wifi_dev} connect [SSID]\n4. quit\n\n"
            fi
            
            msg+="[ ETHERNET / VM / DHCP ]\n"
            msg+="Try restarting the service for your INIT (${INIT}):\n"
            case "${INIT}" in
                openrc) msg+="sudo rc-service dhcpcd restart\n" ;;
                runit)  msg+="sudo sv restart dhcpcd\n" ;;
                dinit)  msg+="sudo dinitctl restart dhcpcd\n" ;;
                s6)     msg+="sudo s6-rc -u change dhcpcd\n" ;;
            esac
            msg+="\nManual force: sudo dhcpcd [interface_name]\n\nLaunching tools..."
            _tui_msg "Networking" "${msg}"

            case "${INIT}" in
                openrc) rc-service iwd start 2>/dev/null; rc-service dhcpcd start 2>/dev/null ;;
                runit)  sv up iwd 2>/dev/null; sv up dhcpcd 2>/dev/null ;;
                dinit)  dinitctl start iwd 2>/dev/null; dinitctl start dhcpcd 2>/dev/null ;;
                s6)     s6-rc -u change iwd 2>/dev/null; s6-rc -u change dhcpcd 2>/dev/null ;;
            esac
            
            sleep 2
            iwctl || nmtui
        fi
    fi
}

function _handle_modded_kernels {
    case "${KERNEL_CHOICE}" in
        "xanmod")
            (
                pacman-key --recv-key FBA220DFC880C036 --keyserver hkp://keyserver.ubuntu.com
                pacman-key --lsign-key FBA220DFC880C036
                if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
                    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf
                fi

                pacman -Sy --noconfirm
                pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                                     'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
                
                local CPU_LEVEL=$(/lib/ld-linux-x86-64.so.2 --help | grep -E "x86-64-v[2-4] \(supported" | head -n 1 | awk '{print $1}')
                
                case "$CPU_LEVEL" in
                    "x86-64-v4") KERNEL_PKG="linux-xanmod-x64v4" ;;
                    "x86-64-v3") KERNEL_PKG="linux-xanmod-x64v3" ;;
                    "x86-64-v2") KERNEL_PKG="linux-xanmod-x64v2" ;;
                    *)           KERNEL_PKG="linux-xanmod" ;;
                esac
                
                pacman -Sy --noconfirm "$KERNEL_PKG" "${KERNEL_PKG}-headers"

                if [[ "${BOOTLOADER}" == "grub" ]]; then
                    grub-mkconfig -o /boot/grub/grub.cfg
                elif [[ "${BOOTLOADER}" == "refind" ]]; then
                    printf "\"Boot XanMod\" \"${cmdline_opts} initrd=/boot/${ucode}.img initrd=/boot/initramfs-${KERNEL_PKG}.img\"\n" > /boot/refind_linux.conf
                fi
            ) 2>&1 | dialog --title "Xanmod Installation" --programbox 20 80 ;;
        "tkg")
            _tui_msg "Kernel" "Downloading TKG source..."
            git clone https://github.com/frogging-family/linux-tkg /tmp/linux-tkg
            chown -R "${USER_NAME:-root}": /tmp/linux-tkg
            _tui_msg "TKG" "Source ready in /tmp/linux-tkg. Because of complexity, you can compile with: cd /tmp/linux-tkg && ./install.sh" ;;
    esac
}

function _setup_audio {
    if _tui_yesno "Audio Setup" "Would you like to configure audio server?"; then
        local ac=$( _tui_menu "Audio" "Select audio server:" "1" "Pipewire" "2" "PulseAudio" )
        case "${ac}" in
            1) pacman -S --noconfirm pipewire pipewire-pulse wireplumber && pacman -S --noconfirm "pipewire-${INIT}" 2>/dev/null || true ;;
            2) pacman -S --noconfirm pulseaudio pulseaudio-alsa && pacman -S --noconfirm "pulseaudio-${INIT}" 2>/dev/null || true ;;
        esac
    fi
}

function _handle_drivers {
    local pkgs=(); local gpu_info=$(lspci | grep -iE "vga|3d")
    if _tui_yesno "Drivers" "Install drivers for: ${gpu_info}?"; then
        DRV_CHOICE=$(_tui_menu "Drivers" "Select driver type:" "1" "xLibre (Libre)" "2" "Standard X.Org")
        if [[ "${gpu_info,,}" == *nvidia* ]]; then
            [[ "${DRV_CHOICE}" == "2" ]] && pkgs+=( "nvidia-dkms" "nvidia-utils" ) || pkgs+=( "xlibre-video-nouveau" )
        elif [[ "${gpu_info,,}" == *intel* ]]; then
            [[ "${DRV_CHOICE}" == "2" ]] && pkgs+=( "xf86-video-intel" "intel-media-driver" ) || pkgs+=( "xlibre-video-intel" )
        elif [[ "${gpu_info,,}" == *amd* ]]; then
            [[ "${DRV_CHOICE}" == "2" ]] && pkgs+=( "xf86-video-amdgpu" "vulkan-radeon" ) || pkgs+=( "xlibre-video-amdgpu" "vulkan-radeon" )
        fi
        [[ "${DRV_CHOICE}" == "2" ]] && pkgs+=( "xorg-server" ) || pkgs+=( "xlibre-xserver" )
        pacman -S --noconfirm --needed "${pkgs[@]}"
    fi
}

function _install_interface {
    _handle_drivers; 
    local pkgs=("dbus" "dbus-${INIT}");
    local dm="lightdm"; 
    local common="gvfs gvfs-mtp xdg-user-dirs"
    
    case "${WM_DE}" in
        "xfce4")    pkgs+=("xfce4" "xfce4-goodies" $common) ;;
        "lxqt")     pkgs+=("lxqt" "pavucontrol-qt" $common); dm="sddm" ;;
        "lxde")     pkgs+=("lxde" "lxappearance" $common) ;;
        "hyprland") pkgs+=("hyprland" "seatd" "seatd-${INIT}" "xdg-desktop-portal-hyprland" "foot") ;;
        "niri")     pkgs+=("niri" "seatd" "seatd-${INIT}" "foot") ;;
        "i3wm")     pkgs+=("i3-wm" "i3status" "i3lock" "xterm") ;;
        "dwm"|"vxvm") pkgs+=("libx11" "libxft" "libxinerama" "xorg-server-devel" "base-devel" "git" "imlib2" "xorg-xinit" "xorg-xsetroot") ;;
    esac

    if [[ ${#pkgs[@]} -gt 2 ]]; then
        (
            if [[ "${DRV_CHOICE:-2}" == "1" ]]; then
                local x_ver;
                x_ver=$(pacman -Si xorg-server 2>/dev/null | grep Version | awk '{print $3}' | cut -d'-' -f1 || echo "21.1.13")
                pacman -S --noconfirm --needed --assume-installed "xorg-server=${x_ver}" "${pkgs[@]}"
            else
                pacman -S --noconfirm --needed "${pkgs[@]}"
            fi
        ) 2>&1 | dialog --title "Interface Installation" --programbox 20 80
    fi

    case "${INIT}" in
        openrc) rc-update add dbus default; rc-service dbus start 2>/dev/null || true ;;
        runit)  ln -s /etc/runit/sv/dbus /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
        dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../dbus /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
        s6)     s6-rc-bundle-update add default dbus 2>/dev/null || true ;;
    esac

    case "${WM_DE}" in
        dwm|vxvm)
            (
                local repo_url="git://git.suckless.org/dwm"
                [[ "${WM_DE}" =~ ^vxv[m|w]$ ]] && repo_url="https://codeberg.org/wh1tepearl/vxwm" 
                
                git clone "${repo_url}" "/tmp/${WM_DE}"
                cd "/tmp/${WM_DE}"
                [[ -f config.def.h ]] && cp config.def.h config.h
                make clean install
                
                if [[ -n "${USER_NAME:-}" ]]; then
                    local user_home="/home/${USER_NAME}"
                    printf "while true; do xsetroot -name \"\$(date '+\%%H:\%%M')\"; sleep 60; done &\nexec ${WM_DE}\n" > "${user_home}/.xinitrc"
                    chown "${USER_NAME}:${USER_NAME}" "${user_home}/.xinitrc"
                    chmod +x "${user_home}/.xinitrc"
                fi
            ) 2>&1 | dialog --title "Compiling ${WM_DE}" --programbox 20 80 ;;
        hyprland|niri)
            case "${INIT}" in
                openrc) rc-update add seatd default; rc-service seatd start 2>/dev/null || true ;;
                runit)  ln -s /etc/runit/sv/seatd /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
                dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../seatd /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
                s6)     s6-rc-bundle-update add default seatd 2>/dev/null || true ;;
            esac; [[ -n "${USER_NAME:-}" ]] && usermod -aG video,render,input "${USER_NAME}" ;;
        xfce4|lxqt|lxde)
            pacman -S --noconfirm "${dm}" "${dm}-${INIT}"
            [[ "${dm}" == "lightdm" ]] && pacman -S --noconfirm lightdm-gtk-greeter
            case "${INIT}" in
                openrc) rc-update add "${dm}" default ;;
                runit)  ln -s "/etc/runit/sv/${dm}" /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
                dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../${dm} /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
                s6)     s6-rc-bundle-update add default "${dm}" 2>/dev/null || true ;;
            esac ;;
    esac
}


function _install_bonus_tools {
    if _tui_yesno "Extras" "Enter bonus tools menu?"; then

        if _tui_yesno "Git" "Install Git & Base-Devel?"; then
             ( pacman -S --noconfirm git base-devel ) 2>&1 | dialog --title "Extras" --programbox 20 80
        fi

        if _tui_yesno "Codecs" "Install Multimedia Codecs (essential for video/audio)?"; then
            ( pacman -S --noconfirm alsa-utils alsa-plugins gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav ) 2>&1 | dialog --title "Extras" --programbox 20 80
        fi

        if _tui_yesno "Firewall" "Install UFW?"; then
            ( pacman -S --noconfirm ufw "ufw-${INIT}" ) 2>&1 | dialog --title "Extras" --programbox 20 80
            case "${INIT}" in
                openrc) rc-update add ufw default ;;
                runit)  ln -s /etc/runit/sv/ufw /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
                dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../ufw /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
                s6)     s6-rc-bundle-update add default ufw 2>/dev/null || true ;;
            esac
        fi

        if _tui_yesno "Bluetooth" "Install Bluetooth stack (Bluez)?"; then
            ( pacman -S --noconfirm bluez bluez-utils "bluez-${INIT}" ) 2>&1 | dialog --title "Extras" --programbox 20 80
            case "${INIT}" in
                openrc) rc-update add bluetooth default ;;
                runit)  ln -s /etc/runit/sv/bluetoothd /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
                dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../bluetoothd /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
            esac
        fi

        _tui_yesno "Flatpak" "Install Flatpak support?" && pacman -S --noconfirm flatpak

        if _tui_yesno "Zram" "Install Zram-tools for better RAM management?"; then
            ( pacman -S --noconfirm zram-tools "zram-tools-${INIT}" ) 2>&1 | dialog --title "Extras" --programbox 20 80
            [[ "${INIT}" == "openrc" ]] && rc-update add zramd default
        fi

        _tui_yesno "Fastfetch" "Install Fastfetch?" && pacman -S --noconfirm fastfetch

        if [[ "${INIT}" == "runit" ]] && _tui_yesno "rsvc" "Install SashexSRB's rsvc?"; then
            ( git clone https://github.com/SashexSRB/rsvc /tmp/rsvc && cd /tmp/rsvc && make && make install ) 2>&1 | dialog --title "rsvc Installation" --programbox 20 80
        fi
    fi
}

function main {
    [[ "${EUID}" -ne 0 ]] && _error_exit "must be run as root";
    _setup_networking; _enable_arch_repos; _handle_modded_kernels; _install_interface; _setup_audio; _install_bonus_tools
    touch /var/lib/artix-firstboot-done; rm -f /etc/profile.d/firstboot.sh; _tui_msg "Finish" "Setup complete. Please reboot."
}
main;
