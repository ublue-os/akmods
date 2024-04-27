#!/bin/sh

set -oeux pipefail


sed -i "s@gpgcheck=0@gpgcheck=1@" /tmp/build/ublue-os-nvidia-addons/rpmbuild/SOURCES/nvidia-container-toolkit.repo

rpmbuild -ba \
    --define '_topdir /tmp/build/ublue-os-nvidia-addons/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/build/ublue-os-nvidia-addons/ublue-os-nvidia-addons.spec
