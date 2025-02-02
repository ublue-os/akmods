#!/bin/sh

set -oeux pipefail

# Ensure packages get copied to /var/cache/rpms
if [ -d /var/cache/akmods ]; then
    for RPM in $(find /var/cache/akmods/ -type f -name \*.rpm); do
        cp "${RPM}" /var/cache/rpms/kmods/
    done
fi

if [ -d /root/rpmbuild/RPMS/"$(uname -m)" ]; then
    for RPM in $(find /root/rpmbuild/RPMS/"$(uname -m)"/ -type f -name \*.rpm); do
        cp "${RPM}" /var/cache/rpms/kmods/
    done
fi

# Remove kernel version from kmod package names
# FIXME: The sed is a gross hack, maybe PR upstream?
sed -i -e 's/args = \["rpmbuild", "-bb"\]/args = \["rpmbuild", "-bb", "--buildroot", "#{build_path}\/BUILD"\]/g' /usr/local/share/gems/gems/fpm-*/lib/fpm/package/rpm.rb
kernel_version=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" "${KERNEL_NAME}" | head -n 1)
for rpm in $(find /var/cache/rpms/kmods -type f -name \*.rpm); do
    basename=$(basename ${rpm})
    name=${basename%%-${kernel_version}*}
    if [[ "$basename" == *"$kernel_version"* ]]; then
        fpm --verbose -s rpm -t rpm -p ${rpm} -f --name ${name} ${rpm}
    else
        echo "Skipping $basename rebuild as its name does not contain $kernel_version"
    fi
done

# ensure kernel cache RPMS are copied
mkdir -p /var/cache/kernel-rpms
cp -a /tmp/kernel_cache/*.rpm /var/cache/kernel-rpms

find /var/cache/rpms
