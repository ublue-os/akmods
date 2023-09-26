#!/bin/sh

set -oeux pipefail


### PREPARE REPOS
ARCH="$(rpm -E '%_arch')"
RELEASE="$(rpm -E '%fedora')"

# Modularity repositories are not available on Fedora 39 and above, so don't try to disable them
if [[ "${RELEASE}" -le 38 ]]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-{cisco-openh264,modular,updates-modular}.repo
else
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo
fi

# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

# enable more repos
rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${RELEASE}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm \
    fedora-repos-archive

# force use of single rpmfusion mirror
sed -i.bak 's%^metalink=%#metalink=%' /etc/yum.repos.d/rpmfusion-*.repo
sed -i 's%^#baseurl=http://download1.rpmfusion.org%baseurl=http://mirrors.ocf.berkeley.edu/rpmfusion%' /etc/yum.repos.d/rpmfusion-*.repo
# after F39 launches, bump to 40
if [[ "${FEDORA_MAJOR_VERSION}" -ge 39 ]]; then
    sed -i 's%free/fedora/releases%free/fedora/development%' /etc/yum.repos.d/rpmfusion-*.repo
fi


### PREPARE CUSTOM KERNEL SUPPORT
if [[ "asus" == "${KERNEL_FLAVOR}" ]]; then
    echo "Installing ASUS Kernel:"
    wget https://copr.fedorainfracloud.org/coprs/lukenukem/asus-kernel/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-kernel-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_lukenukem-asus-kernel.repo
    rpm-ostree cliwrap install-to-root /
    rpm-ostree override replace \
    --experimental \
    --from repo=copr:copr.fedorainfracloud.org:lukenukem:asus-kernel \
        kernel \
        kernel-core \
        kernel-devel \
        kernel-devel-matched \
        kernel-modules \
        kernel-modules-core \
        kernel-modules-extra
elif [[ "surface" == "${KERNEL_FLAVOR}" ]]; then
    echo "Installing Surface Kernel:"
    # Add Linux Surface repo
    wget https://pkg.surfacelinux.com/fedora/linux-surface.repo -P /etc/yum.repos.d
    wget https://github.com/linux-surface/linux-surface/releases/download/silverblue-20201215-1/kernel-20201215-1.x86_64.rpm -O \
    /tmp/surface-kernel.rpm
    rpm-ostree cliwrap install-to-root /
    rpm-ostree override replace /tmp/surface-kernel.rpm \
        --remove kernel-core \
        --remove kernel-modules \
        --remove kernel-modules-extra \
        --install kernel-surface \
        --install kernel-surface-core \
        --install kernel-surface-devel \
        --install kernel-surface-devel-matched \
        --install kernel-surface-modules \
        --install kernel-surface-modules-core \
        --install kernel-surface-modules-extra
else
    echo "Default main kernel needs no customization."
fi


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

# create directories for later copying resulting artifacts
mkdir -p /var/cache/rpms/{kmods,ublue-os}
