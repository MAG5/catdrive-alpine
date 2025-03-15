LOCATION := $(shell pwd)
STAGE := $(LOCATION)/stage
OUTPUT := $(LOCATION)/output

TC := gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu
TCURL := https://developer.arm.com/-/media/Files/downloads/gnu/11.2-2022.02/binrel/$(TC).tar.xz

KERNEL := linux-6.12.19
KCFG := catdrive_defconfig
KDTS := $(KERNEL)/arch/arm64/boot/dts/marvell/armada-3720-catdrive.dts
KURL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(KERNEL).tar.xz
KVER = $(shell make -s kernel_version)

DIR = $(TC) $(KERNEL)
MAKE_ARCH := export PATH=$$PATH:$(LOCATION)/$(TC)/bin; make -C $(KERNEL) CROSS_COMPILE=aarch64-none-linux-gnu- ARCH=arm64
J = $(shell grep ^processor /proc/cpuinfo | wc -l)

all: kernel modules
	mkdir -p $(OUTPUT)
	cp -f $(KERNEL)/defconfig $(OUTPUT)/$(KCFG)
	cp -f $(KERNEL)/arch/arm64/boot/Image $(OUTPUT)
	cp -f $(KERNEL)/arch/arm64/boot/dts/marvell/armada-3720-catdrive.dtb $(OUTPUT)
	tar --owner=root --group=root -cJf $(OUTPUT)/modules.tar.xz -C $(STAGE) lib

dl_toolchain:
ifeq (,$(wildcard $(TC).tar.xz))
	curl -O -L $(TCURL)
endif

dl_kernel:
ifeq (,$(wildcard $(KERNEL).tar.xz))
	curl -O -L $(KURL)
endif

download: dl_toolchain dl_kernel

$(DIR):
ifeq (,$(wildcard $@))
	tar xf $@.tar.xz
	rm -rf $@/.git
endif

patch: download $(DIR)
ifeq (,$(wildcard $(KDTS)))
	find $(LOCATION)/patches -type f -print | sort | xargs -n 1 patch -d $(KERNEL) -p1 -i
endif

kernel-config:
ifeq (,$(wildcard $(KERNEL)/arch/arm64/configs/$(KCFG)))
	cp -f $(KCFG) $(KERNEL)/arch/arm64/configs/
endif
	$(MAKE_ARCH) $(KCFG)

kernel_version: kernel-config
	$(MAKE_ARCH) kernelrelease

kernel: kernel-config
	$(MAKE_ARCH) -j$(J) Image dtbs
	$(MAKE_ARCH) savedefconfig

modules: kernel-config
	rm -rf $(STAGE)
	$(MAKE_ARCH) -j$(J) modules
	$(MAKE_ARCH) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(STAGE) modules_install
	rm -f $(STAGE)/lib/modules/$(KVER)/build $(STAGE)/lib/modules/$(KVER)/source

unpatch:
ifneq (,$(wildcard $(KDTS)))
	find $(LOCATION)/patches -type f -print | sort -r | xargs -n 1 patch -d $(KERNEL) -p1 -R -i
endif

kernel_clean: unpatch
	$(MAKE_ARCH) clean
ifeq (,$(wildcard $(KERNEL)/arch/arm64/configs/$(KCFG)))
	rm $(KERNEL)/arch/arm64/configs/$(KCFG)
endif

clean: kernel_clean
	rm -rf $(STAGE)
	rm -rf $(OUTPUT)/*
