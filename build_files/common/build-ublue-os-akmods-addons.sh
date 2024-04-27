#!/bin/sh

set -oeux pipefail


### BUILD UBLUE AKMODS-ADDONS RPM
# ensure a higher priority is set for our ublue akmods COPR to pull deps from it over other sources (99 is default)
echo "priority=90" >> /tmp/build/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo

install -D /etc/pki/akmods/certs/public_key.der /tmp/build/ublue-os-akmods-addons/rpmbuild/SOURCES/public_key.der
rpmbuild -ba \
    --define '_topdir /tmp/build/ublue-os-akmods-addons/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/build/ublue-os-akmods-addons/ublue-os-akmods-addons.spec
