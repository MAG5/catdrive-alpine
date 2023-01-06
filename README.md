### build catdrive kernel

linux-5.10.y LTS kernel for marvell armada-3720-catdrive

#### toolchain

    gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu

fetch latest gnu toolchain from

<https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/gnu-a/downloads>

#### linux-marvell

    https://www.kernel.org
    branch linux-5.10.y

#### build

    make patch
    make all

Porting the patch from <https://github.com/hanwckf/linux-marvell>

### Upgrade Kernel

#### backup old kernel & modules

    mv /boot/armada-3720-catdrive.dtb /boot/armada-3720-catdrive.dtb.old
    mv /boot/Image /boot/Image.old
    mv /lib/modules/4.14.76-armada-18.12.3 /lib/modules/4.14.76-armada-18.12.3.old

#### install new kernel & modules

    cp ./armada-3720-catdrive.dtb /boot/armada-3720-catdrive.dtb
    cp ./Image /boot/Image
    tar --no-same-owner xf ./modules.tar.xz --strip-components 2 -C /lib/modules/
    mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
