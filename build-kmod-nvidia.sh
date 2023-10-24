#!/bin/sh

set -oeux pipefail

NVIDIA_MAJOR_VERSION=${1}

RELEASE="$(rpm -E '%fedora.%_arch')"
echo NVIDIA_MAJOR_VERSION=${NVIDIA_MAJOR_VERSION}

cd /tmp

### BUILD nvidia
# nvidia 520.xxx and newer currently don't have a -$VERSIONxx suffix in their
# package names
if [[ "${NVIDIA_MAJOR_VERSION}" -ge 520 ]]; then
    NVIDIA_PACKAGE_NAME="nvidia"
else
    NVIDIA_PACKAGE_NAME="nvidia-${NVIDIA_MAJOR_VERSION}xx"
fi

rpm-ostree install \
    akmod-${NVIDIA_PACKAGE_NAME}*:${NVIDIA_MAJOR_VERSION}.*.fc${RELEASE} \
    xorg-x11-drv-${NVIDIA_PACKAGE_NAME}-{,cuda,devel,kmodsrc,power}*:${NVIDIA_MAJOR_VERSION}.*.fc${RELEASE}

if [[ "${NVIDIA_DRIVER_VARIANT}" != "proprietary" ]]; then
    rpm-ostree install rpmfusion-nonfree-release-tainted
    rpm-ostree install \
        akmod-${NVIDIA_PACKAGE_NAME}-${NVIDIA_DRIVER_VARIANT}*:${NVIDIA_MAJOR_VERSION}.*.fc${RELEASE}
fi

# Either successfully build and install the kernel modules, or fail early with debug output
KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
if [[ "${NVIDIA_DRIVER_VARIANT}" =~ "proprietary" ]]; then
    NVIDIA_AKMOD_VERSION="$(basename "$(rpm -q "akmod-${NVIDIA_PACKAGE_NAME}" --queryformat '%{VERSION}-%{RELEASE}')" ".fc${RELEASE%%.*}")"
else
    NVIDIA_AKMOD_VERSION="$(basename "$(rpm -q "akmod-${NVIDIA_PACKAGE_NAME}-${NVIDIA_DRIVER_VARIANT}" --queryformat '%{VERSION}-%{RELEASE}')" ".fc${RELEASE%%.*}")"
fi
NVIDIA_LIB_VERSION="$(basename "$(rpm -q "xorg-x11-drv-${NVIDIA_PACKAGE_NAME}" --queryformat '%{VERSION}-%{RELEASE}')" ".fc${RELEASE%%.*}")"
NVIDIA_FULL_VERSION="$(rpm -q "xorg-x11-drv-${NVIDIA_PACKAGE_NAME}" --queryformat '%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}')"

akmods --force --kernels "${KERNEL_VERSION}" --kmod "${NVIDIA_PACKAGE_NAME}"

if [[ "${NVIDIA_DRIVER_VARIANT}" != "proprietary" ]]; then
    akmods --force --kernels "${KERNEL_VERSION}" --kmod "${NVIDIA_PACKAGE_NAME}"-"${NVIDIA_DRIVER_VARIANT}"
fi

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/${NVIDIA_PACKAGE_NAME}/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
(cat /var/cache/akmods/${NVIDIA_PACKAGE_NAME}/${NVIDIA_AKMOD_VERSION}-for-${KERNEL_VERSION}.failed.log && exit 1)

cat <<EOF > /var/cache/rpms/kmods/nvidia-vars.${NVIDIA_MAJOR_VERSION}
KERNEL_VERSION=${KERNEL_VERSION}
RELEASE=${RELEASE}
NVIDIA_PACKAGE_NAME=${NVIDIA_PACKAGE_NAME}
NVIDIA_MAJOR_VERSION=${NVIDIA_MAJOR_VERSION}
NVIDIA_FULL_VERSION=${NVIDIA_FULL_VERSION}
NVIDIA_AKMOD_VERSION=${NVIDIA_AKMOD_VERSION}
NVIDIA_LIB_VERSION=${NVIDIA_LIB_VERSION}
EOF
