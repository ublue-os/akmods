#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
# allow pinning to a specific release series (eg, 2.0.x or 2.1.x)
ZFS_MINOR_VERSION="${ZFS_MINOR_VERSION:-}"
# CoreOS testing may opt into the one experimental configure switch we support.
ZFS_CONFIGURE_ARGS="${ZFS_CONFIGURE_ARGS:-}"
ZFS_CONFIGURE_ARGS_ARRAY=()
if [[ -n "${ZFS_CONFIGURE_ARGS}" ]]; then
    if [[ "${ZFS_CONFIGURE_ARGS}" != "--enable-linux-experimental" ]]; then
        echo "Unsupported ZFS_CONFIGURE_ARGS: ${ZFS_CONFIGURE_ARGS}" >&2
        exit 1
    fi
    ZFS_CONFIGURE_ARGS_ARRAY=("${ZFS_CONFIGURE_ARGS}")
fi

cd /tmp

# Use cURL to fetch the given URL, saving the response to `data.json`
curl "https://api.github.com/repos/openzfs/zfs/releases" -o data.json
ZFS_VERSION=$(jq -r --arg ZMV "zfs-${ZFS_MINOR_VERSION}" '[ .[] | select(.prerelease==false and .draft==false) | select(.tag_name | startswith($ZMV))][0].tag_name' data.json|cut -f2- -d-)
echo "ZFS_MINOR_VERSION==$ZFS_MINOR_VERSION"
echo "ZFS_VERSION==$ZFS_VERSION"
echo "ZFS_CONFIGURE_ARGS==$ZFS_CONFIGURE_ARGS"


### zfs specific build deps
dnf install -y libtirpc-devel libblkid-devel libuuid-devel libudev-devel openssl-devel libaio-devel libattr-devel elfutils-libelf-devel python3-devel libffi-devel libcurl-devel ncompress python3-setuptools


### BUILD zfs
echo "getting zfs-${ZFS_VERSION}.tar.gz"
curl -L -O "https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_VERSION}/zfs-${ZFS_VERSION}.tar.gz"
curl -L -O "https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_VERSION}/zfs-${ZFS_VERSION}.tar.gz.asc"
curl -L -O "https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_VERSION}/zfs-${ZFS_VERSION}.sha256.asc"

echo "Import key"
# https://openzfs.github.io/openzfs-docs/Project%20and%20Community/Signing%20Keys.html
gpg --yes --keyserver keyserver.ubuntu.com --recv D4598027
gpg --yes --keyserver keyserver.ubuntu.com --recv C77B9667
gpg --yes --keyserver keyserver.ubuntu.com --recv C6AF658B

echo "Verifying tar.gz signature"
if ! gpg --verify "zfs-${ZFS_VERSION}.tar.gz.asc" "zfs-${ZFS_VERSION}.tar.gz"; then
    echo "ZFS tarball signature verification FAILED! Exiting..."
    exit 1
fi

echo "Verifying checksum signature"
if ! gpg --verify "zfs-${ZFS_VERSION}.sha256.asc"; then
    echo "Checksum signature verification FAILED! Exiting..."
    exit 1
fi

echo "Verifying encrypted checksum"
if ! gpg --decrypt "zfs-${ZFS_VERSION}.sha256.asc" | sha256sum -c; then
    echo "Checksum verification FAILED! Exiting..."
    exit 1
fi

# no-same-owner/no-same-permissions required for F40 based images building on podman 3.4.4 (ubuntu 22.04)
tar -z -x --no-same-owner --no-same-permissions -f "zfs-${ZFS_VERSION}.tar.gz"

cd "/tmp/zfs-${ZFS_VERSION}"

# 2.4.3 predates both Linux 7.1 support (openzfs/zfs#18682) and the zfs_fillpage()
# mmap underflow fix (openzfs/zfs#18715). Neither has been backported to
# zfs-2.4-release, so carry them here for 2.4.3 only; later releases are expected
# to ship them and must not be patched.
if [[ "${ZFS_VERSION}" == "2.4.3" ]]; then
    echo "zfs-${ZFS_VERSION} requires patches"
    for patch in /tmp/patches/*.patch; do
        echo "PATCH ${patch##*/}"
        git apply "${patch}"
    done
else
    echo "zfs-${ZFS_VERSION}: no patches required"
fi

# normalize timestamps so autotools doesn't complain about clock skew
find . -exec touch -h -r "/tmp/zfs-${ZFS_VERSION}.tar.gz" {} + 2>/dev/null || true
# ensure rpm spec depends on correct kernel-devel package, else build fails on kernel-longterm kernels
sed -i "s|kernel-devel|${KERNEL_NAME}-devel|" rpm/*/*spec.in

if [[ -n "${ZFS_CONFIGURE_ARGS}" ]]; then
    for spec in rpm/generic/zfs-kmod.spec.in rpm/redhat/zfs-kmod.spec.in; do
        if [[ ! -f "${spec}" ]] || ! grep -q '^[[:space:]]*%{?kernel_arch}[[:space:]]*$' "${spec}"; then
            echo "Unable to add ZFS configure arguments to ${spec}" >&2
            exit 1
        fi
        # rpm-kmod invokes configure separately, so it needs the same opt-in.
        sed -i 's|^\([[:space:]]*%{?kernel_arch}\)[[:space:]]*$|\1 --enable-linux-experimental|' "${spec}"
    done
fi

# GCC 16+ rejects earlyclobber on hard-bound registers (see GCC PR 87600)
LOCALLY_PATCHED=false
if [ "$(uname -m)" = "aarch64" ]; then
    if grep -q '^#define[[:space:]]*UVR.*"+&w"' module/zfs/vdev_raidz_math_aarch64_neon_common.h; then
        echo "PATCH raidz aarch64 neon to drop earlyclobber"
        sed -i '/^#define[[:space:]]*UVR/s/"+&w"/"+w"/g' module/zfs/vdev_raidz_math_aarch64_neon_common.h
        LOCALLY_PATCHED=true
    else
        echo "SKIP patch to raidz aarch64 neon, already applied upstream"
    fi
fi
# Hint at the coreos-stable kernel pin when OpenZFS rejects this kernel.
# See README.md#pinning-the-coreos-stable-kernel
suggest_coreos_stable_kernel_pin() {
    local flavor="${KERNEL_FLAVOR:-}"
    if [[ ! "${flavor}" =~ coreos-stable ]]; then
        return 0
    fi

    local looks_unsupported=false
    local linux_max=""
    local kernel_mm=""

    if [[ -f META ]]; then
        linux_max="$(awk -F: '/^Linux-Maximum:/ { gsub(/[[:space:]]/, "", $2); print $2 }' META)"
    fi
    kernel_mm="$(echo "${KERNEL}" | grep -oE '^[0-9]+\.[0-9]+')"

    # Linux-Maximum is major.minor; 7.1.4 does not exceed a declared 7.1.
    if [[ -n "${linux_max}" && -n "${kernel_mm}" ]]; then
        if [[ "$(printf '%s\n' "${linux_max}" "${kernel_mm}" | sort -V | tail -n1)" == "${kernel_mm}" && \
              "${kernel_mm}" != "${linux_max}" ]]; then
            looks_unsupported=true
        fi
    fi

    if [[ -f config.log ]] && grep -Eiq \
        'not a supported kernel|maximum supported kernel|unsupported Linux kernel|Cannot enable unsupported' \
        config.log; then
        looks_unsupported=true
    fi

    if [[ "${looks_unsupported}" != true ]]; then
        return 0
    fi

    cat >&2 <<'EOF'

========================================================================
This coreos-stable ZFS build failed because the kernel looks newer than
OpenZFS currently declares supported.

Pinning the last successful coreos-stable kernel unblocks the rest of
the coreos-stable publication pipeline (common, nvidia, and downstream
stable images) until an OpenZFS release supports this kernel.

Read this before carrying local ZFS kernel-compat backports:
https://github.com/ublue-os/akmods/blob/main/README.md#pinning-the-coreos-stable-kernel
========================================================================
EOF
}

if ! ./configure \
        -with-linux="/usr/src/kernels/${KERNEL}/" \
        -with-linux-obj="/usr/src/kernels/${KERNEL}/" \
        "${ZFS_CONFIGURE_ARGS_ARRAY[@]}" \
    || ! make -j "$(nproc)" rpm-utils rpm-kmod; then
    cat config.log || true
    suggest_coreos_stable_kernel_pin
    exit 1
fi

# validate RAIDZ math implementations when we've locally patched on aarch64
if [ "${LOCALLY_PATCHED}" = "true" ]; then
    echo "Installing ZFS packages for raidz_test validation..."
    rpm -ivh --nodeps \
        ./lib*."$(uname -m)".rpm \
        ./zfs-2.[0-9]*."$(uname -m)".rpm \
        ./zfs-test-*."$(uname -m)".rpm \
        2> >(grep -v debuginfo >&2)
    ldconfig
    if ! command -v raidz_test &>/dev/null; then
        echo "ERROR: raidz_test not found after installing zfs-test package"
        exit 1
    fi
    echo "Running raidz_test to validate RAIDZ math implementations..."
    raidz_test -S -t 60
    echo "raidz_test PASSED"
fi

# create a directory for later copying of resulting zfs specific artifacts
mkdir -p /var/cache/rpms/kmods/zfs/{debug,devel,other,src}
mv ./*src.rpm /var/cache/rpms/kmods/zfs/src/
mv ./*devel*.rpm /var/cache/rpms/kmods/zfs/devel/
mv ./*debug*.rpm /var/cache/rpms/kmods/zfs/debug/
mv zfs-dracut*.rpm /var/cache/rpms/kmods/zfs/other/
mv zfs-test*.rpm /var/cache/rpms/kmods/zfs/other/
mv ./*.rpm /var/cache/rpms/kmods/zfs/
