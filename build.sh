#!/bin/bash

[ "$EUID" != "0" ] && echo "please run as root" && exit 1

set -e
set -o pipefail

os="alpine"
rootsize=1000
origin="minirootfs"
target="catdrive"

tmpdir="tmp"
output="output"
rootfs_mount_point="/mnt/${os}_rootfs"
qemu_static="./tools/qemu/qemu-aarch64-static"

cur_dir=$(pwd)
DTB=armada-3720-catdrive.dtb

add_services() {
	if [ "$BUILD_RESCUE" != "y" ]; then
		echo "add resize mmc script"
		cp ./tools/${os}/resizemmc.sh $rootfs_mount_point/sbin/resizemmc.sh
		cp ./tools/${os}/resizemmc $rootfs_mount_point/etc/init.d/resizemmc
		ln -sf /etc/init.d/resizemmc $rootfs_mount_point/etc/runlevels/default/resizemmc
		touch $rootfs_mount_point/root/.need_resize
	fi
}

gen_new_name() {
	local rootfs=$1
	echo "`basename $rootfs | sed "s/${origin}/${target}/" | sed 's/.tar.gz$//'`"
}


DISK="rootfs.img"

func_generate() {
	local rootfs=$1
	local kdir=$2

	[ "$os" != "debian" ] && [ ! -f "$rootfs" ] && echo "${os} rootfs file not found!" && return 1
	[ ! -d "$kdir" ] && echo "kernel dir not found!" && return 1

	# create rootfs mbr img
	mkdir -p ${tmpdir}
	echo "create mbr rootfs, size: ${rootsize}M"
	dd if=/dev/zero bs=1M status=none conv=fsync count=$rootsize of=$tmpdir/$DISK
	parted -s $tmpdir/$DISK -- mktable msdos
	parted -s $tmpdir/$DISK -- mkpart p ext4 8192s -1s

	# get PTUUID
	eval `blkid -o export -s PTUUID $tmpdir/$DISK`

	# mkfs.ext4
	echo "mount loopdev to format ext4 rootfs"
	modprobe loop
	lodev=$(losetup -f)
	losetup -P $lodev $tmpdir/$DISK
	mkfs.ext4 -q -m 2 ${lodev}"p1"

	# mount rootfs
	echo "mount rootfs"
	mkdir -p $rootfs_mount_point
	mount  ${lodev}"p1" $rootfs_mount_point

	# extract rootfs
	if [ "$os" = "debian" ]; then
		generate_rootfs $rootfs_mount_point
	else
		echo "extract ${os} rootfs($rootfs) to $rootfs_mount_point"
		if [ "$os" = "archlinux" ]; then
			tarbin="bsdtar"
		else
			tarbin="tar"
		fi
		$tarbin -xpf $rootfs -C $rootfs_mount_point
	fi

	# configure binfmt
	echo "configure binfmt to chroot"
	modprobe binfmt_misc
	if [ -e /proc/sys/fs/binfmt_misc/register ]; then
		echo -1 > /proc/sys/fs/binfmt_misc/status
		echo ":arm64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:OC" > /proc/sys/fs/binfmt_misc/register
		echo "copy $qemu_static to $rootfs_mount_point/usr/bin/"
		cp $qemu_static $rootfs_mount_point/usr/bin/qemu-aarch64-static
	else
		echo "Could not configure binfmt for qemu!" && exit 1
	fi

	cp ./tools/${os}/init.sh $rootfs_mount_point/init.sh

	# prepare for chroot
	echo "nameserver 8.8.8.8" > $rootfs_mount_point/etc/resolv.conf

	# chroot
	echo "chroot to ${os} rootfs"
	LANG=C LC_ALL=C chroot $rootfs_mount_point /init.sh

	# clean rootfs
	rm -f $rootfs_mount_point/init.sh
	[ -n "$qemu" ] && rm -f $rootfs_mount_point/$qemu || rm -f $rootfs_mount_point/usr/bin/qemu-aarch64-static

	# add services
	add_services

	# add /boot
	echo "add /boot"
	mkdir -p $rootfs_mount_point/boot
	cp -f $kdir/Image $rootfs_mount_point/boot
	cp -f $kdir/$DTB $rootfs_mount_point/boot
	cp -f ./tools/boot/uEnv.txt $rootfs_mount_point/boot
	echo "rootdev=PARTUUID=${PTUUID}-01" >> $rootfs_mount_point/boot/uEnv.txt
	cp -f ./tools/boot/boot.cmd $rootfs_mount_point/boot
	mkimage -C none -A arm -T script -d $rootfs_mount_point/boot/boot.cmd $rootfs_mount_point/boot/boot.scr

	# add /lib/modules
	echo "add /lib/modules"
	tar --no-same-owner -xf $kdir/modules.tar.xz --strip-components 1 -C $rootfs_mount_point/lib

	umount -l $rootfs_mount_point
	losetup -d $lodev

	echo "generate ${os} rootfs done"

}

case "$1" in
generate)
	func_generate "$2" "$3"
	;;
*)
	echo "Usage: $0 { generate [rootfs] [KDIR] | release [rootfs] [KDIR] [RESCUE_ROOTFS] }"
	exit 1
	;;
esac
