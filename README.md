[![build-38](https://github.com/ublue-os/akmods/actions/workflows/build-38.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-38.yml) [![build-39](https://github.com/ublue-os/akmods/actions/workflows/build-39.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-39.yml) [![build-40](https://github.com/ublue-os/akmods/actions/workflows/build-40.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-40.yml)

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
- [evdi](www.displaylink.com) - kernel module required for use of displaylink (akmod from [negativo17 multimedia repo](https://negativo17.org/multimedia/)
- [kvmfr](https://github.com/gnif/looking-glass) - KVM framebuffer relay kernel module for use with Looking Glass (akmod from [hikariknight/looking-glass-kvmfr-akmod copr](https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/))
- [nct6687d](https://github.com/Fred78290/nct6687d) - Linux kernel module for Nuvoton NCT6687-R found on AMD B550 chipset motherboards (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [nvidia](https://rpmfusion.org/Howto/NVIDIA) - nvidia GPU drivers built from rpmfusion
- [openrazer](https://openrazer.github.io/) - kernel module adding additional features to Razer hardware (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- rtl8814au - Realtek RTL8814AU Driver (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- rtl88xxau - Realtek RTL8812AU/21AU and RTL8814AU driver (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [ryzen_smu](https://gitlab.com/leogx9r/ryzen_smu) - A Linux kernel driver that exposes access to the SMU (System Management Unit) for certain AMD Ryzen Processors (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [v4l2loopback](https://github.com/umlaeute/v4l2loopback) - allows creating "virtual video devices"
- [wl (broadcom)](https://github.com/rpmfusion/broadcom-wl/) - support for some legacy broadcom wifi devices
- [xpadneo](https://github.com/atar-axis/xpadneo) - xbox one controller bluetooth driver (akmod from [negativo17 steam repo](https://negativo17.org/steam/)
- [xonedo](https://github.com/BoukeHaarsma23/xonedo/) - xbox one controller USB wired/RF driver modified to work along-side xpad (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))
- [zenergy](https://github.com/BoukeHaarsma23/zenergy) - Based on AMD_ENERGY driver, but with some jiffies added so non-root users can read it safely. (akmod from [ublue-os/akmods copr](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/))

# How it's organized

The [`akmods` image](https://github.com/orgs/ublue-os/packages/container/package/akmods) is built and published daily. However, there's not a single image but several, given various kernel support we now provide.

Here's a rundown on how it's organized.

We do our best to support all current builds of Fedora, current versions of the kernel modules listed, and the latest NVIDIA driver.
**Note: NVIDIA legacy driver version 470 is no longer provided as RPMfusion has ceased updates to the package and it no longer builds with kernel 6.8 which has now released for Fedora 38 and 39. Also the `-550` extra driver version tag has been removed as the latest driver will always be included.**

The majority of the drivers are tagged with `KERNEL_TYPE-FEDORA_RELEASE`. NVIDIA drivers are bundled distinctly with tag `KERNEL_TYPE-FEDORA_RELEASE-NVIDIA_VERSION`.

| KERNEL_TYPE | FEDORA_RELEASE | TAG |
| - | - | - |
| Fedora stock kernel | 38 | `main-38` |
| | 39 | `main-39` |
| | 40 | `main-40` |
| [patched for ASUS devices](https://copr.fedorainfracloud.org/coprs/lukenukem/asus-kernel) | 39 | `asus-39`|
| | 40 | `asus-40` |
| [patched fsync](https://copr.fedorainfracloud.org/coprs/sentry/kernel-fsync) | 39 | `fsync-39` |
| [patched Microsoft Surface devices](https://github.com/linux-surface/linux-surface/) | 39 | `surface-39` |
| | 40 | `surface-40` |



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

