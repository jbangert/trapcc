#!/bin/bash
 
# This script can be used to quickly test MultiBoot-compliant
# kernels.
 
# ---- begin config params ----
 
harddisk_image_size=$((4*1024*1024)) # 4 megabytes
harddisk_image="harddisk.img"
qemu_cmdline="qemu -monitor stdio"
kernel_args=""
kernel_binary="kernel.bin"
 
# ----  end config params  ----
 
 
function fail() { echo "$1"; exit 1; }
function prereq() {
	local c x
	if [ "$1" = "f" ]; then c=stat;x=file; else c=which;x=program; fi
	if [ -z "$3" ]; then
		$c "$2" >/dev/null || fail "$x $2 not found"
	else
		$c "$2" >/dev/null || fail "$x $2 (from package $3) not found"
	fi
}
 
# check prerequisites
prereq x mkfs.vfat dosfstools
prereq x mcopy mtools
prereq x syslinux
prereq f /usr/lib/syslinux/mboot.c32 syslinux
 
 
# create image
dd if=/dev/zero of="$harddisk_image" bs=4k count=$((harddisk_image_size/4096)) 2>/dev/null
 
# format image
mkfs.vfat "$harddisk_image" || fail "could not format harddisk.img"
 
# install syslinux
syslinux "$harddisk_image" || fail "could not install syslinux"
 
# copy over mboot.c32 (required for Multiboot)
mcopy -i "$harddisk_image" /usr/lib/syslinux/mboot.c32 ::mboot.c32 || fail "could not copy over mboot.c32"
 
# copy over kernel
mcopy -i "$harddisk_image" "$kernel_binary" ::kernel.bin || fail "could not copy over kernel"
 
# create syslinux.cfg
echo '
TIMEOUT 1
DEFAULT mboot.c32 kernel.bin '$kernel_args'
' | mcopy -i "$harddisk_image" - ::syslinux.cfg
 