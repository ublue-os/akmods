#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

ARCH="$(rpm -E '%_arch')"
KMOD_REPO="${1:-nvidia}"

DIST="$(rpm -E '%dist')"
DIST="${DIST#.}"
VARS_KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
if [[ "${KERNEL_FLAVOR}" =~ "centos" ]]; then
    # enable negativo17
    cp "/tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-epel-${KMOD_REPO}.repo" /etc/yum.repos.d/
else
    # disable rpmfusion and enable negativo17
    sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/rpmfusion-*.repo
    cp "/tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-fedora-${KMOD_REPO}.repo" /etc/yum.repos.d/
fi
export KERNEL_MODULE_TYPE=open
if [[ "${KMOD_REPO}" =~ "lts" ]]; then
    export KERNEL_MODULE_TYPE=kernel
fi
DEPRECATED_RELEASE="${DIST}.${ARCH}"

# Applies patches for the current kernel flavor.
# Patches can be optionally placed in build_files/nvidia/patches/{flavor}/
# and will be applied alphanumerically if present.
patch_nvidia_kmod_source() {
    local patch_dir="/tmp/patches/${KERNEL_FLAVOR}"
    local topdir="/tmp/nvidia-kmod-patched"
    local patches=() tarball srcdir patched_srpm patch

    [[ -d "${patch_dir}" ]] || return 0
    mapfile -t patches < <(find "${patch_dir}" -maxdepth 1 -name '*.patch' | sort)
    (( ${#patches[@]} )) || return 0

    echo "Applying ${#patches[@]} ${KERNEL_FLAVOR} patch(es) to nvidia-kmod source"

    rm -rf "${topdir}"
    rpm -i --define "_topdir ${topdir}" /usr/src/akmods/nvidia-kmod.latest

    tarball="$(find "${topdir}/SOURCES" -maxdepth 1 -name 'open-gpu-kernel-modules-*.tar.gz' -print -quit)"
    if [[ -z "${tarball}" ]]; then
        echo "ERROR: no open-gpu-kernel-modules tarball in ${topdir}/SOURCES" >&2
        exit 1
    fi

    srcdir="$(basename "${tarball}" .tar.gz)"

    pushd "${topdir}/SOURCES" > /dev/null
    tar xzf "${tarball}"
    if [[ ! -d "${srcdir}" ]]; then
        echo "ERROR: ${tarball##*/} did not unpack into ${srcdir}/" >&2
        exit 1
    fi
    for patch in "${patches[@]}"; do
        echo "  ${patch##*/}"
        patch -p1 -F0 -d "${srcdir}" < "${patch}"
    done
    tar czf "${tarball}.new" "${srcdir}"
    mv "${tarball}.new" "${tarball}"
    rm -rf "${srcdir}"
    popd > /dev/null

    rpmbuild -bs --define "_topdir ${topdir}" "${topdir}/SPECS/nvidia-kmod.spec"

    patched_srpm="$(find "${topdir}/SRPMS" -maxdepth 1 -name 'nvidia-kmod-*.src.rpm' -print -quit)"
    if [[ -z "${patched_srpm}" ]]; then
        echo "ERROR: rpmbuild produced no patched SRPM in ${topdir}/SRPMS" >&2
        exit 1
    fi

    ln -sfn "${patched_srpm}" /usr/src/akmods/nvidia-kmod.latest
}

cd /tmp

### BUILD nvidia

# query latest available driver in repo
DRIVER_VERSION=$(dnf info akmod-nvidia | grep -E '^Version|^Release' | awk '{print $3}' | xargs | sed 's/\ /-/')

# only install the version of akmod-nviida which matches available nvidia-driver
# this works around situations where a new version may be released but not for one arch
dnf install -y \
    "akmod-nvidia-${DRIVER_VERSION}"

# Either successfully build and install the kernel modules, or fail early with debug output
rpm -qa |grep nvidia
KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
NVIDIA_AKMOD_VERSION="$(basename "$(rpm -q "akmod-nvidia" --queryformat '%{VERSION}-%{RELEASE}')" ".${DIST}")"

patch_nvidia_kmod_source

akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"

modinfo /usr/lib/modules/"${KERNEL_VERSION}"/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
(cat /var/cache/akmods/nvidia/"${NVIDIA_AKMOD_VERSION}"-for-"${KERNEL_VERSION}".failed.log && exit 1)

# View license information
modinfo -l /usr/lib/modules/"${KERNEL_VERSION}"/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

# create a directory for later copying of resulting nvidia specific artifacts
mkdir -p /var/cache/rpms/kmods/nvidia

# TODO: remove deprecated RELEASE var which clobbers more typical meanings/usages of RELEASE
cat <<EOF > /var/cache/rpms/kmods/nvidia-vars
DIST_ARCH="${DIST}.${ARCH}"
KERNEL_VERSION=${VARS_KERNEL_VERSION}
# KERNEL_MODULE_TYPE: deprecated as of 2025-12-07, in favor of KMOD_REPO
# latest drivers are always "open", and LTS driver is always "kernel"
KERNEL_MODULE_TYPE=${KERNEL_MODULE_TYPE}
# KMOD_REPO: latest drivers are "nvidia", and LTS driver is "nvidia-lts"
KMOD_REPO=${KMOD_REPO}
RELEASE="${DEPRECATED_RELEASE}"
NVIDIA_AKMOD_VERSION=${NVIDIA_AKMOD_VERSION}
EOF
