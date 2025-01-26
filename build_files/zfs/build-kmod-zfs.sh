#!/usr/bin/bash

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

# allow pinning to a specific release series (eg, 2.0.x or 2.1.x)
ZFS_MINOR_VERSION="${ZFS_MINOR_VERSION:-}"

cd /tmp

# Use cURL to fetch the given URL, saving the response to `data.json`
curl "https://api.github.com/repos/openzfs/zfs/releases" -o data.json
ZFS_VERSION=$(jq -r --arg ZMV "zfs-${ZFS_MINOR_VERSION}" '[ .[] | select(.prerelease==false and .draft==false) | select(.tag_name | startswith($ZMV))][0].tag_name' data.json|cut -f2- -d-)
echo "ZFS_VERSION==$ZFS_VERSION"


### zfs specific build deps
dnf install -y libtirpc-devel libblkid-devel libuuid-devel libudev-devel openssl-devel libaio-devel libattr-devel elfutils-libelf-devel python3-devel libffi-devel libcurl-devel ncompress python3-setuptools


### BUILD zfs
echo "getting zfs-${ZFS_VERSION}.tar.gz"
curl -L -O https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_VERSION}/zfs-${ZFS_VERSION}.tar.gz
# no-same-owner/no-same-permissions required for F40 based images building on podman 3.4.4 (ubuntu 22.04)
tar -z -x --no-same-owner --no-same-permissions -f zfs-${ZFS_VERSION}.tar.gz

# patch the zfs-kmod.spec.in file for older zfs versions
ZFS_MAJ=$(echo $ZFS_VERSION | cut -f1 -d.)
ZFS_MIN=$(echo $ZFS_VERSION | cut -f2 -d.)
ZFS_PATCH=$(echo $ZFS_VERSION | cut -f3 -d.)

cd /tmp/zfs-${ZFS_VERSION}
./configure \
        -with-linux=/usr/src/kernels/${KERNEL}/ \
        -with-linux-obj=/usr/src/kernels/${KERNEL}/ \
    && make -j $(nproc) rpm-utils rpm-kmod \
    || (cat config.log && exit 1)


# create a directory for later copying of resulting zfs specific artifacts
mkdir -p /var/cache/rpms/kmods/zfs/{debug,devel,other,src} \
    && mv *src.rpm /var/cache/rpms/kmods/zfs/src/ \
    && mv *devel*.rpm /var/cache/rpms/kmods/zfs/devel/ \
    && mv *debug*.rpm /var/cache/rpms/kmods/zfs/debug/ \
    && mv zfs-dracut*.rpm /var/cache/rpms/kmods/zfs/other/ \
    && mv zfs-test*.rpm /var/cache/rpms/kmods/zfs/other/ \
    && mv *.rpm /var/cache/rpms/kmods/zfs/
