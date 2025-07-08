#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

### SETUP nvidia container stuffs

mkdir -p /tmp/ublue-os-ucore-nvidia/rpmbuild/SOURCES/

curl -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
    -o /tmp/ublue-os-ucore-nvidia/rpmbuild/SOURCES/nvidia-container-toolkit.repo
sed -i "s@gpgcheck=0@gpgcheck=1@" /tmp/ublue-os-ucore-nvidia/rpmbuild/SOURCES/nvidia-container-toolkit.repo

curl -L https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp \
    -o /tmp/ublue-os-ucore-nvidia/rpmbuild/SOURCES/nvidia-container.pp

rpmbuild -ba \
    --define '_topdir /tmp/ublue-os-ucore-nvidia/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/ublue-os-ucore-nvidia/ublue-os-ucore-nvidia.spec
