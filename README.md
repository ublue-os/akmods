[![build-ublue](https://github.com/ublue-os/akmods/actions/workflows/build.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build.yml)

# ublue-os akmods

A layer for adding extra kernel modules to your image. Use for better hardware support and a few other features!

# Usage

Add this to your Containerfile to install all the RPM packages, replacing `RELEASE` with either `37` or `38`:

    COPY --from=ghcr.io/ublue-os/akmods:RELEASE /rpms/ /tmp/rpms
    RUN rpm-ostree install /tmp/rpms/ublue-os/*.rpm
    RUN rpm-ostree install /tmp/rpms/kmods/*.rpm

This example shows:
1. copying all the rpms from the akmods image
2. installing the ublue specific RPM, providing any extra repos and the akmod signing key
3. installing the kmods RPMs, providing the actual kmods built in this repo

The rpmfusion and extra repos provide dependencies which are required by the kmods RPMs.


# Features

Feel free to PR more kmod build scripts into this repo!

- ublue-os-akmods-addons - installs extra repos and our kmods signing key; install and import to allow SecureBoot systems to use these kmods
    - [nvidia container selinux policy](https://github.com/NVIDIA/dgx-selinux/tree/master/src/nvidia-container-selinux) - uses RHEL9 policy as the closest match
    - [nvidia-container-tookkit repo](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-yum-or-dnf) - version 1.14 (and newer) provide CDI for podman use of nvidia gpus
- [evdi](www.displaylink.com) - kernel module required for use of displaylink (akmod from [negativo17 multimedia repo](https://negativo17.org/multimedia/)
- [gasket/apex](https://github.com/google/gasket-driver) - kernel module for Coral Gasket Driver, allowing usage of the Coral EdgeTPU on Linux systems (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [gcadapter_oc](https://github.com/hannesmann/gcadapter-oc-kmod) - kernel module for overclocking the Nintendo Wii U/Mayflash GameCube adapter (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [nct6687d](https://github.com/Fred78290/nct6687d) - Linux kernel module for Nuvoton NCT6687-R found on AMD B550 chipset motherboards (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [nvidia](https://rpmfusion.org/Howto/NVIDIA) - nvidia GPU drivers built from rpmfusion
- [openrazer](https://openrazer.github.io/) - kernel module adding additional features to Razer hardware (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [openrgb](https://gitlab.com/CalcProgrammer1/OpenRGB/-/raw/master/OpenRGB.patch) - kernel module with i2c-nct6775 and patched i2c-piix4 for use with OpenRGB (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [ryzen_smu](https://gitlab.com/leogx9r/ryzen_smu) - A Linux kernel driver that exposes access to the SMU (System Management Unit) for certain AMD Ryzen Processors (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [steamdeck](https://lkml.org/lkml/2022/2/5/391) - platform driver for Valve's Steam Deck handheld PC (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [v4l2loopback](https://github.com/umlaeute/v4l2loopback) - allows creating "virtual video devices"
- [winesync](https://repo.or.cz/linux/zf.git/shortlog/refs/heads/winesync4) - Support for Winesync/Fastsync/NTSync primitives
- [wl (broadcom)](https://github.com/rpmfusion/broadcom-wl/) - support for some legacy broadcom wifi devices
- [xpadneo](https://github.com/atar-axis/xpadneo) - xbox one controller bluetooth driver (akmod from [negativo17 steam repo](https://negativo17.org/steam/)
- [xpad-noone](https://github.com/ublue-os/xpad-noone) - xbox/xbox 360 controller driver (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [xone](https://github.com/medusalix/xone) - xbox one controller USB wired/RF driver (akmod from [negativo17 steam repo](https://negativo17.org/steam/)

# Adding kmods

If you have a kmod you want to contribute send a pull request by adding a script using [build-kmod-wl.sh](https://github.com/ublue-os/akmods/blob/main/build-kmod-wl.sh) as an example.

# Verification

These images are signed with sisgstore's [cosign](https://docs.sigstore.dev/cosign/overview/). You can verify the signature by downloading the `cosign.pub` key from this repo and running the following command, replacing `RELEASE` with either `37` or `38`:

    cosign verify --key cosign.pub ghcr.io/ublue-os/akmods:RELEASE

