#!/bin/sh

set -oeux pipefail


### BUILD UBLUE AKMODS-KEY RPM
install -D /etc/pki/akmods/certs/public_key.der /tmp/ublue-os-akmods-key/rpmbuild/SOURCES/public_key.der
rpmbuild -ba \
    --define '_topdir /tmp/ublue-os-akmods-key/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/ublue-os-akmods-key/ublue-os-akmods-key.spec

