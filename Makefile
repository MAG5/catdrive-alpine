DIST := build
$(shell mkdir -p $(DIST))

MAKE_ARCH := make -C linux -j$(shell grep ^processor /proc/cpuinfo | wc -l) CC="ccache aarch64-linux-gnu-gcc" CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64
KVER := $(shell make -C linux -s kernelversion)

# ccache gcc-aarch64-linux-gnu
$(DIST)/Image:
	$(MAKE_ARCH) Image
	cp -f linux/arch/arm64/boot/Image $(DIST)

$(DIST)/armada-3720-catdrive.dtb:
	$(MAKE_ARCH) marvell/armada-3720-catdrive.dtb
	cp -f linux/arch/arm64/boot/dts/marvell/armada-3720-catdrive.dtb $(DIST)

$(DIST)/lib/modules:
	rm -rf $(DIST)/modules
	$(MAKE_ARCH) modules
	$(MAKE_ARCH) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(CURDIR)/$(DIST) modules_install
	rm -f $(DIST)/lib/modules/$(KVER)/build $(DIST)/lib/modules/$(KVER)/source

TEMP_DIR_APKS := $(shell mktemp -d)
$(DIST)/apks.tar:
	curl -L https://dl-cdn.alpinelinux.org/v3.21/releases/aarch64/alpine-rpi-3.21.3-aarch64.tar.gz | tar -xz -C $(TEMP_DIR_APKS) ./apks/
	tar -cJf $(DIST)/apks.tar $(TEMP_DIR_APKS)/apks

$(DIST)/rootfs:
	mkdir -p $(DIST)/rootfs
	curl -L https://dl-cdn.alpinelinux.org/v3.21/releases/aarch64/alpine-minirootfs-3.21.0-aarch64.tar.gz | tar -xz -C $(DIST)/rootfs

# binfmt-support qemu-user-static
$(DIST)/initramfs-generic: $(DIST)/rootfs
	sudo update-binfmts --enable qemu-aarch64
	echo "nameserver 8.8.8.8" > $(DIST)/rootfs/etc/resolv.conf
	mkdir -p $(DIST)/rootfs/boot
	sudo mount --bind $(DIST) $(DIST)/rootfs/boot
	sudo LANG=C LC_ALL=C chroot $(DIST)/rootfs ash -c "\
	apk add mkinitfs; \
	mkinitfs -n # -n: no modules \
	"
	sudo umount $(DIST)/rootfs/boot
	sudo chmod +r $(DIST)/initramfs-generic

# squashfs-tools
$(DIST)/modloop: $(DIST)/lib/modules
	mksquashfs $(DIST)/lib/modules/${KVER} $(DIST)/modloop -comp xz

all: $(DIST)/Image $(DIST)/armada-3720-catdrive.dtb $(DIST)/modloop $(DIST)/initramfs-generic $(DIST)/apks.tar
# TODO alpine-catdrive-3.21.3-kernel-$(KVER)-aarch64.img

