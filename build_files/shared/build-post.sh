#!/bin/sh

set -oeux pipefail

for RPM in $(find /var/cache/akmods/ -type f -name \*.rpm); do \
    cp "${RPM}" /var/cache/rpms/kmods/; \
done

find /var/cache/rpms
