#!/usr/bin/bash

set -oeux pipefail

### PREPARE REPOS
# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

# ARCH="$(rpm -E '%_arch')"
if [[ "${KERNEL_FLAVOR}" =~ "centos" ]]; then
    echo "Building for CentOS"
    RELEASE="$(rpm -E '%centos')"

    mkdir -p /var/roothome

    dnf remove -y subscription-manager
    dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RELEASE}.noarch.rpm"
    dnf config-manager --set-enabled crb
else
    echo "Building for Fedora"
    RELEASE="$(rpm -E '%fedora')"

    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

    RPMFUSION_MIRROR_RPMS="https://mirrors.rpmfusion.org"
    if [ -n "${RPMFUSION_MIRROR}" ]; then
        RPMFUSION_MIRROR_RPMS=${RPMFUSION_MIRROR}
    fi
    dnf install -y \
        "${RPMFUSION_MIRROR_RPMS}"/free/fedora/rpmfusion-free-release-"${RELEASE}".noarch.rpm \
        "${RPMFUSION_MIRROR_RPMS}"/nonfree/fedora/rpmfusion-nonfree-release-"${RELEASE}".noarch.rpm \
        fedora-repos-archive

    # after F43 launches, bump to 44
    if [[ "${FEDORA_MAJOR_VERSION}" -ge 43 ]]; then
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
fi

# install kernel_cache provided kernel
echo "Installing ${KERNEL_FLAVOR} kernel-cache RPMs..."

# build image has no kernel so this needs nothing fancy, just install, but not UKIs
dnf install -y `find /tmp/kernel_cache/*.rpm -type f | grep -v uki | xargs`
KERNEL_VERSION=$(rpm -q "${KERNEL_NAME}" | cut -d '-' -f2-)

### PREPARE BUILD ENV
dnf install -y \
    akmods \
    mock \
    ruby-devel

gem install fpm

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

# This is for ZFS more than CentOS|CoreOS
if [[ "${KERNEL_FLAVOR}" =~ "centos" ]] || [[ "${KERNEL_FLAVOR}" =~ "coreos" ]]; then
    install -Dm644 /tmp/certs/public_key.der /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.x509
    install -Dm644 /tmp/certs/private_key.priv /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.pem
    dnf install -y \
        autoconf \
        automake \
        dkms \
        git \
        jq \
        libtool \
        ncompress \
        python-cffi
fi

# protect against incorrect permissions in tmp dirs which can break akmods builds
chmod 1777 /tmp /var/tmp

# create directories for later copying resulting artifacts
mkdir -p /var/cache/rpms/{kmods,ublue-os,ucore}
