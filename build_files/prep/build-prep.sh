#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

### PREPARE REPOS
# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

pushd /tmp/kernel_cache
KERNEL_VERSION=$(find "$KERNEL_NAME"-*.rpm | grep "$(uname -m)" | grep -P "$KERNEL_NAME-\d+\.\d+(\.\d+)?-\w+.*$(rpm -E '%{dist}')" | sed -E "s/$KERNEL_NAME-//;s/\.rpm//")
popd

if [[ "${KERNEL_FLAVOR}" =~ centos|ogc-el10 ]]; then
    echo "Building for CentOS"
    RELEASE="$(rpm -E '%centos')"

    mkdir -p /var/roothome
    PREP_RPMS+=("https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RELEASE}.noarch.rpm")
    dnf config-manager --set-enabled crb

    # stage a distro-matched ublue akmods COPR repo so the addons RPM and common
    # kmods can consume EL packages as soon as they are published to the chroot
    mkdir -p /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES
    cat > /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo <<EOF
[copr:copr.fedorainfracloud.org:ublue-os:akmods]
name=COPR (ublue-os/akmods)
baseurl=https://download.copr.fedorainfracloud.org/results/ublue-os/akmods/epel-${RELEASE}-$(rpm -E '%{_arch}')/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/ublue-os/akmods/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

    # stage the EL variant of negativo17 multimedia under the same filename the
    # Fedora build ADDs; scripts and the addons spec consume it unmodified
    curl -LsSf https://negativo17.org/repos/epel-multimedia.repo \
        -o /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-multimedia.repo

    # enable Terra EL for modules it packages for CentOS Stream (gaming/peripherals)
    # repo_gpgcheck=0: dnf5 cannot interactively confirm the repomd key in image
    # builds; package integrity is still enforced via gpgcheck against the
    # Terra EL key imported below
    curl -LsSf "https://raw.githubusercontent.com/terrapkg/packages/el${RELEASE}/anda/terra/release/terra.repo" \
    | sed 's/^repo_gpgcheck=1/repo_gpgcheck=0/' \
        > /etc/yum.repos.d/terra.repo
    curl -LsSf "https://raw.githubusercontent.com/terrapkg/packages/el${RELEASE}/anda/terra/gpg-keys/RPM-GPG-KEY-terrael${RELEASE}" \
        -o "/etc/pki/rpm-gpg/RPM-GPG-KEY-terrael${RELEASE}"
    rpmkeys --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-terrael${RELEASE}"
    # also stage it where extra kmod scripts copy their repo files from
    cp /etc/yum.repos.d/terra.repo /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/terra.repo
else
    echo "Building for Fedora"
    RELEASE="$(rpm -E '%fedora')"

    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

    RPMFUSION_MIRROR_RPMS="https://mirrors.rpmfusion.org"
    if [ -n "${RPMFUSION_MIRROR}" ]; then
        RPMFUSION_MIRROR_RPMS=${RPMFUSION_MIRROR}
    fi
    PREP_RPMS+=(
        "${RPMFUSION_MIRROR_RPMS}"/free/fedora/rpmfusion-free-release-"${RELEASE}".noarch.rpm \
        "${RPMFUSION_MIRROR_RPMS}"/nonfree/fedora/rpmfusion-nonfree-release-"${RELEASE}".noarch.rpm \
        fedora-repos-archive
    )

fi

# install kernel_cache provided kernel
echo "Installing ${KERNEL_FLAVOR} kernel-cache RPMs..."

# build image has no kernel so this needs nothing fancy, just install, but not UKIs
#shellcheck disable=SC2046 #we want word splitting
dnf install -y --allowerasing --setopt=install_weak_deps=False "${PREP_RPMS[@]}" $(find /tmp/kernel_cache/*.rpm -type f | grep "$(uname -m)" | grep -v uki | xargs)

# after F45 launches, bump to 46
if [[ "${VERSION}" -ge 45 && -f /etc/fedora-release ]]; then
    # pre-release rpmfusion is in a different location
    sed -i "s%free/fedora/releases%free/fedora/development%" /etc/yum.repos.d/rpmfusion-*.repo
    # pre-release rpmfusion needs to enable testing
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/rpmfusion-*-updates-testing.repo
fi

if [[ -n "${RPMFUSION_MIRROR}" && -f /etc/fedora-release ]]; then
    # force use of single rpmfusion mirror
    echo "Using single rpmfusion mirror: ${RPMFUSION_MIRROR}"
    sed -i.bak "s%^metalink=%#metalink=%" /etc/yum.repos.d/rpmfusion-*.repo
    sed -i "s%^#baseurl=http://download1.rpmfusion.org%baseurl=${RPMFUSION_MIRROR}%" /etc/yum.repos.d/rpmfusion-*.repo
fi

### PREPARE BUILD ENV
RPMS_TO_INSTALL+=(
    akmods
    gcc-c++
    mock
    ruby-devel
)

if [[ ! -s "/tmp/certs/private_key.priv" ]]; then
    echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
    cp /tmp/certs/private_key.priv{.test,}
    cp /tmp/certs/public_key.der{.test,}
fi

install -Dm644 /tmp/certs/public_key.der   /etc/pki/akmods/certs/public_key.der
install -Dm644 /tmp/certs/private_key.priv /etc/pki/akmods/private/private_key.priv

if [[ "${DUAL_SIGN}" == "true" ]]; then
    RPMS_TO_INSTALL+=(rpmrebuild)
fi

# This is for ZFS more than CentOS|CoreOS
if [[ "${KERNEL_FLAVOR}" =~ centos|ogc-el10|coreos|longterm ]]; then
    mkdir -p "$(dirname /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.x509)"
    install -Dm644 /tmp/certs/public_key.der /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.x509
    install -Dm644 /tmp/certs/private_key.priv /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.pem
    RPMS_TO_INSTALL+=(
        autoconf
        automake
        dkms
        git
        jq
        libtool
        ncompress
        python-cffi
    )
fi
if [[ "${KERNEL_FLAVOR}" =~ "coreos" ]] || [[ "${KERNEL_FLAVOR}" =~ "longterm" ]]; then
    # this seems to be needed on longterm builds but is already present on CoreOS, too
    RPMS_TO_INSTALL+=(libatomic)
fi

# Install RPMs
dnf install -y --allowerasing "${RPMS_TO_INSTALL[@]}"

# Configure Dual Signing
if [[ "${DUAL_SIGN}" == 'true' ]]; then
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

# Install FPM
gem install fpm

# protect against incorrect permissions in tmp dirs which can break akmods builds
chmod 1777 /tmp /var/tmp

# create directories for later copying resulting artifacts
mkdir -p /var/cache/rpms/{kmods,ublue-os,ucore}
