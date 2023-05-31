#!/bin/sh

set -oeux pipefail


### BUILD UBLUE AKMODS-ADDONS RPM
#sed -i "s@gpgcheck=0@gpgcheck=1@" /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-steam.repo

install -D /etc/pki/akmods/certs/public_key.der /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/public_key.der
rpmbuild -ba \
    --define '_topdir /tmp/ublue-os-akmods-addons/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/ublue-os-akmods-addons/ublue-os-akmods-addons.spec
