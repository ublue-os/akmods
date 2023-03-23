#!/bin/sh

set -ouex pipefail

#source akmod variables
source /var/cache/akmods/akmod-vars

#install local kmod RPMs and possible necessary remote packages
rpm-ostree install \
    v4l2loopback \
    /var/cache/akmods/v4l2loopback/kmod-v4l2loopback-${KERNEL_VERSION}-${LOOPBACK_AKMOD_VERSION}.fc${RELEASE}.rpm \
    /tmp/ublue-os-akmods-key/rpmbuild/RPMS/noarch/ublue-os-akmods-key-*.rpm
