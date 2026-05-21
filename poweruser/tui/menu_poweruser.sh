#!/usr/bin/env bash
set -Eeuo pipefail

tui_poweruser_select_profile() {
    local profile
    profile=$(tui_menu "Compilation Profile" "Choose optimization level:" \
        "default — balanced, safe optimizations" \
        "safe — conservative flags, maximum stability" \
        "performance — aggressive optimizations" \
        "hardened — security-focused flags") || return 1
    profile="${profile%% *}"
    state_set POWERUSER_PROFILE "${profile}"
    tui_poweruser_profile_preview "${profile}"
}

tui_poweruser_profile_preview() {
    local profile="${1}"
    local profile_file="${POWERUSER_DIR}/profile/${profile}.sh"
    source "${profile_file}"
    tui_msg "Profile: ${profile}" \
        "CFLAGS: ${ARTIX_CFLAGS}\nCXXFLAGS: ${ARTIX_CXXFLAGS}\nLDFLAGS: ${ARTIX_LDFLAGS}\nMAKEFLAGS: -j${ARTIX_MAKEFLAGS}"
}

tui_poweruser_tweak_profile() {
    if ! tui_yesno "Tweak Flags?" "Would you like to customize the compilation flags?"; then
        return 0
    fi

    local current_cflags="${ARTIX_CFLAGS}"
    local current_cxxflags="${ARTIX_CXXFLAGS}"
    local current_ldflags="${ARTIX_LDFLAGS}"
    local current_makeflags="${ARTIX_MAKEFLAGS}"

    local new_cflags new_cxxflags new_ldflags new_makeflags
    new_cflags=$(tui_input "CFLAGS" "Enter CFLAGS:" "${current_cflags}") || return 0
    new_cxxflags=$(tui_input "CXXFLAGS" "Enter CXXFLAGS:" "${current_cxxflags}") || return 0
    new_ldflags=$(tui_input "LDFLAGS" "Enter LDFLAGS:" "${current_ldflags}") || return 0
    new_makeflags=$(tui_input "MAKEFLAGS" "Enter MAKEOPTS (-j):" "${current_makeflags}") || return 0

    export ARTIX_CFLAGS="${new_cflags:-${current_cflags}}"
    export ARTIX_CXXFLAGS="${new_cxxflags:-${current_cxxflags}}"
    export ARTIX_LDFLAGS="${new_ldflags:-${current_ldflags}}"
    export ARTIX_MAKEFLAGS="${new_makeflags:-${current_makeflags}}"

    mkdir -p "${POWERUSER_DIR}/profile"
    cat > "${POWERUSER_DIR}/profile/custom.sh" <<EOF
#!/usr/bin/env bash
ARTIX_CFLAGS="${ARTIX_CFLAGS}"
ARTIX_CXXFLAGS="${ARTIX_CXXFLAGS}"
ARTIX_LDFLAGS="${ARTIX_LDFLAGS}"
ARTIX_MAKEFLAGS="${ARTIX_MAKEFLAGS}"
EOF

    state_set POWERUSER_PROFILE "custom"
    tui_msg "Flags Saved" "Custom flags saved as 'custom' profile."
}

tui_poweruser_select_packages() {
    local recipes=()
    while IFS=' — ' read -r name desc; do
        recipes+=("${name}")
    done < <(list_recipes)

    [[ ${#recipes[@]} -gt 0 ]] || {
        tui_msg "No Recipes" "No source recipes found."
        return 1
    }

    local selected
    selected=$(tui_checklist "Source Packages" "Select packages to build:" "${recipes[@]}") || return 1

    [[ -n "${selected//[[:space:]]/}" ]] || {
        tui_msg "No Selection" "No packages selected."
        return 1
    }

    state_set POWERUSER_PACKAGES "${selected//$'\n'/ }"

    if [[ " ${selected} " =~ " glibc " ]]; then
        tui_msg "WARNING: glibc Selected" "Building glibc from source is DANGEROUS.\n\nA miscompiled glibc will make your system unbootable.\nKeep the binary package as a fallback.\n\nProceed only if you understand the risks."
    fi
}

tui_poweruser_kernel_depth() {
    local depth
    depth=$(tui_menu "Kernel Configuration" "How much control do you want?" \
        "Auto-detection – hardware pre-filled, review & adjust" \
        "Manual – blank checklist, pick everything yourself" \
        "menuconfig – full ncurses kernel editor") || return 1
    case "${depth}" in
        Auto*)   state_set KERNEL_CONFIG_DEPTH "auto" ;;
        Manual*) state_set KERNEL_CONFIG_DEPTH "manual" ;;
        menuconfig*) state_set KERNEL_CONFIG_DEPTH "menuconfig" ;;
    esac
}

tui_poweruser_kernel_config() {
    local mode="${1:-auto}"
    source "${POWERUSER_DIR}/lib/hwdetect.bash"
    local cpu gpu net storage
    cpu=$(detect_cpu)
    gpu=$(detect_gpu)
    net=$(detect_net)
    storage=$(detect_storage)

    local gpu_choices
    if [[ "${mode}" == "auto" ]]; then
        local gpu_defaults=()
        case "${gpu}" in
            INTEL)   gpu_defaults=("intel (i915)") ;;
            AMD)     gpu_defaults=("amd (amdgpu)") ;;
            NVIDIA)  gpu_defaults=("nvidia (nouveau)") ;;
            VIRTIO)  gpu_defaults=("virtio (virtio-gpu)") ;;
            *)       gpu_defaults=("vesa (basic)") ;;
        esac
        gpu_choices=$(tui_checklist "GPU Drivers" "Select GPU support:" \
            --selected="${gpu_defaults[*]}" \
            "intel (i915)" "amd (amdgpu)" "nvidia (nouveau)" \
            "virtio (virtio-gpu)" "vesa (basic)" "simpledrm (simple framebuffer)") || true
    else
        gpu_choices=$(tui_checklist "GPU Drivers" "Select GPU support:" \
            "intel (i915)" "amd (amdgpu)" "nvidia (nouveau)" \
            "virtio (virtio-gpu)" "vesa (basic)" "simpledrm (simple framebuffer)") || true
    fi
    state_set KERNEL_ADV_GPU "$(echo "${gpu_choices}" | sed 's/ .*//')"

    local net_choices
    if [[ "${mode}" == "auto" ]]; then
        local net_defaults=()
        for n in ${net}; do
            case "${n}" in
                INTEL)   net_defaults+=("intel (e1000/e1000e)") ;;
                REALTEK) net_defaults+=("realtek (r8169)") ;;
                BROADCOM) net_defaults+=("broadcom (tg3/bnx2)") ;;
                ATHEROS) net_defaults+=("atheros (atl1)") ;;
                VIRTIO)  net_defaults+=("virtio (virtio-net)") ;;
            esac
        done
        net_choices=$(tui_checklist "Network" "Select network drivers:" \
            --selected="${net_defaults[*]}" \
            "intel (e1000/e1000e)" "realtek (r8169)" "broadcom (tg3/bnx2)" \
            "atheros (atl1)" "virtio (virtio-net)" \
            "intel-wifi (iwlwifi)" "ath-wifi (ath9k/10k)" \
            "realtek-wifi (rtl8xxxu)" "bt (Bluetooth)") || true
    else
        net_choices=$(tui_checklist "Network" "Select network drivers:" \
            "intel (e1000/e1000e)" "realtek (r8169)" "broadcom (tg3/bnx2)" \
            "atheros (atl1)" "virtio (virtio-net)" \
            "intel-wifi (iwlwifi)" "ath-wifi (ath9k/10k)" \
            "realtek-wifi (rtl8xxxu)" "bt (Bluetooth)") || true
    fi
    state_set KERNEL_ADV_NET "$(echo "${net_choices}" | sed 's/ .*//')"

    local fs_choices
    if [[ "${mode}" == "auto" ]]; then
        local fs_defaults=("ext4 (built-in)")
        local fs_type
        fs_type="$(state_get FS_TYPE ext4)"
        case "${fs_type}" in
            btrfs) fs_defaults+=("btrfs (built-in)") ;;
            xfs)   fs_defaults+=("xfs (built-in)") ;;
            f2fs)  fs_defaults+=("f2fs (module)") ;;
            exfat) fs_defaults+=("exfat (module)") ;;
        esac
        fs_choices=$(tui_checklist "Filesystems" "Select filesystem support:" \
            --selected="${fs_defaults[*]}" \
            "ext4 (built-in)" "btrfs (built-in)" "xfs (built-in)" \
            "f2fs (module)" "exfat (module)" "ntfs3 (module)" "overlay (module)") || true
    else
        fs_choices=$(tui_checklist "Filesystems" "Select filesystem support:" \
            "ext4 (built-in)" "btrfs (built-in)" "xfs (built-in)" \
            "f2fs (module)" "exfat (module)" "ntfs3 (module)" "overlay (module)") || true
    fi
    state_set KERNEL_ADV_FS "$(echo "${fs_choices}" | sed 's/ .*//')"

    local snd_choices
    snd_choices=$(tui_checklist "Sound" "Select audio support:" \
        "intel-hda (Intel HDA)" "amd-hda (AMD HDA)" "usb-audio (USB audio)") || true
    state_set KERNEL_ADV_SOUND "$(echo "${snd_choices}" | sed 's/ .*//')"

    local usb_choices
    if [[ "${mode}" == "auto" ]]; then
        usb_choices=$(tui_checklist "USB Support" "Select USB options:" \
            --selected="hid (USB HID)" \
            "storage (usb-storage)" "hid (USB HID)" "serial (USB serial)") || true
    else
        usb_choices=$(tui_checklist "USB Support" "Select USB options:" \
            "storage (usb-storage)" "hid (USB HID)" "serial (USB serial)") || true
    fi
    state_set KERNEL_ADV_USB "$(echo "${usb_choices}" | sed 's/ .*//')"

    local sec_choices
    sec_choices=$(tui_checklist "Security" "Select security features:" \
        "selinux" "apparmor" "lockdown") || true
    state_set KERNEL_ADV_SECURITY "$(echo "${sec_choices}" | sed 's/ .*//')"

    local virt_choices
    if [[ "${mode}" == "auto" ]]; then
        local virt_defaults=()
        if [[ "${gpu}" == "VIRTIO" || "${net}" =~ "VIRTIO" || "${storage}" == "VIRTIO" ]]; then
            virt_defaults=("kvm (KVM)")
        fi
        virt_choices=$(tui_checklist "Virtualization" "Select virtualization support:" \
            --selected="${virt_defaults[*]}" \
            "kvm (KVM)" "vhost (vhost-net)") || true
    else
        virt_choices=$(tui_checklist "Virtualization" "Select virtualization support:" \
            "kvm (KVM)" "vhost (vhost-net)") || true
    fi
    state_set KERNEL_ADV_VIRT "$(echo "${virt_choices}" | sed 's/ .*//')"

    local dbg_choices
    dbg_choices=$(tui_checklist "Debug & Tracing" "Select debugging features:" \
        "ftrace" "perf" "kprobes" "ebpf") || true
    state_set KERNEL_ADV_DEBUG "$(echo "${dbg_choices}" | sed 's/ .*//')"

    local preempt
    preempt=$(tui_menu "Preemption Model" "Select preemption model:" \
        "voluntary (Desktop)" "full (Low-Latency Desktop)" "rt (Real-Time)") || true
    case "${preempt}" in
        voluntary*) state_set KERNEL_PREEMPT "voluntary" ;;
        full*)      state_set KERNEL_PREEMPT "full" ;;
        rt*)        state_set KERNEL_PREEMPT "rt" ;;
    esac

    local timer
    timer=$(tui_menu "Timer Frequency" "Select kernel timer frequency (Hz):" \
        "100" "250" "300" "1000") || true
    state_set KERNEL_TIMER "${timer}"

    local gov
    gov=$(tui_menu "CPU Governor" "Select default CPU frequency governor:" \
        "schedutil" "ondemand" "performance") || true
    state_set KERNEL_GOVERNOR "${gov}"
}

tui_poweruser_feature_flags() {
    local -a pkgs
    read -ra pkgs <<< "$(state_get POWERUSER_PACKAGES)"
    for pkg in "${pkgs[@]}"; do
        local recipe_file="${POWERUSER_DIR}/recipes/${pkg}.sh"
        [[ -f "${recipe_file}" ]] || continue
        local -a flags=()
        source "${recipe_file}" 2>/dev/null || true
        if [[ "$(declare -p feature_flags 2>/dev/null)" =~ "declare -a" ]]; then
            flags=("${feature_flags[@]}")
        fi
        if [[ ${#flags[@]} -gt 0 ]]; then
            local chosen
            chosen=$(tui_checklist "${pkg} — Feature Flags" "Select features:" "${flags[@]}") || true
            if [[ -n "${chosen}" ]]; then
                state_set "POWERUSER_FEATURES_${pkg//-/_}" "${chosen//$'\n'/ }"
            else
                state_set "POWERUSER_FEATURES_${pkg//-/_}" ""
            fi
        fi

        if [[ "${pkg}" == "linux" ]]; then
            tui_poweruser_kernel_depth
            local depth
            depth="$(state_get KERNEL_CONFIG_DEPTH auto)"
            if [[ "${depth}" == "auto" ]]; then
                tui_poweruser_kernel_config "auto"
                if tui_yesno "Fine-Tune?" "Review the full blank checklist?"; then
                    tui_poweruser_kernel_config "manual"
                fi
                if tui_yesno "menuconfig?" "Drop into make menuconfig?"; then
                    state_set KERNEL_CONFIG_DEPTH "menuconfig"
                fi
            elif [[ "${depth}" == "manual" ]]; then
                tui_poweruser_kernel_config "manual"
                if tui_yesno "menuconfig?" "Drop into make menuconfig?"; then
                    state_set KERNEL_CONFIG_DEPTH "menuconfig"
                fi
            fi
        fi
    done
}

tui_poweruser_hw_summary() {
    source "${POWERUSER_DIR}/lib/hwdetect.bash"
    local cpu gpu net storage
    cpu=$(detect_cpu)
    gpu=$(detect_gpu)
    net=$(detect_net)
    storage=$(detect_storage)
    tui_msg "Hardware Detected" \
        "CPU: ${cpu}\nGPU: ${gpu}\nNetwork: ${net}\nStorage: ${storage}"
}

tui_poweruser_create_recipe() {
    if ! tui_yesno "Create Recipe" "Would you like to create a new recipe?"; then
        return 0
    fi

    local name version url desc dependencies
    name=$(tui_input "Recipe Name" "Package name:") || return 1
    version=$(tui_input "Version" "e.g. 1.0:") || return 1
    url=$(tui_input "Source URL" "Tarball URL:") || return 1
    desc=$(tui_input "Description" "Short description:") || true
    dependencies=$(tui_input "Dependencies" "Space-separated list:") || true

    local recipe_file="${POWERUSER_DIR}/recipes/${name}.sh"
    cat > "${recipe_file}" <<EOF
#!/usr/bin/env bash
pkgname=${name}
pkgver=${version}
pkgrel=1
desc="${desc}"
url="${url}"

sources=(
  "${url}|SKIP|${name}-\${pkgver}.tar.gz"
)

depends=(${dependencies})
makedepends=(base-devel)

prepare() {
  cd "\${BUILD_DIR}"
  tar xf "\${SOURCES_DIR}/${name}-\${pkgver}.tar.gz"
  mv "${name}-\${pkgver}" src
}

configure() {
  cd "\${BUILD_DIR}/src"
  ./configure --prefix=/usr
}

build() {
  cd "\${BUILD_DIR}/src"
  make -j\${ARTIX_MAKEFLAGS}
}

package() {
  cd "\${BUILD_DIR}/src"
  make DESTDIR="\${PKG_DESTDIR}" install
}
EOF
    tui_msg "Recipe Created" "Saved to ${recipe_file}."
}

tui_poweruser_pre_summary() {
    local summary=""
    summary+="Profile: $(state_get POWERUSER_PROFILE default)"$'\n'
    summary+="Packages:"$'\n'
    local -a pkgs
    read -ra pkgs <<< "$(state_get POWERUSER_PACKAGES)"
    for pkg in "${pkgs[@]}"; do
        local features
        features="$(state_get "POWERUSER_FEATURES_${pkg//-/_}" "")"
        if [[ -n "${features}" ]]; then
            summary+="  ${pkg} [${features}]"$'\n'
        else
            summary+="  ${pkg}"$'\n'
        fi
    done
    tui_msg "Power User Build Summary" "${summary}"
}

tui_poweruser_config() {
    tui_poweruser_select_profile || return 1
    tui_poweruser_tweak_profile
    tui_poweruser_select_packages || {
        state_set POWER_USER "no"
        return 1
    }
    tui_poweruser_create_recipe
    tui_poweruser_feature_flags
    tui_poweruser_hw_summary
    tui_poweruser_pre_summary
}