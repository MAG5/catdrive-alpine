KERNEL := https://github.com/9abc/catdrive/releases/download
RELEASE_TAG = Kernel
DTB := armada-3720-catdrive.dtb

DTB_URL := $(KERNEL)/$(RELEASE_TAG)/$(DTB)
KERNEL_URL := $(KERNEL)/$(RELEASE_TAG)/Image
KMOD_URL := $(KERNEL)/$(RELEASE_TAG)/modules.tar.xz

QEMU_URL := https://github.com/multiarch/qemu-user-static/releases/download
QEMU_TAG = v7.1.0-2
QEMU := x86_64_qemu-aarch64-static

TARGETS := debian archlinux alpine ubuntu

DL := dl
DL_KERNEL := $(DL)/kernel/$(RELEASE_TAG)
DL_QEMU := $(DL)/qemu
OUTPUT := output

CURL := curl -O -L
download = ( mkdir -p $(1) && cd $(1) ; $(CURL) $(2) )

help:
	@echo "Usage: make build_[system1]=y build_[system2]=y build"
	@echo "available system: $(TARGETS)"

build: $(TARGETS)

clean: $(TARGETS:%=%_clean)
	rm -f $(RESCUE_ROOTFS)

dl_qemu: $(DL_QEMU)

$(DL_QEMU):
	$(call download,$(DL_QEMU),$(QEMU_URL)/$(QEMU_TAG)/$(QEMU).tar.gz)
	mkdir -p tools/qemu; tar xf $(DL_QEMU)/$(QEMU).tar.gz -C tools/qemu/

dl_kernel: $(DL_KERNEL)/$(DTB) $(DL_KERNEL)/Image $(DL_KERNEL)/modules.tar.xz dl_qemu

$(DL_KERNEL)/$(DTB):
	$(call download,$(DL_KERNEL),$(DTB_URL))

$(DL_KERNEL)/Image:
	$(call download,$(DL_KERNEL),$(KERNEL_URL))

$(DL_KERNEL)/modules.tar.xz:
	$(call download,$(DL_KERNEL),$(KMOD_URL))

ALPINE_BRANCH := v3.17
ALPINE_VERSION := 3.17.0
ALPINE_PKG := alpine-minirootfs-$(ALPINE_VERSION)-aarch64.tar.gz
RESCUE_ROOTFS := tools/rescue/rescue-alpine-catdrive-$(ALPINE_VERSION)-aarch64.tar.xz
ALPINE_URL_BASE := http://dl-cdn.alpinelinux.org/alpine/$(ALPINE_BRANCH)/releases/aarch64

alpine_dl: dl_kernel $(DL)/$(ALPINE_PKG)

$(DL)/$(ALPINE_PKG):
	$(call download,$(DL),$(ALPINE_URL_BASE)/$(ALPINE_PKG))

alpine_clean:

$(RESCUE_ROOTFS):
	@[ ! -f $(RESCUE_ROOTFS) ] && make rescue

rescue: alpine_dl
	sudo BUILD_RESCUE=y ./build-alpine.sh release $(DL)/$(ALPINE_PKG) $(DL_KERNEL) -

ifeq ($(build_alpine),y)
alpine: alpine_dl $(RESCUE_ROOTFS)
	sudo ./build-alpine.sh release $(DL)/$(ALPINE_PKG) $(DL_KERNEL) $(RESCUE_ROOTFS)
else
alpine:
endif


ARCHLINUX_PKG := ArchLinuxARM-aarch64-latest.tar.gz
ARCHLINUX_URL_BASE := http://os.archlinuxarm.org/os

archlinux_dl: dl_kernel $(DL)/$(ARCHLINUX_PKG)

$(DL)/$(ARCHLINUX_PKG):
	$(call download,$(DL),$(ARCHLINUX_URL_BASE)/$(ARCHLINUX_PKG))

archlinux_clean:
	rm -f $(DL)/$(ARCHLINUX_PKG)

ifeq ($(build_archlinux),y)
archlinux: archlinux_dl $(RESCUE_ROOTFS)
	sudo ./build-archlinux.sh release $(DL)/$(ARCHLINUX_PKG) $(DL_KERNEL) $(RESCUE_ROOTFS)
else
archlinux:
endif

UBUNTU_PKG := ubuntu-base-22.04.1-base-arm64.tar.gz
UBUNTU_URL_BASE := http://cdimage.ubuntu.com/ubuntu-base/releases/jammy/release

ubuntu_dl: dl_kernel $(DL)/$(UBUNTU_PKG)

$(DL)/$(UBUNTU_PKG):
	$(call download,$(DL),$(UBUNTU_URL_BASE)/$(UBUNTU_PKG))

ubuntu_clean:

ifeq ($(build_ubuntu),y)
ubuntu: ubuntu_dl $(RESCUE_ROOTFS)
	sudo ./build-ubuntu.sh release $(DL)/$(UBUNTU_PKG) $(DL_KERNEL) $(RESCUE_ROOTFS)
else
ubuntu:
endif

ifeq ($(build_debian),y)
debian: dl_kernel $(RESCUE_ROOTFS)
	sudo ./build-debian.sh release - $(DL_KERNEL) $(RESCUE_ROOTFS)

else
debian:
endif
debian_clean:
