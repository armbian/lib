# DO NOT EDIT THIS FILE
#
# Please edit /boot/armbianEnv.txt to set supported parameters
#

setenv load_addr "0x300000"
# default values
setenv rootdev "/dev/mmcblk0p1"
setenv rootfstype "ext4"
setenv verbosity "1"
setenv emmc_fix "off"
setenv ethaddr "00:50:43:84:fb:2f"
setenv eth1addr "00:50:43:25:fb:84"
setenv eth2addr "00:50:43:84:25:2f"
setenv eth3addr "00:50:43:0d:19:18"

echo "Boot script loaded from ${devtype}"

if load ${devtype} ${devnum} ${load_addr} ${prefix}armbianEnv.txt; then
	env import -t ${load_addr} ${filesize}
fi

setenv bootargs "console=ttyS0,115200 root=${rootdev} rootwait rootfstype=${rootfstype} ubootdev=${devtype} scandelay loglevel=${verbosity} usb-storage.quirks=${usbstoragequirks} ${extraargs}"

load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}zImage

fdt addr ${fdt_addr_r}
fdt resize 65536
for overlay_file in ${overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/overlay/${overlay_prefix}-${overlay_file}.dtbo; then
		echo "Applying kernel provided DT overlay ${overlay_prefix}-${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done
for overlay_file in ${user_overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}overlay-user/${overlay_file}.dtbo; then
		echo "Applying user provided DT overlay ${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done
if test "${overlay_error}" = "true"; then
	echo "Error applying DT overlays, restoring original DT"
	load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/rockchip/${fdtfile}
else
	if test -e ${devtype} ${devnum} ${prefix}dtb/overlay/${overlay_prefix}-fixup.scr; then
		load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/overlay/${overlay_prefix}-fixup.scr
		echo "Applying kernel provided DT fixup script (${overlay_prefix}-fixup.scr)"
		source ${load_addr}
	fi
	if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
		load ${devtype} ${devnum} ${load_addr} ${prefix}fixup.scr
		echo "Applying user provided fixup script (fixup.scr)"
		source ${load_addr}
	fi
fi

# eMMC fix
if test "${emmc_fix}" = "on"; then
	echo "Applying eMMC compatibility fix to the DT"
	fdt rm /soc/internal-regs/sdhci@d8000/ cd-gpios
	fdt set /soc/internal-regs/sdhci@d8000/ non-removable
fi

# SPI - SATA workaround
if test "${spi_workaround}" = "on"; then
	echo "Applying SPI workaround to the DT"
	fdt addr ${fdt_addr}
	fdt resize
	fdt set /soc/internal-regs/sata@e0000 status "disabled"
	fdt set /soc/internal-regs/sata@a8000 status "disabled"
	fdt set /soc/spi@10680 status "okay"
	fdt set /soc/spi@10680/spi-flash@0 status "okay"
fi

bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
