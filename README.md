# ublue-os akmods

[![build-39](https://github.com/ublue-os/akmods/actions/workflows/build-39.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-39.yml) [![build-40](https://github.com/ublue-os/akmods/actions/workflows/build-40.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-40.yml)

A layer for adding extra kernel modules to your image. Use for better hardware support and a few other features!

## How it's organized

The [`akmods` image](https://github.com/orgs/ublue-os/packages/container/package/akmods) is built and published daily. However, there's not a single image but several, given various kernel support we now provide.

The akmods package is broken out into three akmod "streams":

- `common` - any kmod installed by default in Bluefin or which was originally in main pre-39
- `extra` - primarily for kmods used in Bazzite or any others we need, but don't fit in `common`
- `nvidia` - only for the nvidia kmod and addons
- `zfs` - only for the zfs kmod and utilities

Feel free to PR more kmod build scripts into this repo!

## Features

### Overview

The `common` stream image contains related kmod packages, plus:

- `ublue-os-akmods-addons` - installs extra repos and our kmods signing key; install and import to allow SecureBoot systems to use these kmods
- `ublue-os-ucore-addons` - a slightly lighter `ublue-os-akmods-addons` for CoreOS/uCore systems

The `nvidia` stream image contains

- `ublue-os-nvidia-addons` - installs extra repos enabling our nvidia support
  - [nvidia container selinux policy](https://github.com/NVIDIA/dgx-selinux/tree/master/src/nvidia-container-selinux) - uses RHEL9 policy as the closest match
  - [nvidia-container-tookkit repo](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-yum-or-dnf) - version 1.14 (and newer) provide CDI for podman use of nvidia gpus
- `ublue-os-ucore-nvidia` - a slightly lighter `ublue-os-nvidia-addons` for CoreOS/uCore systems

### Kmod Packages

| Package | Stream | Description | Source |
|---------|--------|-------------|--------|
| [ayaneo-platform](https://github.com/ShadowBlip/ayaneo-platform) | extra | Linux drivers for AYANEO x86 handhelds | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ayaneo-platform-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ayaneo-platform-kmod) |
| [ayn-platform](https://github.com/ShadowBlip/ayn-platform) | extra | Linux drivers for AYN x86 handhelds | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ayn-platform-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ayn-platform-kmod) |
| [bmi260](https://github.com/hhd-dev/bmi260) | extra | kernel module driver for the Bosch BMI260 IMU | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/bmi260-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/bmi260-kmod) |
| [evdi](www.displaylink.com) | extra | kernel module required for use of displaylink | [negativo17 - fedora-multimedia](https://negativo17.org/) |
| [facetimehd](https://github.com/patjak/facetimehd/) | extra | kernel module Linux driver for the FacetimeHD (Broadcom 1570) PCIe webcam | [![badge](https://copr.fedorainfracloud.org/coprs/mulderje/facetimehd-kmod/package/facetimehd-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/mulderje/facetimehd-kmod/package/facetimehd-kmod) |
| [framework-laptop](https://github.com/DHowett/framework-laptop-kmod) | common | A kernel module that exposes the Framework Laptop (13, 16)'s battery charge limit and LEDs to userspace | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/framework-laptop-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/framework-laptop-kmod) |
| [gcadapter_oc](https://github.com/hannesmann/gcadapter-oc-kmod) | extra | kernel module for overclocking the Nintendo Wii U/Mayflash GameCube adapter | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/gcadapter_oc-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/gcadapter_oc-kmod) |
| [it87-extras](https://github.com/frankcrawford/it87) | extra | Linux driver for ITE sensors and PWM controllers with expanded Gigabyte motherboard support | [![badge](https://copr.fedorainfracloud.org/coprs/grandpares/it87-extras/package/it87-extras-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/grandpares/it87-extras/package/it87-extras-kmod/) |
| [kvmfr](https://github.com/gnif/looking-glass) | common | KVM framebuffer relay kernel module for use with Looking Glass | [![badge](https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/package/kvmfr-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/package/kvmfr-kmod) |
| [nct6687d](https://github.com/Fred78290/nct6687d) | extra | Linux kernel module for Nuvoton NCT6687-R found on AMD B550 chipset motherboards | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/nct6687d-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/nct6687d-kmod) |
| [nvidia](https://negativo17.org/nvidia-driver/) | nvidia | nvidia GPU drivers | [negativo17 - fedora-nvidia](https://negativo17.org/) |
| [openrazer](https://openrazer.github.io/) | common | kernel module adding additional features to Razer hardware | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/openrazer-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/openrazer-kmod) |
| [rtl8814au](https://github.com/morrownr/8814au) | extra | Realtek RTL8814AU Driver | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/rtl8814au-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/rtl8814au-kmod) |
| [rtl88xxau](https://github.com/aircrack-ng/rtl8812au) | extra | Realtek RTL8812AU/21AU and RTL8814AU driver | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/rtl88xxau-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/rtl88xxau-kmod) |
| [ryzen-smu](https://gitlab.com/leogx9r/ryzen_smu) | extra | A Linux kernel driver that exposes access to the SMU (System Management Unit) for certain AMD Ryzen Processors | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ryzen-smu-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ryzen-smu-kmod) |
| [v4l2loopback](https://github.com/umlaeute/v4l2loopback) | common | allows creating "virtual video devices" | [RPMFusion - free](https://rpmfusion.org/) |
| [wl](https://github.com/rpmfusion/broadcom-wl/) | common | support for some legacy broadcom wifi devices | [RPMFusion - nonfree](https://rpmfusion.org/) |
| [xpadneo](https://github.com/atar-axis/xpadneo) | common | xbox one controller bluetooth driver | [negativo17 - fedora-multimedia](https://negativo17.org/) |
| [xone](https://github.com/BoukeHaarsma23/xonedo/) | common | xbox one controller USB wired/RF driver modified to work along-side xpad | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/xone-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/xone-kmod) |
| [zenergy](https://github.com/BoukeHaarsma23/zenergy) | extra | Based on AMD_ENERGY driver, but with some jiffies added so non-root users can read it safely | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/zenergy-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/zenergy-kmod) |
| [zfs](https://github.com/openzfs/zfs) | zfs | OpenZFS advanced file system and volume manager (From Ucore, CoreOS Only) |

## Notes

We do our best to support all current builds of Fedora, current versions of the kernel modules listed, and the latest NVIDIA driver.
**Note: NVIDIA legacy driver version 470 is no longer provided as RPMfusion has ceased updates to the package and it no longer builds with kernel 6.8 which has now released for Fedora 39. Also the `-550` extra driver version tag has been removed as the latest driver will always be included.**

The majority of the drivers are tagged with `KERNEL_TYPE-FEDORA_RELEASE`. NVIDIA drivers are bundled distinctly with tag `KERNEL_TYPE-FEDORA_RELEASE-NVIDIA_VERSION`.

| KERNEL_TYPE | FEDORA_RELEASE | TAG |
| - | - | - |
| Fedora stock kernel | 39 | `main-39` |
| | 40 | `main-40` |
| [patched for ASUS devices](https://copr.fedorainfracloud.org/coprs/lukenukem/asus-kernel) | 39 | `asus-39`|
| | 40 | `asus-40` |
| [patched fsync](https://copr.fedorainfracloud.org/coprs/sentry/kernel-fsync) | 39 | `fsync-39` |
| [patched Microsoft Surface devices](https://github.com/linux-surface/linux-surface/) | 39 | `surface-39` |
| | 40 | `surface-40` |

## Usage

To install one of these kmods, you'll need to install any of their specific dependencies (checkout the `build-prep.sh` and the specific `build-FOO.sh` script for details).

For common images, add something like this to your Containerfile, replacing `TAG` with one of the `something-FR` tags above:

    COPY --from=ghcr.io/ublue-os/akmods:TAG /rpms/ /tmp/rpms
    RUN find /tmp/rpms
    RUN rpm-ostree install /tmp/rpms/ublue-os/ublue-os-akmods*.rpm
    RUN rpm-ostree install /tmp/rpms/kmods/kmod-v4l2loopback*.rpm

For extra images, add something like this to your Containerfile, replacing `TAG` with one of the `something-FR` tags above:

    COPY --from=ghcr.io/ublue-os/akmods-extra:TAG /rpms/ /tmp/rpms
    RUN find /tmp/rpms
    RUN rpm-ostree install /tmp/rpms/kmods/kmod-facetimehd*.rpm

For NVIDIA images, add something like this to your Containerfile, replacing `TAG` with one of the `something-FR-NVV` tags above:

    COPY --from=ghcr.io/ublue-os/akmods-nvidia:TAG /rpms/ /tmp/rpms
    RUN find /tmp/rpms
    RUN rpm-ostree install /tmp/rpms/ublue-os/ublue-os-nvidia*.rpm
    RUN rpm-ostree install /tmp/rpms/kmods/kmod-nvidia*.rpm

These examples show:

1. copying all the rpms from the respective akmods images
2. installing the respective ublue specific RPM
3. installing a kmods RPM.

## Adding kmods

If you have a kmod you want to contribute send a pull request by adding a script using [build-kmod-wl.sh](https://github.com/ublue-os/akmods/blob/main/build-kmod-wl.sh) as an example.

## Verification

These images are signed with sisgstore's [cosign](https://docs.sigstore.dev/cosign/overview/). You can verify the signature by downloading the `cosign.pub` key from this repo and running the following command, replacing `RELEASE` with either `39` or `40`:

    cosign verify --key cosign.pub ghcr.io/ublue-os/akmods:RELEASE

## Metrics

![Alt](https://repobeats.axiom.co/api/embed/a7ddeb1a3d2e0ce534ccf7cfa75c33b35183b106.svg "Repobeats analytics image")
