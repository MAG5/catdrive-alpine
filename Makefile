KERNEL := https://github.com/9abc/catdrive/releases/download
RELEASE_TAG = Kernel
DTB := armada-3720-catdrive.dtb

DTB_URL := $(KERNEL)/$(RELEASE_TAG)/$(DTB)
KERNEL_URL := $(KERNEL)/$(RELEASE_TAG)/Image
KMOD_URL := $(KERNEL)/$(RELEASE_TAG)/modules.tar.xz

QEMU_URL := https://github.com/multiarch/qemu-user-static/releases/download
QEMU_TAG = v7.1.0-2
QEMU := x86_64_qemu-aarch64-static

TARGETS := alpine

DL := dl
DL_KERNEL := $(DL)/kernel/$(RELEASE_TAG)
DL_QEMU := $(DL)/qemu

CURL := curl -O -L
download = ( mkdir -p $(1) && cd $(1) ; $(CURL) $(2) )

help:
	@echo "Usage: make build_[system1]=y build_[system2]=y build"
	@echo "available system: $(TARGETS)"

build: $(TARGETS)

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
ALPINE_VERSION := 3.17.10
ALPINE_PKG := alpine-minirootfs-$(ALPINE_VERSION)-aarch64.tar.gz
ALPINE_URL_BASE := http://dl-cdn.alpinelinux.org/alpine/$(ALPINE_BRANCH)/releases/aarch64

alpine_dl: dl_kernel $(DL)/$(ALPINE_PKG)

$(DL)/$(ALPINE_PKG):
	$(call download,$(DL),$(ALPINE_URL_BASE)/$(ALPINE_PKG))

alpine_clean:

ifeq ($(build_alpine),y)
alpine: alpine_dl
	sudo ./build.sh generate $(DL)/$(ALPINE_PKG) $(DL_KERNEL)
else
alpine:
endif
