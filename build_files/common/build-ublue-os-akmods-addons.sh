#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

### BUILD UBLUE AKMODS-ADDONS RPM
# ensure a higher priority is set for our ublue akmods COPR to pull deps from it over other sources (99 is default)
echo "priority=85" >> /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo

install -D /etc/pki/akmods/certs/public_key.der /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/public_key.der

# drop spec references to sources that were not staged for this flavor
# (non-Fedora builds only stage the ublue akmods COPR repo)
spec=/tmp/ublue-os-akmods-addons/ublue-os-akmods-addons.spec
grep -oP '^Source\d+:\s+\K\S+' "$spec" | while read -r f; do
    if [[ ! -f "/tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/$f" ]]; then
        sed -i "\\|$f|d" "$spec"
    fi
done
rpmbuild -ba \
    --define '_topdir /tmp/ublue-os-akmods-addons/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/ublue-os-akmods-addons/ublue-os-akmods-addons.spec
