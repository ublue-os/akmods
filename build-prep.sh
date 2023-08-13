#!/bin/sh

set -oeux pipefail


### PREPARE REPOS
ARCH="$(rpm -E '%_arch')"
RELEASE="$(rpm -E '%fedora')"

# Modularity repositories are not available on Fedora 39 and above, so don't try to disable them
if [[ "${FEDORA_MAJOR_VERSION}" -le 38 ]]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo
else
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo
fi

wget -P /tmp/rpms \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${RELEASE}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm

# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

rpm-ostree install \
    /tmp/rpms/*.rpm \
    fedora-repos-archive


### PREPARE BUILD ENV
rpm-ostree install \
    akmods \
    mock

if [[ ! -s "/tmp/certs/private_key.priv" ]]; then
    echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
    cp /tmp/certs/private_key.priv{.test,}
    cp /tmp/certs/public_key.der{.test,}
fi

install -Dm644 /tmp/certs/public_key.der   /etc/pki/akmods/certs/public_key.der
install -Dm644 /tmp/certs/private_key.priv /etc/pki/akmods/private/private_key.priv

# protect against incorrect permissions in tmp dirs which can break akmods builds
chmod 1777 /tmp /var/tmp
