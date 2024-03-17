[![build-ublue](https://github.com/ublue-os/akmods/actions/workflows/build.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build.yml)

# ublue-os akmods

A layer for adding extra kernel modules to your image. Use for better hardware support and a few other features!

# Features

Feel free to PR more kmod build scripts into this repo!

- ublue-os-akmods-addons - installs extra repos and our kmods signing key; install and import to allow SecureBoot systems to use these kmods
- ublue-os-nvidia-addons - installs extra repos enabling our nvidia support
    - [nvidia container selinux policy](https://github.com/NVIDIA/dgx-selinux/tree/master/src/nvidia-container-selinux) - uses RHEL9 policy as the closest match
    - [nvidia-container-tookkit repo](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-yum-or-dnf) - version 1.14 (and newer) provide CDI for podman use of nvidia gpus
- [ayaneo-platform](https://github.com/ShadowBlip/ayaneo-platform) - Linux drivers for AYANEO x86 handhelds (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [ayn-platform](https://github.com/ShadowBlip/ayn-platform) - Linux drivers for AYN x86 handhelds (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [bmi160](https://github.com/hhd-dev/bmi160) - kernel module driver for the BMI160 IMU (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [bmi260](https://github.com/hhd-dev/bmi260) - kernel module driver for the Bosch BMI260 IMU (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [bmi323](https://github.com/hhd-dev/bmi260) - kernel module driver for the Bosch BMI323 IMU (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [evdi](www.displaylink.com) - kernel module required for use of displaylink (akmod from [negativo17 multimedia repo](https://negativo17.org/multimedia/)
- [gasket/apex](https://github.com/google/gasket-driver) - kernel module for Coral Gasket Driver, allowing usage of the Coral EdgeTPU on Linux systems (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [gcadapter_oc](https://github.com/hannesmann/gcadapter-oc-kmod) - kernel module for overclocking the Nintendo Wii U/Mayflash GameCube adapter (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [nct6687d](https://github.com/Fred78290/nct6687d) - Linux kernel module for Nuvoton NCT6687-R found on AMD B550 chipset motherboards (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [nvidia](https://rpmfusion.org/Howto/NVIDIA) - nvidia GPU drivers built from rpmfusion
- [openrazer](https://openrazer.github.io/) - kernel module adding additional features to Razer hardware (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [openrgb](https://gitlab.com/CalcProgrammer1/OpenRGB/-/raw/master/OpenRGB.patch) - kernel module with i2c-nct6775 and patched i2c-piix4 for use with OpenRGB (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- rtl8814au - Realtek RTL8814AU Driver (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- rtl88xxau - Realtek RTL8812AU/21AU and RTL8814AU driver (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [ryzen_smu](https://gitlab.com/leogx9r/ryzen_smu) - A Linux kernel driver that exposes access to the SMU (System Management Unit) for certain AMD Ryzen Processors (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [steamdeck](https://lkml.org/lkml/2022/2/5/391) - platform driver for Valve's Steam Deck handheld PC (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [v4l2loopback](https://github.com/umlaeute/v4l2loopback) - allows creating "virtual video devices"
- [winesync](https://repo.or.cz/linux/zf.git/shortlog/refs/heads/winesync4) - Support for Winesync/Fastsync/NTSync primitives (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [wl (broadcom)](https://github.com/rpmfusion/broadcom-wl/) - support for some legacy broadcom wifi devices
- [xpadneo](https://github.com/atar-axis/xpadneo) - xbox one controller bluetooth driver (akmod from [negativo17 steam repo](https://negativo17.org/steam/)
- [xonedo](https://github.com/BoukeHaarsma23/xonedo/) - xbox one controller USB wired/RF driver modified to work along-side xpad (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [zenergy](https://github.com/BoukeHaarsma23/zenergy) - Based on AMD_ENERGY driver, but with some jiffies added so non-root users can read it safely. (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))

# How it's organized

The [`akmods` image](https://github.com/orgs/ublue-os/packages/container/package/akmods) is built and published daily. However, there's not a single image but several, given various kernel support we now provide.

Here's a rundown on how it's organized.

We do our best to support all current builds of Fedora, current versions of the kernel modules listed, and in the case of NVIDIA, current (550) and the 470 legacy driver.

The majority of the drivers are tagged with `KERNEL_TYPE-FEDORA_RELEASE`. NVIDIA drivers are bundled distinctly with tag `KERNEL_TYPE-FEDORA_RELEASE-NVIDIA_VERSION`.

| KERNEL_TYPE | FEDORA_RELEASE | TAG |
| - | - | - |
| Fedora stock kernel | 38 | `main-38`, `main-38-470` `main-38-550` |
| | 39 | `main-39`, `main-39-470` `main-39-550` |
| [patched for ASUS devices](https://copr.fedorainfracloud.org/coprs/lukenukem/asus-kernel) | 38 | `asus-38`, `asus-38-470` `asus-38-550` |
| | 39 | `asus-39`, `asus-39-470` `asus-39-550` |
| [patched Microsoft Surface devices](https://github.com/linux-surface/linux-surface/) | 38 | `surface-38`, `surface-38-550` |
| | 39 | `surface-39`, `surface-39-550` |



# Usage

To install one of these kmods, you'll need to install any of their specific dependencies (checkout the `build-prep.sh` and the specific `build-FOO.sh` script for details.

For common images, add something like this to your Containerfile, replacing `TAG` with one of the `something-FR` tags above:

    COPY --from=ghcr.io/ublue-os/akmods:TAG /rpms/ /tmp/rpms
    RUN find /tmp/rpms
    RUN rpm-ostree install /tmp/rpms/ublue-os/ublue-os-akmods*.rpm
    RUN rpm-ostree install /tmp/rpms/kmods/kmod-v4l2loopback*.rpm

For NVIDIA images, add something like this to your Containerfile, replacing `TAG` with one of the `something-FR-NVV` tags above:

    COPY --from=ghcr.io/ublue-os/akmods:TAG /rpms/ /tmp/rpms
    RUN find /tmp/rpms
    RUN rpm-ostree install /tmp/rpms/ublue-os/ublue-os-nvidia*.rpm
    RUN rpm-ostree install /tmp/rpms/kmods/kmod-nvidia.rpm

These examples show:
1. copying all the rpms from the respective akmods images
2. installing the respective ublue specific RPM
3. installing a kmods RPM.


# Adding kmods

If you have a kmod you want to contribute send a pull request by adding a script using [build-kmod-wl.sh](https://github.com/ublue-os/akmods/blob/main/build-kmod-wl.sh) as an example.

# Verification

These images are signed with sisgstore's [cosign](https://docs.sigstore.dev/cosign/overview/). You can verify the signature by downloading the `cosign.pub` key from this repo and running the following command, replacing `RELEASE` with either `38` or `39`:

    cosign verify --key cosign.pub ghcr.io/ublue-os/akmods:RELEASE

# Metrics

![Alt](https://repobeats.axiom.co/api/embed/a7ddeb1a3d2e0ce534ccf7cfa75c33b35183b106.svg "Repobeats analytics image")

