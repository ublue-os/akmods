# ublue-os akmods

[![Build BAZZITE akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-bazzite.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-bazzite.yml)[![Build CENTOS akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-centos.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-centos.yml)[![Build COREOS-STABLE akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-coreos-stable.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-coreos-stable.yml)[![Build COREOS-TESTING akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-coreos-testing.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-coreos-testing.yml)[![Build LONGTERM-6.12 akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-longterm-6.12.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-longterm-6.12.yml)[![Build MAIN akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-main.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-main.yml)

OCI images providing a set of cached kernel RPMs and extra kernel modules to Universal Blue images. Used for better hardware support and consistent build process.

## How it's organized

The [`akmods` images](https://github.com/orgs/ublue-os/packages?repo_name=akmods) are built and published daily. However, there's not a single image but several, given various kernels we now support.

The akmods packages are divided up for building in a few different "groups":

- `common` - any kmod installed by default in Bluefin/Aurora (or were originally in main images pre-Fedora 39)
- `extra` - any kmods used by Bazzite but not Bluefine/Aurora
- `nvidia` - only the nvidia proprietary kmod and addons
- `nvidia-open` - only the nvidia-open kmod and addons
- `zfs` - only the zfs kmod and utilities built for select kernels

Each of these images contains a cached copy of the respective kernel RPMs compatible with the respective kmods for the image.

Builds also run for different kernels:

- `bazzite` - Bazzite [builds a kernel with gaming specific patches](https://github.com/bazzite-org/kernel-bazzite) for the current release of Fedora
- `main` - Mainline Fedora Kernel
- `coreos-stable` - Current Fedora CoreOS stable kernel version
- `coreos-testing` - Current Fedora CoreOS testing kernel version
- `Centos` - Mainline Centos Kernel
- `Longterm-6.12` - Fedora Kernel on Kernel 6.12 LTS

See `images.yaml` for which akmods packages are built for each Kernel

## Features

### Overview

The `common` images contain related kmod packages, plus:

- `ublue-os-akmods-addons` - installs extra repos and our kmods signing key; install and import to allow SecureBoot systems to use these kmods
- `ublue-os-ucore-addons` - a slightly lighter `ublue-os-akmods-addons` for CoreOS/uCore systems

The `nvidia` and `nvidia-open` images contains

- `ublue-os-nvidia-addons` - installs extra repos enabling our nvidia support
  - [nvidia container selinux policy](https://github.com/NVIDIA/dgx-selinux/tree/master/src/nvidia-container-selinux) - uses RHEL9 policy as the closest match
  - [nvidia-container-toolkit repo](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-yum-or-dnf) - version 1.14 (and newer) provide CDI for podman use of nvidia gpus
- `ublue-os-ucore-nvidia` - a slightly lighter `ublue-os-nvidia-addons` for CoreOS/uCore systems

### Kmod Packages

| Group | Package | Description | Source |
|-------|---------|-------------|--------|
| common | [framework-laptop](https://github.com/DHowett/framework-laptop-kmod) | A kernel module that exposes the Framework Laptop (13, 16)'s battery charge limit and LEDs to userspace | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/framework-laptop-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/framework-laptop-kmod) |
| common | [kvmfr](https://github.com/gnif/looking-glass) | KVM framebuffer relay kernel module for use with Looking Glass | [![badge](https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/package/kvmfr-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/package/kvmfr-kmod) |
| common | [openrazer](https://openrazer.github.io/) | kernel module adding additional features to Razer hardware | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/openrazer-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/openrazer-kmod) |
| common | [v4l2loopback](https://github.com/umlaeute/v4l2loopback) | allows creating "virtual video devices" | [RPMFusion - free](https://rpmfusion.org/) |
| common | [wl](https://github.com/rpmfusion/broadcom-wl/) | support for some legacy broadcom wifi devices | [RPMFusion - nonfree](https://rpmfusion.org/) |
| common | [xone](https://github.com/BoukeHaarsma23/xonedo/) | xbox one controller USB wired/RF driver modified to work along-side xpad | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/xone-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/xone-kmod) |
| extra | [ayaneo-platform](https://github.com/ShadowBlip/ayaneo-platform) | Linux drivers for AYANEO x86 handhelds | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ayaneo-platform-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ayaneo-platform-kmod) |
| extra | [ayn-platform](https://github.com/ShadowBlip/ayn-platform) | Linux drivers for AYN x86 handhelds | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ayn-platform-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ayn-platform-kmod) |
| extra | [bmi260](https://github.com/hhd-dev/bmi260) | kernel module driver for the Bosch BMI260 IMU | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/bmi260-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/bmi260-kmod) |
| extra | [evdi](www.displaylink.com) | kernel module required for use of displaylink | [negativo17 - fedora-multimedia](https://negativo17.org/) |
| extra | [gcadapter_oc](https://github.com/hannesmann/gcadapter-oc-kmod) | kernel module for overclocking the Nintendo Wii U/Mayflash GameCube adapter | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/gcadapter_oc-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/gcadapter_oc-kmod) |
| extra | [gpd-fan](https://github.com/KyleGospo/gpd-fan-driver) | kernel module to control fan speeds on GPD handhelds | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/gpd-fan-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/gpd-fan-kmod) |
| extra | [nct6687d](https://github.com/Fred78290/nct6687d) | Linux kernel module for Nuvoton NCT6687-R found on AMD B550 chipset motherboards | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/nct6687d-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/nct6687d-kmod) |
| extra | [ryzen-smu](https://gitlab.com/leogx9r/ryzen_smu) | A Linux kernel driver that exposes access to the SMU (System Management Unit) for certain AMD Ryzen Processors | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ryzen-smu-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/ryzen-smu-kmod) |
| extra | [system76](https://github.com/pop-os/system76-dkms) | A Linux kernel driver for System76 laptops | [![badge](https://copr.fedorainfracloud.org/coprs/ssweeny/system76-hwe/package/system76-driver-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ssweeny/system76-hwe/package/system76-driver-kmod/) |
| extra | [system76-io](https://github.com/pop-os/system76-io-dkms) | A Linux kernel driver for the System76 Io board, which is used in System76's Thelio desktop line | [![badge](https://copr.fedorainfracloud.org/coprs/ssweeny/system76-hwe/package/system76-io-akmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ssweeny/system76-hwe/package/system76-io-akmod/) |
| extra | [zenergy](https://github.com/BoukeHaarsma23/zenergy) | Based on AMD_ENERGY driver, but with some jiffies added so non-root users can read it safely | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/zenergy-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/zenergy-kmod) |
| nvidia | [nvidia](https://negativo17.org/nvidia-driver/) | nvidia GPU drivers | [negativo17 - fedora-nvidia](https://negativo17.org/) |
| nvidia-open | [nvidia](https://negativo17.org/nvidia-driver/) | nvidia-open GPU drivers | [negativo17 - fedora-nvidia](https://negativo17.org/) |
| zfs | [zfs](https://github.com/openzfs/zfs) | OpenZFS advanced file system and volume manager | [zfs](https://github.com/openzfs/zfs) |

## Notes

### NVIDIA Hardware Support

We build both the open and closed drivers from NVIDIA. The open driver is the only option for supporting the latest hardware. The closed driver is required for older hardware, but even it doesn't support "legacy" hardware.

`nvidia-open` - newest current and most open driver supports the following hardware:

- GeForce RTX: 50 Series, 40 Series, 30 Series, 20 Series
- GeForce: 16 Series
- and more: [NVIDIA Compatible GPUs list](https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus)

`nvidia` - closed proprietary driver supports the following hardware:

- GeForce RTX: 40 Series, 30 Series, 20 Series
- GeForce: 16 Series, 10 Series, 900 Series, 700 Series
- NVIDIA Turing: T4, T4G
- NVIDIA Volta: V100
- NVIDIA Pascal: Quadro: P2000, P4000, P5000, P6000, GP100; Tesla: P100, P40, P4
- NVIDIA Maxwell: Quadro: K2200, M2000, M4000, M5000, M6000, M6000 24GB; - - Tesla: M60, M40, M6, M4

## Usage

To install one of these kmods, you'll need to install any of their specific dependencies (checkout the `build-prep.sh` and the specific `build-FOO.sh` script for details), and ensure you are on a compatible kernel.

Using common images as an example, add something like this to your Containerfile, replacing `TAG` with the appropriate tag for the image:

    COPY --from=ghcr.io/ublue-os/akmods:TAG / /tmp/akmods-common
    RUN find /tmp/akmods-common
    ## optionally install remove old and install new kernel
    # dnf -y remove --no-autoremove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra
    ## install ublue support package and desired kmod(s)
    RUN dnf install /tmp/rpms/ublue-os/ublue-os-akmods*.rpm
    RUN dnf install /tmp/rpms/kmods/kmod-v4l2loopback*.rpm

For NVIDIA images, add something like this to your Containerfile, replacing `TAG` with the appropriate tag for the image:

    COPY --from=ghcr.io/ublue-os/akmods-nvidia:TAG / /tmp/akmods-nvidia
    RUN find /tmp/akmods-nvidia
    ## optionally install remove old and install new kernel
    # dnf -y remove --no-autoremove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra
    ## install ublue support package and desired kmod(s)
    RUN dnf install /tmp/rpms/ublue-os/ublue-os-nvidia*.rpm
    RUN dnf install /tmp/rpms/kmods/kmod-nvidia*.rpm
  
*Note* There is an nvidia-install script that most universal-blue images use located with the *main* repo that works for desktop Fedora installs.

## Verification

These images are signed with sisgstore's [cosign](https://docs.sigstore.dev/about/overview/). You can verify the signature by downloading the `cosign.pub` key from this repo and running the following command, replacing `KERNEL_FLAVOR` with whichever kernel you are using and `RELEASE` with either `40`, `41` or `42`:

    cosign verify --key cosign.pub ghcr.io/ublue-os/akmods:KERNEL_FLAVOR-RELEASE

## Local Building/Testing

You can build these akmods locally with our test keys using the included `Justfile`. We strongly recommend using the provided devcontainer which contains all dependencies for building this project.

### How to Use the Justfile

To build an akmods package, run the following:

```bash
just build
```
Since nothing additional was set. The following will occur. The build scripts will determine the current fedora kernel version, download the RPMs, and sign the kernel with the test key. It will then build the common set of akmods. To modify what gets built, modify the following environment variables:

- AKMODS_KERNEL - The kernel flavor you are building
- AKMODS_VERSION - The release version
- AKMODS_TARGET - The akmods package to build

```bash
AKMODS_KERNEL=centos AKMODS_VERSION=10 AKMODS_TARGET=zfs just build
```

Will determine the current centos kernel version, download the rpms and sign them, and will then build the zfs package.

You can also populate a `.env` file to store your current settings.

You can see your current settings with `just --evaluate`

Additionally you can pass values as key/value pairs.

```bash
just kernel_flavor=bazzite version=42 akmods_target=extra build
```

Which will build the extra package for Bazzite.

Note, the `Justfile` will compare your inputs to the `images.yaml` file to ensure you have a valid combination.

### How to Use images.yaml

All build targets are defined in the `images.yaml` file. This is where the top level targets are defined. You can view the targets using:

```bash
yq 'explode(.).images' images.yaml
```

### Adding Kernels and KMODs

Generally speaking, Kernels are only added if they will be used internally to Universal Blue.

KMODs as well will likely only be included if there is a need/desire to include them within the Universal Blue Project. Generally, KMODs for hardware enablement will be considered for inclusion or ones that fix/resolve a known feature gap.

Don't hesitate to file an issue asking about inclusion.

## Metrics

![Alt](https://repobeats.axiom.co/api/embed/a7ddeb1a3d2e0ce534ccf7cfa75c33b35183b106.svg "Repobeats analytics image")
