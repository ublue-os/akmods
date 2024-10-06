#!/usr/bin/bash

set -oeux pipefail


### PREPARE REPOS
# ARCH="$(rpm -E '%_arch')"
RELEASE="$(rpm -E '%fedora')"

sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

# install kernel_cache provided kernel
echo "Installing ${KERNEL_FLAVOR} kernel-cache RPMs..."
# fedora image has no kernel so this needs nothing fancy, just install
dnf install -y /tmp/kernel_cache/*.rpm
if [[ "${KERNEL_FLAVOR}" == "surface" ]]; then
    KERNEL_VERSION=$(rpm -q kernel-surface|cut -d '-' -f2-)
else
    KERNEL_VERSION=$(rpm -q kernel|cut -d '-' -f2-)
fi

# enable more repos
RPMFUSION_MIRROR_RPMS="https://mirrors.rpmfusion.org"
if [ -n "${RPMFUSION_MIRROR}" ]; then
    RPMFUSION_MIRROR_RPMS=${RPMFUSION_MIRROR}
fi
dnf install -y \
    "${RPMFUSION_MIRROR_RPMS}"/free/fedora/rpmfusion-free-release-"${RELEASE}".noarch.rpm \
    "${RPMFUSION_MIRROR_RPMS}"/nonfree/fedora/rpmfusion-nonfree-release-"${RELEASE}".noarch.rpm \
    fedora-repos-archive

# after F41 launches, bump to 42
if [[ "${FEDORA_MAJOR_VERSION}" -ge 41 ]]; then
    # pre-release rpmfusion is in a different location
    sed -i "s%free/fedora/releases%free/fedora/development%" /etc/yum.repos.d/rpmfusion-*.repo
    # pre-release rpmfusion needs to enable testing
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/rpmfusion-*-updates-testing.repo
fi

if [ -n "${RPMFUSION_MIRROR}" ]; then
    # force use of single rpmfusion mirror
    echo "Using single rpmfusion mirror: ${RPMFUSION_MIRROR}"
    sed -i.bak "s%^metalink=%#metalink=%" /etc/yum.repos.d/rpmfusion-*.repo
    sed -i "s%^#baseurl=http://download1.rpmfusion.org%baseurl=${RPMFUSION_MIRROR}%" /etc/yum.repos.d/rpmfusion-*.repo
fi

### PREPARE BUILD ENV
dnf install -y \
    akmods \
    mock

if [[ ! -s "/tmp/certs/private_key.priv" ]]; then
    echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
    cp /tmp/certs/private_key.priv{.test,}
    cp /tmp/certs/public_key.der{.test,}
fi

install -Dm644 /tmp/certs/public_key.der   /etc/pki/akmods/certs/public_key.der
install -Dm644 /tmp/certs/private_key.priv /etc/pki/akmods/private/private_key.priv

if [[ "${DUAL_SIGN}" == "true" ]]; then
    dnf install -y rpmrebuild
    if [[ ! -s "/tmp/certs/private_key_2.priv" ]]; then
        echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
        cp /tmp/certs/private_key_2.priv{.test,}
        cp /tmp/certs/public_key_2.der{.test,}
    fi
    openssl x509 -in /tmp/certs/public_key_2.der -out /tmp/certs/public_key_2.crt
    openssl x509 -in /tmp/certs/public_key.der -out /tmp/certs/public_key.crt
    cat /tmp/certs/private_key.priv <(echo) /tmp/certs/public_key.crt >> /tmp/certs/signing_key_1.pem
    cat /tmp/certs/private_key_2.priv <(echo) /tmp/certs/public_key_2.crt >> /tmp/certs/signing_key_2.pem
    cat /tmp/certs/public_key.crt <(echo) /tmp/certs/public_key_2.crt >> /tmp/certs/public_key_chain.pem
fi

# This is for ZFS more than CoreOS
if [[ "${KERNEL_FLAVOR}" =~ "coreos" ]]; then
    install -Dm644 /tmp/certs/public_key.der /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.x509
    install -Dm644 /tmp/certs/private_key.priv /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.pem
    dnf install -y \
        autoconf \
        automake \
        dkms \
        git \
        jq \
        libtool \
        ncompress
fi

# protect against incorrect permissions in tmp dirs which can break akmods builds
chmod 1777 /tmp /var/tmp

# create directories for later copying resulting artifacts
mkdir -p /var/cache/rpms/{kmods,ublue-os,ucore}
