#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

ARCH="$(rpm -E '%_arch')"
KMOD_REPO="${1:-nvidia}"
if [[ -n "${NVIDIA_AKMOD_EVR:-}" ]]; then
    DRIVER_EVR="${NVIDIA_AKMOD_EVR}"
else
    DRIVER_EVR="$(dnf repoquery --qf '%{EPOCH}:%{VERSION}-%{RELEASE}\n' akmod-nvidia | sort -V | tail -n1)"
fi
DRIVER_VERSION="${DRIVER_EVR#*:}"
DRIVER_VERSION="${DRIVER_VERSION%-*}"

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

NVIDIA_DRIVER_COMMON_PKGS=()
if dnf repoquery --qf '%{VERSION}\n' nvidia-driver-common | grep -qxF "${DRIVER_VERSION}"; then
    echo "Using nvidia-driver-common for NVIDIA ${DRIVER_VERSION}"
    NVIDIA_DRIVER_COMMON_PKGS+=(
        "nvidia-driver-common"
    )
    if [[ "${ARCH}" = "x86_64" ]] && \
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
    if [[ "${ARCH}" = "x86_64" ]]; then
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
if [[ -n "${NVIDIA_AKMOD_EVR:-}" ]]; then
    #shellcheck source=../prep/dnf-retry.sh
    source /tmp/dnf-retry.sh
    # Resolve against the same negativo17 repo the fingerprint queried
    REPO_ID="$(sed -n 's/^\[\(.*\)\]$/\1/p' "/etc/yum.repos.d/negativo17-fedora-${KMOD_REPO}.repo" | head -n1)"
    if [[ -z "${REPO_ID}" ]]; then
        echo "ERROR: no repo id in negativo17-fedora-${KMOD_REPO}.repo" >&2
        exit 1
    fi
    # Userspace packages come from several source RPMs whose releases differ, so
    # pin each one to the driver version and take its latest release.
    NVIDIA_NEVRAS=()
    for pkg in "${NVIDIA_RPMS[@]}"; do
        name="${pkg%.i686}"
        arches=("${ARCH}" noarch)
        [[ "${pkg}" == "${name}" ]] || arches=(i686)
        # one arch at a time, native before noarch, so a name built both ways resolves once
        nevra=()
        for arch in "${arches[@]}"; do
            mapfile -t nevra < <(dnf repoquery --disablerepo='*' --enablerepo="${REPO_ID}" \
                --latest-limit=1 --arch="${arch}" \
                --qf '%{NAME} %{NAME}-%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}\n' "${name}-${DRIVER_VERSION}" |
                awk -v name="${name}" '$1 == name { print $2 }')
            (( ${#nevra[@]} == 0 )) || break
        done
        if (( ${#nevra[@]} != 1 )); then
            echo "ERROR: expected one ${pkg} at version ${DRIVER_VERSION} in ${REPO_ID}, found ${#nevra[@]}" >&2
            exit 1
        fi
        NVIDIA_NEVRAS+=("${nevra[0]}")
    done
    dnf_retry download --destdir /var/cache/rpms/nvidia "${NVIDIA_NEVRAS[@]}"
else
    dnf download --destdir /var/cache/rpms/nvidia "${NVIDIA_RPMS[@]}"
fi

rm -f /var/cache/rpms/nvidia/*.src.rpm

if [[ -n "${NVIDIA_AKMOD_EVR:-}" ]]; then
    for rpm in /var/cache/rpms/nvidia/*.rpm; do
        version="$(rpm -qp --queryformat '%{VERSION}' "${rpm}")"
        if [[ "${version}" != "${DRIVER_VERSION}" ]]; then
            echo "ERROR: ${rpm##*/} is version ${version}, expected ${DRIVER_VERSION}" >&2
            exit 1
        fi
    done
fi
