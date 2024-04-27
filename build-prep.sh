#!/bin/sh

set -oeux pipefail


### PREPARE REPOS
ARCH="$(rpm -E '%_arch')"
RELEASE="$(rpm -E '%fedora')"

sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

# enable more repos
RPMFUSION_MIRROR_RPMS="https://mirrors.rpmfusion.org"
if [ -n "${RPMFUSION_MIRROR}" ]; then
    RPMFUSION_MIRROR_RPMS=${RPMFUSION_MIRROR}
fi
rpm-ostree install \
    ${RPMFUSION_MIRROR_RPMS}/free/fedora/rpmfusion-free-release-${RELEASE}.noarch.rpm \
    ${RPMFUSION_MIRROR_RPMS}/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm \
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

# required for main and surface when fedora repo has updated kernel beyond what was in the image
curl -L -o /etc/yum.repos.d/fedora-coreos-pool.repo \
    https://raw.githubusercontent.com/coreos/fedora-coreos-config/testing-devel/fedora-coreos-pool.repo

### PREPARE CUSTOM KERNEL SUPPORT
if [[ "asus" == "${KERNEL_FLAVOR}" ]]; then
    echo "Installing ASUS Kernel:"
    curl -L -o /etc/yum.repos.d/_copr_lukenukem-asus-kernel.repo \
        https://copr.fedorainfracloud.org/coprs/lukenukem/asus-kernel/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-kernel-fedora-$(rpm -E %fedora).repo
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
elif [[ "fsync-lts" == "${KERNEL_FLAVOR}" ]]; then
    echo "Installing fsync-lts kernel:"
    curl -L -o /etc/yum.repos.d/_copr_sentry-kernel-ba.repo \
        https://copr.fedorainfracloud.org/coprs/sentry/kernel-ba/repo/fedora-$(rpm -E %fedora)/sentry-kernel-ba-fedora-$(rpm -E %fedora).repo
    rpm-ostree cliwrap install-to-root /
    rpm-ostree override replace \
    --experimental \
    --from repo=copr:copr.fedorainfracloud.org:sentry:kernel-ba \
        kernel \
        kernel-core \
        kernel-devel \
        kernel-devel-matched \
        kernel-modules \
        kernel-modules-core \
        kernel-modules-extra
elif [[ "fsync" == "${KERNEL_FLAVOR}" ]]; then
    echo "Installing fsync kernel:"
    curl -L -o /etc/yum.repos.d/_copr_sentry-kernel-fsync.repo \
        https://copr.fedorainfracloud.org/coprs/sentry/kernel-fsync/repo/fedora-$(rpm -E %fedora)/sentry-kernel-fsync-fedora-$(rpm -E %fedora).repo
    rpm-ostree cliwrap install-to-root /
    rpm-ostree override replace \
    --experimental \
    --from repo=copr:copr.fedorainfracloud.org:sentry:kernel-fsync \
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
    curl -L -o /etc/yum.repos.d/linux-surface.repo \
        https://pkg.surfacelinux.com/fedora/linux-surface.repo
    curl -L -o /tmp/surface-kernel.rpm \
        https://github.com/linux-surface/linux-surface/releases/download/silverblue-20201215-1/kernel-20201215-1.x86_64.rpm
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
elif [[ "main" == "${KERNEL_FLAVOR}" ]] && \
     [[ "" != "${KERNEL_VERSION}" ]]; then
    echo "main kernel version ${KERNEL_VERSION} to avoid upgrading kernel beyond what is in the image."
    rpm-ostree cliwrap install-to-root /
    rpm-ostree install \
        kernel-devel-${KERNEL_VERSION} \
        kernel-devel-matched-${KERNEL_VERSION}
else
    echo "Default main kernel without a specific version."
    rpm-ostree install \
        kernel-devel \
        kernel-devel-matched
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
