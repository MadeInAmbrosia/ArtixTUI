#!/usr/bin/env bash
set -Eeuo pipefail

tui_show_summary() {
    local title_colour
    title_colour=$(theme_ansi_code "${GUM_TITLE_COLOR}")
    local summary
    printf -v summary \
"\e[1;${title_colour}mDisk:\e[0m       %s
\e[1;${title_colour}mHostname:\e[0m   %s
\e[1;${title_colour}mTimezone:\e[0m   %s
\e[1;${title_colour}mLocale:\e[0m     %s
\e[1;${title_colour}mKeyboard:\e[0m   %s
\e[1;${title_colour}mMicrocode:\e[0m  %s
\e[1;${title_colour}mBTRFS:\e[0m      %s
\e[1;${title_colour}mFilesystem:\e[0m %s
\e[1;${title_colour}mLVM:\e[0m        %s
\e[1;${title_colour}mInit:\e[0m       %s
\e[1;${title_colour}mBootloader:\e[0m %s
\e[1;${title_colour}mUKI:\e[0m        %s
\e[1;${title_colour}mKernel:\e[0m     %s
\e[1;${title_colour}mPriv Esc:\e[0m   %s
\e[1;${title_colour}mPower User:\e[0m %s
\e[1;${title_colour}mDesktop:\e[0m    %s
\e[1;${title_colour}mNetwork:\e[0m    %s
\e[1;${title_colour}mX Stack:\e[0m    %s
\e[1;${title_colour}mLUKS:\e[0m       %s
\e[1;${title_colour}mArch Repos:\e[0m %s" \
        "$(state_get DISK)" \
        "$(state_get HOSTNAME artix)" \
        "$(state_get TIMEZONE Europe/Belgrade)" \
        "$(state_get LOCALE en_US.UTF-8)" \
        "$(state_get KEYMAP us)" \
        "$(state_get MICROCODE_OVERRIDE auto)" \
        "$(state_get BTRFS_LAYOUT standard)" \
        "$(state_get FS_TYPE ext4)" \
        "$(state_get USE_LVM no)" \
        "$(state_get INIT openrc)" \
        "$(state_get BOOTLOADER grub)" \
        "$(state_get GENERATE_UKI no)" \
        "$(state_get KERNEL_CHOICE linux)" \
        "$(state_get PRIV_ESCALATION sudo)" \
        "$(state_get POWER_USER no)" \
        "$(state_get WM_DE none)" \
        "$(state_get NETWORK_STACK dhcpcd+iwd)" \
        "$(state_get X_STACK xorg)" \
        "$(state_get USE_LUKS no)" \
        "$(state_get ENABLE_ARCH_REPOS no)"

    tui_msg "Installation Summary" "${summary}"

    if ! tui_yesno "Proceed?" "Proceed with installation?"; then
        exit 0
    fi

    if [[ -n "${FORGE_TUI_DAEMON:-}" ]]; then
        unset FORGE_TUI_DAEMON
        [[ -S "${FORGE_TUI_SOCKET}" ]] && printf '{"widget":"quit"}\n' | nc -U "${FORGE_TUI_SOCKET}" 2>/dev/null
        rm -f "${FORGE_TUI_SOCKET}"
    fi

    trap 'if [[ -n "${FORGE_TUI_DAEMON:-}" && -S "${FORGE_TUI_SOCKET}" ]]; then printf "{\"widget\":\"quit\"}\n" | nc -U "${FORGE_TUI_SOCKET}" 2>/dev/null; rm -f "${FORGE_TUI_SOCKET}"; fi' EXIT
}