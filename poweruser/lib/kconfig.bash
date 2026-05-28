#!/usr/bin/env bash
set -Eeuo pipefail

apply_basic_config() {
    ensure_boot_essentials
    source "${POWERUSER_DIR}/lib/hwdetect.bash"
    local rec
    while IFS= read -r rec; do
        if [[ "${rec}" == CONFIG_*=y ]]; then
            scripts/config --enable "${rec#CONFIG_}"
        elif [[ "${rec}" == CONFIG_*=m ]]; then
            scripts/config --module "${rec#CONFIG_}"
        fi
    done < <(recommendations)
}

ensure_boot_essentials() {
    scripts/config --enable BLOCK
    scripts/config --enable BLK_DEV
    scripts/config --enable VIRTIO
    scripts/config --enable VIRTIO_MENU
    scripts/config --enable VIRTIO_PCI
    scripts/config --module VIRTIO_BLK
    scripts/config --module USB_HID
    scripts/config --enable BLK_DEV_SD
    scripts/config --enable BLK_DEV_NVME
    scripts/config --enable ATA
    scripts/config --enable SATA_AHCI
    scripts/config --enable NET
    scripts/config --enable INET
    scripts/config --enable PACKET
    scripts/config --enable TTY
    scripts/config --enable VT
    scripts/config --enable UNIX98_PTYS
    scripts/config --enable PROC_FS
    scripts/config --enable SYSFS
    scripts/config --enable DEVTMPFS
    scripts/config --enable TMPFS
    scripts/config --enable BINFMT_ELF
}

apply_advanced_config() {
    ensure_boot_essentials
    local fs
    fs="$(state_get KERNEL_ADV_FS "")"
    for f in ${fs}; do
        case "${f}" in
            ext4)   scripts/config --enable EXT4_FS ;;
            btrfs)  scripts/config --enable BTRFS_FS ;;
            xfs)    scripts/config --enable XFS_FS ;;
            f2fs)   scripts/config --module F2FS_FS ;;
            exfat)  scripts/config --module EXFAT_FS ;;
            ntfs)   scripts/config --module NTFS3_FS ;;
            overlay) scripts/config --module OVERLAY_FS ;;
        esac
    done
    local fs_disable="ext4 btrfs xfs f2fs exfat ntfs overlay"
    for f in ${fs_disable}; do
        [[ " ${fs} " =~ " ${f} " ]] && continue
        case "${f}" in
            ext4)   scripts/config --disable EXT4_FS ;;
            btrfs)  scripts/config --disable BTRFS_FS ;;
            xfs)    scripts/config --disable XFS_FS ;;
            f2fs)   scripts/config --disable F2FS_FS ;;
            exfat)  scripts/config --disable EXFAT_FS ;;
            ntfs)   scripts/config --disable NTFS3_FS ;;
            overlay) scripts/config --disable OVERLAY_FS ;;
        esac
    done

    local gpu
    gpu="$(state_get KERNEL_ADV_GPU "")"
    for g in ${gpu}; do
        case "${g}" in
            intel)   scripts/config --module DRM_I915 ;;
            amd)     scripts/config --module DRM_AMDGPU
                     scripts/config --enable DRM_AMDGPU_SI
                     scripts/config --enable DRM_AMDGPU_CIK ;;
            nvidia)  scripts/config --module DRM_NOUVEAU ;;
            virtio)  scripts/config --enable DRM_VIRTIO_GPU ;;
            vesa)    scripts/config --enable DRM_VESA ;;
            simpledrm) scripts/config --enable DRM_SIMPLEDRM ;;
        esac
    done
    [[ " ${gpu} " =~ " intel " ]] || scripts/config --disable DRM_I915
    [[ " ${gpu} " =~ " amd " ]] || { scripts/config --disable DRM_AMDGPU; scripts/config --disable DRM_AMDGPU_SI; scripts/config --disable DRM_AMDGPU_CIK; }
    [[ " ${gpu} " =~ " nvidia " ]] || scripts/config --disable DRM_NOUVEAU
    [[ " ${gpu} " =~ " virtio " ]] || scripts/config --disable DRM_VIRTIO_GPU
    [[ " ${gpu} " =~ " vesa " ]] || scripts/config --disable DRM_VESA
    [[ " ${gpu} " =~ " simpledrm " ]] || scripts/config --disable DRM_SIMPLEDRM

    local net
    net="$(state_get KERNEL_ADV_NET "")"
    for n in ${net}; do
        case "${n}" in
            intel)     scripts/config --module E1000; scripts/config --module E1000E ;;
            realtek)   scripts/config --module R8169 ;;
            broadcom)  scripts/config --module TIGON3; scripts/config --module BNX2 ;;
            atheros)   scripts/config --module ATL1 ;;
            virtio)    scripts/config --enable VIRTIO_NET ;;
            intel-wifi) scripts/config --module IWLWIFI ;;
            ath-wifi)  scripts/config --module ATH9K; scripts/config --module ATH10K ;;
            realtek-wifi) scripts/config --module RTL8XXXU ;;
            bt)        scripts/config --module BT; scripts/config --module BTUSB ;;
        esac
    done

    local net_entries="intel realtek broadcom atheros virtio intel-wifi ath-wifi realtek-wifi bt"
    for n in ${net_entries}; do
        [[ " ${net} " =~ " ${n} " ]] && continue
        case "${n}" in
            intel)     scripts/config --disable E1000; scripts/config --disable E1000E ;;
            realtek)   scripts/config --disable R8169 ;;
            broadcom)  scripts/config --disable TIGON3; scripts/config --disable BNX2 ;;
            atheros)   scripts/config --disable ATL1 ;;
            virtio)    scripts/config --disable VIRTIO_NET ;;
            intel-wifi) scripts/config --disable IWLWIFI ;;
            ath-wifi)  scripts/config --disable ATH9K; scripts/config --disable ATH10K ;;
            realtek-wifi) scripts/config --disable RTL8XXXU ;;
            bt)        scripts/config --disable BT; scripts/config --disable BTUSB ;;
        esac
    done

    local usb
    usb="$(state_get KERNEL_ADV_USB "")"
    for u in ${usb}; do
        case "${u}" in
            storage) scripts/config --module USB_STORAGE ;;
            hid)     scripts/config --enable USB_HID ;;
            serial)  scripts/config --module USB_SERIAL ;;
        esac
    done

    [[ " ${usb} " =~ " storage " ]] || scripts/config --disable USB_STORAGE
    [[ " ${usb} " =~ " hid " ]] || scripts/config --disable USB_HID
    [[ " ${usb} " =~ " serial " ]] || scripts/config --disable USB_SERIAL

    local snd
    snd="$(state_get KERNEL_ADV_SOUND "")"
    for s in ${snd}; do
        case "${s}" in
            intel-hda) scripts/config --module SND_HDA_INTEL ;;
            amd-hda)   scripts/config --module SND_HDA_AMD ;;
            usb-audio) scripts/config --module SND_USB_AUDIO ;;
        esac
    done

    [[ " ${snd} " =~ " intel-hda " ]] || scripts/config --disable SND_HDA_INTEL
    [[ " ${snd} " =~ " amd-hda " ]] || scripts/config --disable SND_HDA_AMD
    [[ " ${snd} " =~ " usb-audio " ]] || scripts/config --disable SND_USB_AUDIO

    local sec
    sec="$(state_get KERNEL_ADV_SECURITY "")"
    for s in ${sec}; do
        case "${s}" in
            selinux)   scripts/config --enable SECURITY_SELINUX ;;
            apparmor)  scripts/config --enable SECURITY_APPARMOR ;;
            lockdown)  scripts/config --enable SECURITY_LOCKDOWN_LSM ;;
        esac
    done

    [[ " ${sec} " =~ " selinux " ]] || scripts/config --disable SECURITY_SELINUX
    [[ " ${sec} " =~ " apparmor " ]] || scripts/config --disable SECURITY_APPARMOR
    [[ " ${sec} " =~ " lockdown " ]] || scripts/config --disable SECURITY_LOCKDOWN_LSM

    local virt
    virt="$(state_get KERNEL_ADV_VIRT "")"
    for v in ${virt}; do
        case "${v}" in
            kvm)     scripts/config --module KVM ;;
            vhost)   scripts/config --module VHOST_NET ;;
        esac
    done

    [[ " ${virt} " =~ " kvm " ]] || scripts/config --disable KVM
    [[ " ${virt} " =~ " vhost " ]] || scripts/config --disable VHOST_NET

    local dbg
    dbg="$(state_get KERNEL_ADV_DEBUG "")"
    for d in ${dbg}; do
        case "${d}" in
            ftrace)   scripts/config --enable FTRACE ;;
            perf)     scripts/config --enable PERF_EVENTS ;;
            kprobes)  scripts/config --enable KPROBES ;;
            ebpf)     scripts/config --enable BPF_SYSCALL ;;
        esac
    done

    [[ " ${dbg} " =~ " ftrace " ]] || scripts/config --disable FTRACE
    [[ " ${dbg} " =~ " perf " ]] || scripts/config --disable PERF_EVENTS
    [[ " ${dbg} " =~ " kprobes " ]] || scripts/config --disable KPROBES
    [[ " ${dbg} " =~ " ebpf " ]] || scripts/config --disable BPF_SYSCALL

    local preempt
    preempt="$(state_get KERNEL_PREEMPT "voluntary")"
    case "${preempt}" in
        voluntary)  scripts/config --enable PREEMPT_VOLUNTARY
                    scripts/config --disable PREEMPT
                    scripts/config --disable PREEMPT_RT ;;
        full)       scripts/config --disable PREEMPT_VOLUNTARY
                    scripts/config --enable PREEMPT
                    scripts/config --disable PREEMPT_RT ;;
        rt)         scripts/config --disable PREEMPT_VOLUNTARY
                    scripts/config --disable PREEMPT
                    scripts/config --enable PREEMPT_RT ;;
    esac

    local timer
    timer="$(state_get KERNEL_TIMER "250")"
    scripts/config --set-val CONFIG_HZ "${timer}"

    local gov
    gov="$(state_get KERNEL_GOVERNOR "schedutil")"
    case "${gov}" in
        performance) scripts/config --enable CPU_FREQ_DEFAULT_GOV_PERFORMANCE ;;
        ondemand)    scripts/config --enable CPU_FREQ_DEFAULT_GOV_ONDEMAND ;;
        schedutil)   scripts/config --enable CPU_FREQ_DEFAULT_GOV_SCHEDUTIL ;;
    esac
}