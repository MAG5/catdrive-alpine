CUR_DIR := $(shell pwd)
STAGE_DIR := $(CUR_DIR)/stage
OUTPUT_DIR := $(CUR_DIR)/output

TC := gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu
TCURL := https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/$(TC).tar.xz

KDIR := linux-5.10.162
KCFG := catdrive_defconfig
KDTS := $(KDIR)/arch/arm64/boot/dts/marvell/armada-3720-catdrive.dts
KURL := https://cdn.kernel.org/pub/linux/kernel/v5.x/$(KDIR).tar.xz
KVER = $(shell make -s kernel_version)

MAKE_ARCH := export PATH=$$PATH:$(CUR_DIR)/$(TC)/bin; make -C $(KDIR) CROSS_COMPILE=aarch64-none-linux-gnu- ARCH=arm64
J=$(shell grep ^processor /proc/cpuinfo | wc -l)

all: kernel modules
	mkdir -p $(OUTPUT_DIR)
	cp -f $(KDIR)/defconfig $(OUTPUT_DIR)/$(KCFG)
	cp -f $(KDIR)/arch/arm64/boot/Image $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/dts/marvell/armada-3720-catdrive.dtb $(OUTPUT_DIR)
	tar --owner=root --group=root -cJf $(OUTPUT_DIR)/modules.tar.xz -C $(STAGE_DIR) lib

dl_toolchain:
ifeq (,$(wildcard $(TC).tar.xz))
	curl -O -L $(TCURL)
	tar xf $(TC).tar.xz
else ifeq (,$(wildcard $(TC)))
	tar xf $(TC).tar.xz
endif

dl_kernel:
ifeq (,$(wildcard $(KDIR).tar.xz))
	curl -O -L $(KURL)
	tar xf $(KDIR).tar.xz
	rm -rf $(KDIR)/.git
else ifeq (,$(wildcard $(KDIR)))
	tar xf $(KDIR).tar.xz
	rm -rf $(KDIR)/.git
endif

kernel-config: patch
	cp -f $(KCFG) $(KDIR)/arch/arm64/configs/
	$(MAKE_ARCH) $(KCFG)

patch: dl_kernel dl_toolchain
ifeq (,$(wildcard $(KDTS)))
	find $(CUR_DIR)/patches -type f -print | sort | xargs -n 1 patch -d $(KDIR) -p1 -i
endif

kernel_version: kernel-config
	$(MAKE_ARCH) kernelrelease

kernel: kernel-config
	$(MAKE_ARCH) -j$(J) Image dtbs
	$(MAKE_ARCH) savedefconfig

modules: kernel-config
	rm -rf $(STAGE_DIR)
	$(MAKE_ARCH) -j$(J) modules
	$(MAKE_ARCH) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(STAGE_DIR) modules_install
	rm -f $(STAGE_DIR)/lib/modules/$(KVER)/build $(STAGE_DIR)/lib/modules/$(KVER)/source

kernel_clean:
	$(MAKE_ARCH) clean
ifneq (,$(wildcard $(KDTS)))
	find $(CUR_DIR)/patches -type f -print | sort -r | xargs -n 1 patch -d $(KDIR) -p1 -R -i
endif

clean: kernel_clean
	rm -rf $(STAGE_DIR)
	rm -rf $(OUTPUT_DIR)/*
