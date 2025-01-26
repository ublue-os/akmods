#!/bin/sh

set -oeux pipefail

curl -L https://negativo17.org/repos/fedora-nvidia.repo \
    -o /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-fedora-nvidia.repo

curl -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
    -o /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/nvidia-container-toolkit.repo
sed -i "s@gpgcheck=0@gpgcheck=1@" /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/nvidia-container-toolkit.repo

curl -L https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp \
    -o /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/nvidia-container.pp


rpmbuild -ba \
    --define '_topdir /tmp/ublue-os-nvidia-addons/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/ublue-os-nvidia-addons/ublue-os-nvidia-addons.spec
