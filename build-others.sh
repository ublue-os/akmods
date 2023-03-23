#!/bin/sh

set -oeux pipefail

RELEASE="$(rpm -E '%fedora.%_arch')"

sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo

rpm-ostree install \
    akmod-v4l2loopback-*.fc${RELEASE} \
    mock

# alternatives cannot create symlinks on its own during a container build
ln -s /usr/bin/ld.bfd /etc/alternatives/ld && ln -s /etc/alternatives/ld /usr/bin/ld

if [[ ! -s "/tmp/certs/private_key.priv" ]]; then
    echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
    cp /tmp/certs/private_key.priv{.test,}
    cp /tmp/certs/public_key.der{.test,}
fi

install -Dm644 /tmp/certs/public_key.der   /etc/pki/akmods/certs/public_key.der
install -Dm644 /tmp/certs/private_key.priv /etc/pki/akmods/private/private_key.priv

# Either successfully build and install the kernel modules, or fail early with debug output
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
LOOPBACK_AKMOD_VERSION="$(basename "$(rpm -q "akmod-v4l2loopback" --queryformat '%{VERSION}-%{RELEASE}')" ".fc${RELEASE%%.*}")"

akmods --force --kernels "${KERNEL_VERSION}" --kmod "v4l2loopback"

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null || \
(cat /var/cache/akmods/v4l2loopback/${LOOPBACK_AKMOD_VERSION}-for-${KERNEL_VERSION}.failed.log && exit 1)

install -D /etc/pki/akmods/certs/public_key.der /tmp/ublue-os-akmods-key/rpmbuild/SOURCES/public_key.der

rpmbuild -ba \
    --define '_topdir /tmp/ublue-os-akmods-key/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/ublue-os-akmods-key/ublue-os-akmods-key.spec


cat <<EOF > /var/cache/akmods/akmod-vars
KERNEL_VERSION=${KERNEL_VERSION}
RELEASE=${RELEASE}
LOOPBACK_AKMOD_VERSION=${LOOPBACK_AKMOD_VERSION}
EOF
