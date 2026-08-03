#!/usr/bin/env bash
set -Eeuo pipefail

tui_poweruser_config() {
    local cats_json
    cats_json=$(cat <<JSONEOF
[
  {"label":"Profile","items":[
    {"id":"POWERUSER_PROFILE","label":"Profile","value":"$(state_get POWERUSER_PROFILE default)","widget":"menu","choices":["default","safe","performance","hardened"],"display":"profile_preview"},
    {"id":"ARTIX_CFLAGS","label":"CFLAGS","value":"$(state_get ARTIX_CFLAGS '-march=native -O2 -pipe')","widget":"input"},
    {"id":"ARTIX_CXXFLAGS","label":"CXXFLAGS","value":"$(state_get ARTIX_CXXFLAGS '-march=native -O2 -pipe')","widget":"input"},
    {"id":"ARTIX_LDFLAGS","label":"LDFLAGS","value":"$(state_get ARTIX_LDFLAGS '')","widget":"input"},
    {"id":"ARTIX_MAKEFLAGS","label":"MAKEFLAGS","value":"$(state_get ARTIX_MAKEFLAGS '-j$(nproc)')","widget":"input"}
  ]},
  {"label":"Architecture","items":[
    {"id":"TARGET_ARCH","label":"Target Architecture","value":"$(state_get TARGET_ARCH x86_64)","widget":"menu","choices":["x86_64","aarch64"]},
    {"id":"BOARD_NAME","label":"Board","value":"$(state_get BOARD_NAME '')","widget":"menu","choices":["Raspberry Pi 4","Raspberry Pi 3B+","Odroid N2","Pinephone","Firefly RK3399","Orange Pi PC2","QEMU VM"],"visible_if":{"TARGET_ARCH":"aarch64"}}
  ]},
  {"label":"Init","items":[
    {"id":"INIT","label":"Init system","value":"$(state_get INIT openrc)","widget":"menu","choices":["openrc","runit","dinit","s6","busybox"]}
  ]},
  {"label":"Packages","items":[
    {"id":"POWERUSER_PACKAGES","label":"Source packages","value":"$(state_get POWERUSER_PACKAGES '')","widget":"checklist","choices_from":"list_recipes"}
  ]},
  {"label":"Coreutils","items":[
    {"id":"COREUTILS","label":"Implementation","value":"$(state_get COREUTILS gnu)","widget":"menu","choices":["gnu","busybox","uutils","artix","custom","none"]}
  ]},
  {"label":"Recipe Sources","items":[
    {"id":"RECIPE_SECTIONS","label":"Sections","value":"$(state_get RECIPE_SECTIONS 'OFFICIAL/Base')","widget":"recipe_sections"}
  ]},
  {"label":"Fallback","items":[
    {"id":"KEEP_BINARY_KERNEL","label":"Keep binary kernel","value":"$(state_get KEEP_BINARY_KERNEL yes)","widget":"yesno"}
  ]},
  {"label":"Custom Recipe","items":[
    {"id":"CUSTOM_RECIPE","label":"Create","value":"","widget":"menu","choices":["Create new recipe","Skip"]}
  ]},
  {"label":"Feature Flags","items":[
    {"id":"POWERUSER_FEATURES","label":"Per-package flags","value":"$(state_get POWERUSER_FEATURES '')","widget":"multiselect","display":"flag_list"}
  ]},
  {"label":"Kernel Config","items":[
    {"id":"KERNEL_CONFIG","label":"Hardware & tuning","value":"$(state_get KERNEL_CONFIG '')","widget":"kernel_config"}
  ]}
]
JSONEOF
)

    local result
    result=$(tui_poweruser "Power User Configuration" "${cats_json}") || return 1

    local key val
    while IFS= read -r key; do
        val=$(echo "${result}" | jq -r --arg k "${key}" '.[$k]')
        state_set "${key}" "${val}"
    done <<< "$(echo "${result}" | jq -r 'keys[]')"

    tui_poweruser_hw_summary
    tui_poweruser_pre_summary
}