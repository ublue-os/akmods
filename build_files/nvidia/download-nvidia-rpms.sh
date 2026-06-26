#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

ARCH="$(rpm -E '%_arch')"
KMOD_REPO="${1:-nvidia}"
DRIVER_EVR="$(dnf repoquery --qf '%{EPOCH}:%{VERSION}-%{RELEASE}\n' akmod-nvidia | sort -V | tail -n1)"
DRIVER_VERSION="${DRIVER_EVR#*:}"
DRIVER_VERSION="${DRIVER_VERSION%-*}"

if [[ "${KERNEL_FLAVOR}" =~ "centos" ]]; then
    echo "Building for CentOS"
    NVIDIA_EXTRA_PKGS=()
else
    echo "Building for Fedora"
    NVIDIA_EXTRA_PKGS=()
    if [ "${ARCH}" = "x86_64" ]; then
        NVIDIA_EXTRA_PKGS+=(
                "libnvidia-fbc.i686"
                "nvidia-driver-cuda-libs.i686"
                "nvidia-driver-libs.i686"
            )
    fi
    if [[ ! "${KMOD_REPO}" =~ "lts" ]]; then
        NVIDIA_EXTRA_PKGS+=(
            "xorg-x11-nvidia"
            "nvidia-xconfig"
        )
    fi
fi

NVIDIA_DRIVER_COMMON_PKGS=()
if dnf repoquery --qf '%{VERSION}\n' nvidia-driver-common | grep -qxF "${DRIVER_VERSION}"; then
    echo "Using nvidia-driver-common for NVIDIA ${DRIVER_VERSION}"
    NVIDIA_DRIVER_COMMON_PKGS+=(
        "nvidia-driver-common"
    )
    if [[ "${ARCH}" = "x86_64" && ! "${KERNEL_FLAVOR}" =~ "centos" ]] && \
        dnf repoquery --qf '%{VERSION}\n' nvidia-driver-common.i686 | grep -qxF "${DRIVER_VERSION}"; then
        NVIDIA_EXTRA_PKGS+=(
            "nvidia-driver-common.i686"
        )
    fi
else
    echo "Using legacy NVIDIA split library packages for NVIDIA ${DRIVER_VERSION}"
    NVIDIA_DRIVER_COMMON_PKGS+=(
        "libnvidia-cfg"
        "libnvidia-gpucomp"
        "libnvidia-ml"
    )
    if [[ "${ARCH}" = "x86_64" && ! "${KERNEL_FLAVOR}" =~ "centos" ]]; then
        NVIDIA_EXTRA_PKGS+=(
            "libnvidia-gpucomp.i686"
            "libnvidia-ml.i686"
        )
    fi
fi

NVIDIA_RPMS+=(
    "libnvidia-fbc"
    "${NVIDIA_DRIVER_COMMON_PKGS[@]}"
    "nvidia-driver"
    "nvidia-driver-cuda"
    "nvidia-driver-cuda-libs"
    "nvidia-driver-libs"
    "nvidia-kmod-common"
    "nvidia-libXNVCtrl"
    "nvidia-modprobe"
    "nvidia-persistenced"
    "nvidia-settings"
    "${NVIDIA_EXTRA_PKGS[@]}"
)

mkdir -p /var/cache/rpms/nvidia
dnf download --destdir /var/cache/rpms/nvidia "${NVIDIA_RPMS[@]}"

rm -f /var/cache/rpms/nvidia/*.src.rpm
