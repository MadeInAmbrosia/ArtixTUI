#!/usr/bin/env bash

# Raspberry Pi 4 cross-compilation profile
# Target: Broadcom BCM2711 (Cortex-A72)
# Requires: cross-aarch64 base profile sourced first

ARTIX_CFLAGS="-O2 -march=armv8-a+crc -mtune=cortex-a72 -pipe"
ARTIX_CXXFLAGS="${ARTIX_CFLAGS}"

BOARD_NAME="raspberry-pi-4"
BOARD_KERNEL_DEFCONFIG="bcm2711_defconfig"
BOARD_DEVICE_TREE="broadcom/bcm2711-rpi-4-b.dtb"
BOOTLOADER="uboot"
UBOOT_TARGET="rpi_4_defconfig"