#!/bin/bash

set -ouex pipefail

: "${AKMODNV_PATH:=/tmp/akmods-rpms}"
: "${MULTILIB:=1}"
source "${AKMODNV_PATH}"/kmods/nvidia-vars

# this is only to aid in human understanding of any issues in CI
find "${AKMODNV_PATH}"/

if ! command -v dnf5 >/dev/null; then
    echo "Requires dnf5... Exiting"
    exit 1
fi

# Check if any rpmfusion repos exist before trying to disable them
if dnf5 repolist --all | grep -q rpmfusion; then
    dnf5 config-manager setopt "rpmfusion*".enabled=0
fi

# Always try to disable cisco repo (or add similar check)
dnf5 config-manager setopt fedora-cisco-openh264.enabled=0

## nvidia install steps
dnf5 install -y "${AKMODNV_PATH}"/ublue-os/ublue-os-nvidia-addons-*.rpm

# Install MULTILIB_PKGS packages from negativo17-multimedia prior to disabling repo

MULTILIB_PKGS=(
    mesa-dri-drivers.i686
    mesa-filesystem.i686
    mesa-libEGL.i686
    mesa-libGL.i686
    mesa-libgbm.i686
    mesa-va-drivers.i686
    mesa-vulkan-drivers.i686
)

if [[ "$(rpm -E '%{_arch}')" == "x86_64" && "${MULTILIB}" == "1" ]]; then
    dnf5 install -y "${MULTILIB_PKGS[@]}"
fi

# enable repos provided by ublue-os-nvidia-addons (not enabling fedora-nvidia-lts)
dnf5 config-manager setopt fedora-nvidia*.enabled=1 nvidia-container-toolkit.enabled=1

# Disable Multimedia
NEGATIVO17_MULT_PREV_ENABLED=N
if dnf5 repolist --enabled | grep -q "fedora-multimedia"; then
    NEGATIVO17_MULT_PREV_ENABLED=Y
    echo "disabling negativo17-fedora-multimedia to ensure negativo17-fedora-nvidia is used"
    dnf5 config-manager setopt fedora-multimedia.enabled=0
fi

# Enable staging for supergfxctl if repo file exists
if [[ -f /etc/yum.repos.d/_copr_ublue-os-staging.repo ]]; then
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-staging.repo
else
    dnf5 -y copr enable ublue-os/staging
fi

if [[ "${IMAGE_NAME}" == "kinoite" ]]; then
    VARIANT_PKGS=(
        supergfxctl
    )
elif [[ "${IMAGE_NAME}" == "silverblue" ]]; then
    VARIANT_PKGS=(
        gnome-shell-extension-supergfxctl-gex
        supergfxctl
    )
else
    VARIANT_PKGS=()
fi

NVIDIA_RPMS=(
    "${AKMODNV_PATH}"/nvidia/*."$(rpm -E '%{_arch}')".rpm
    nvidia-container-toolkit
    "${VARIANT_PKGS[@]}"
    "${AKMODNV_PATH}"/kmods/kmod-nvidia-"${KERNEL_VERSION}"-"${NVIDIA_AKMOD_VERSION}"."${DIST_ARCH}".rpm
)

if [[ "$(rpm -E '%{_arch}')" == "x86_64" && "${MULTILIB}" == "1" ]]; then
    NVIDIA_RPMS+=(
        "${AKMODNV_PATH}"/nvidia/*.i686.rpm
    )
fi

dnf5 install -y "${NVIDIA_RPMS[@]}"

# Ensure the version of the Nvidia module matches the driver
KMOD_VERSION="$(rpm -q --queryformat '%{VERSION}' kmod-nvidia)"
DRIVER_VERSION="$(rpm -q --queryformat '%{VERSION}' nvidia-driver)"
if [ "$KMOD_VERSION" != "$DRIVER_VERSION" ]; then
    echo "Error: kmod-nvidia version ($KMOD_VERSION) does not match nvidia-driver version ($DRIVER_VERSION)"
    exit 1
fi

## nvidia post-install steps
# disable repos provided by ublue-os-nvidia-addons
dnf5 config-manager setopt fedora-nvidia*.enabled=0 nvidia-container-toolkit.enabled=0

# Disable staging
dnf5 -y copr disable ublue-os/staging

systemctl enable ublue-nvctk-cdi.service
semodule --verbose --install /usr/share/selinux/packages/nvidia-container.pp

# Universal Blue specific Initramfs fixes
cp /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf
# we must force driver load to fix black screen on boot for nvidia desktops
sed -i 's@omit_drivers@force_drivers@g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
# as we need forced load, also mustpre-load intel/amd iGPU else chromium web browsers fail to use hardware acceleration
sed -i 's@ nvidia @ i915 amdgpu nvidia @g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

# re-enable negativo17-mutlimedia since we disabled it
if [[ "${NEGATIVO17_MULT_PREV_ENABLED}" = "Y" ]]; then
    dnf5 config-manager setopt fedora-multimedia.enabled=1
fi
