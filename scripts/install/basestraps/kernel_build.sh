#!/usr/bin/env bash
set -Eeuo pipefail

basestrap_build_tkg() {
    log_info "Building TKG kernel inside target chroot..."

    local failed_patches=""
    
    artix-chroot /mnt bash -c "
        pacman -S --noconfirm --needed base-devel git bc cpio flex libelf pahole dkms
        
        cd /tmp
        rm -rf linux-tkg linux-custom
        
        git clone --depth 1 https://github.com/Frogging-Family/linux-tkg.git
        
        artix_kver=\$(pacman -Si linux 2>/dev/null | grep Version | awk '{print \$3}' | cut -d- -f1)
        [[ -z \"\${artix_kver}\" ]] && artix_kver=\$(uname -r | cut -d- -f1)
        
        git clone --depth 1 --branch \"v\${artix_kver}\" \
            https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux-custom 2>/dev/null || \
        git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux-custom
        
        cd linux-custom
        
        kver=\$(make kernelrelease 2>/dev/null || make kernelversion | grep -oP '\d+\.\d+')
        patch_dir=\"/tmp/linux-tkg/linux-tkg-patches/\${kver}\"
        failed_patches_file=\"/tmp/tkg-failed-patches.txt\"
        : > \"\${failed_patches_file}\"
        
        if [[ -d \"\${patch_dir}\" ]]; then
            for patch in \"\${patch_dir}\"/*.patch; do
                patch_name=\$(basename \"\$patch\")
                
                affected_files=\$(grep '^+++' \"\$patch\" 2>/dev/null | sed 's|^+++ [^/]*/||' || true)
                
                if patch -Np1 < \"\$patch\" 2>/dev/null; then
                    continue
                fi
                
                echo \"\${patch_name}\" >> \"\${failed_patches_file}\"
                echo \"Patch \${patch_name} failed — restoring ALL affected files\"
                
                for file in \${affected_files}; do
                    [[ -n \"\${file}\" ]] || continue
                    echo \"  Restoring \${file}\"
                    git checkout \"\${file}\" 2>/dev/null || rm -f \"\${file}\"
                done
            done
        fi
        
        make defconfig
        make -j\$(nproc)
        make modules_install
        make install
        
        mkinitcpio -P
        
        if [[ -d /boot/grub ]]; then
            grub-mkconfig -o /boot/grub/grub.cfg
        fi
        
        cp \"\${failed_patches_file}\" /tmp/tkg-failed-patches.txt 2>/dev/null || true
    "

    if [[ -f /mnt/tmp/tkg-failed-patches.txt ]]; then
        failed_patches=$(tr '\n' ' ' < /mnt/tmp/tkg-failed-patches.txt)
        rm -f /mnt/tmp/tkg-failed-patches.txt
    fi
    
    if ls /mnt/boot/vmlinuz-* &>/dev/null; then
        log_info "TKG kernel built and installed successfully."
        if [[ -n "${failed_patches}" ]]; then
            log_warn "The following TKG patches could not be applied: ${failed_patches}"
            log_warn "This is normal for newer kernels — the default kernel configuration was used for these components."
        fi
    else
        log_error "TKG kernel build failed."
        return 1
    fi
    
    rm -rf /tmp/linux-tkg /tmp/linux-custom
}

basestrap_build_bazzite() {
    log_info "Building linux-bazzite-bin from AUR..."

    local build_dir='/tmp/linux-bazzite-bin'
    rm -rf "${build_dir}"
    git clone 'https://aur.archlinux.org/linux-bazzite-bin.git' "${build_dir}" || {
        log_error "Failed to clone linux-bazzite-bin AUR repo."
        return 1
    }
    useradd -m builduser 2>/dev/null || true
    chown -R builduser:builduser "${build_dir}"
    su builduser -c "cd '${build_dir}' && makepkg -s --noconfirm --needed --skippgpcheck" &>/tmp/bazzite-build.log || {
        log_error "Failed to build linux-bazzite-bin."
        log_error "Last 20 lines of build log:"
        tail -20 /tmp/bazzite-build.log 2>/dev/null | while IFS= read -r line; do log_error "  ${line}"; done
        return 1
    }
    pacman -U --noconfirm "${build_dir}"/*.pkg.tar.* || {
        log_error "Failed to install linux-bazzite-bin package."
        return 1
    }
    local kver
    kver=$(ls -1 /usr/lib/modules/ | grep bazzite | sort -V | tail -1)
    if [[ -n "${kver}" && -f "/usr/lib/modules/${kver}/vmlinuz" ]]; then
        cp "/usr/lib/modules/${kver}/vmlinuz" "/mnt/boot/vmlinuz-linux-bazzite"
        cp -a "/usr/lib/modules/${kver}" /mnt/lib/modules/ 2>/dev/null || true
    fi
    rm -rf "${build_dir}"
    log_info "Bazzite kernel installed."
}