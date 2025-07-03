#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

### BUILD UCORE-ADDONS RPM
install -D /etc/pki/akmods/certs/public_key.der /tmp/ublue-os-ucore-addons/rpmbuild/SOURCES/public_key.der
rpmbuild -ba \
    --define '_topdir /tmp/ublue-os-ucore-addons/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/ublue-os-ucore-addons/ublue-os-ucore-addons.spec
