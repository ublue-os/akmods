#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

pushd /tmp/kernel_cache
KERNEL_VERSION=$(find "$KERNEL_NAME"-*.rpm | grep "$(uname -m)" | grep -P "$KERNEL_NAME-\d+\.\d+\.\d+-\w+.*$(rpm -E '%{dist}')" | sed -E "s/$KERNEL_NAME-//;s/\.rpm//")
popd

### PREPARE REPOS
RPM_PREP=(openssl)
if [[ "${KERNEL_FLAVOR}" =~ "centos" ]]; then
    echo "Building for CentOS"
    RELEASE="$(rpm -E '%centos')"
    mkdir -p /var/roothome
    dnf config-manager --set-enabled crb
else
    echo "Building for Fedora"
    RELEASE="$(rpm -E '%fedora')"
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo
    dnf config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo
fi

# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

if [[ -f $(find /tmp/akmods-rpms/ublue-os/ublue-os-*.rpm 2> /dev/null) ]]; then
    RPM_PREP+=(/tmp/akmods-rpms/ublue-os/ublue-os-*.rpm)
fi

# install kernel_cache provided kernel
echo "Installing ${KERNEL_FLAVOR} kernel-cache RPMs..."
# fedora image has no kernel so this needs nothing fancy, just install
#shellcheck disable=SC2046 # We want word splitting
dnf install -y --setopt=install_weak_deps=False "${RPM_PREP[@]}" $(find /tmp/kernel_cache/*.rpm -type f | grep "$(uname -m)" | grep -v uki)

# after F45 launches, bump to 46
if [[ "${RELEASE}" -ge 45 && -f /etc/fedora-release ]]; then
    # pre-release rpmfusion is in a different location
    sed -i "s%free/fedora/releases%free/fedora/development%" /etc/yum.repos.d/rpmfusion-*.repo
    # pre-release rpmfusion needs to enable testing
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/rpmfusion-*-updates-testing.repo
fi

if [[ -f $(find /tmp/akmods-rpms/kmods/kmod-nvidia-*.rpm) ]]; then
    curl -Lo /etc/yum.repos.d/nvidia-container.pp \
        "https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp"
fi

if [[ ! -s "/tmp/certs/private_key.priv" ]]; then
    echo "WARNING: Using test signing key."
    cp /tmp/certs/public_key.der{.test,}
fi

openssl x509 -in /tmp/certs/public_key.der -out /tmp/certs/public_key.crt
cat /tmp/certs/public_key.crt > /tmp/certs/public_key_chain.pem
rm -f /tmp/certs/private_key.priv

if [[ "${DUAL_SIGN}" == "true" ]]; then
    if [[ ! -s "/tmp/certs/private_key_2.priv" ]]; then
        echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
        cp /tmp/certs/public_key_2.der{.test,}
    fi
    openssl x509 -in /tmp/certs/public_key_2.der -out /tmp/certs/public_key_2.crt
    rm -f /tmp/certs/public_key_chain.pem
    cat /tmp/certs/public_key.crt <(echo) /tmp/certs/public_key_2.crt >> /tmp/certs/public_key_chain.pem
fi

rm -f /tmp/certs/private_key_2.priv

if [[ -f $(find /tmp/akmods-rpms/kmods/kmod-nvidia-*.rpm 2> /dev/null) ]]; then
    #shellcheck disable=SC1091
    source /tmp/akmods-rpms/kmods/nvidia-vars
    KMODS_TO_INSTALL+=(
        /tmp/akmods-rpms/nvidia/*.rpm
        /tmp/akmods-rpms/kmods/kmod-nvidia-"${KERNEL_VERSION}"-"${NVIDIA_AKMOD_VERSION}"."${DIST_ARCH}".rpm
    )
elif [[ -f $(find /tmp/akmods-rpms/kmods/zfs/kmod-*.rpm 2> /dev/null) ]]; then
    KMODS_TO_INSTALL+=(
        /tmp/akmods-rpms/kmods/zfs/*.rpm
    )
elif [[ -d /tmp/akmods-rpms/extra ]]; then
    KMODS_TO_INSTALL+=(
        /tmp/akmods-rpms/kmods/*.rpm
        /tmp/akmods-rpms/extra/*.rpm
    )
else
    KMODS_TO_INSTALL+=(
        /tmp/akmods-rpms/kmods/*.rpm
        /tmp/akmods-rpms/common/*.rpm
    )
fi

dnf install -y --setopt=install_weak_deps=False --allowerasing "${KMODS_TO_INSTALL[@]}"

printf "KERNEL_NAME=%s" "$KERNEL_NAME" >> /tmp/info.sh
