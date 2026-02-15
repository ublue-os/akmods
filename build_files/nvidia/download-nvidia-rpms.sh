#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

if [[ "${KERNEL_FLAVOR}" =~ "centos" ]]; then
    echo "Building for CentOS"
    NVIDIA_EXTRA_PKGS=()
else
    echo "Building for Fedora"
    NVIDIA_EXTRA_PKGS=()
    if [ "$(rpm -E '%_arch')" = "x86_64" ]; then
        NVIDIA_EXTRA_PKGS+=(
                "libnvidia-fbc.i686"
                "libnvidia-gpucomp.i686"
                "libnvidia-ml.i686"
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


NVIDIA_RPMS+=(
    "libnvidia-cfg"
    "libnvidia-fbc"
    "libnvidia-gpucomp"
    "libnvidia-ml"
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
