#!/usr/bin/bash

set -oeux pipefail

### PREPARE REPOS
# ARCH="$(rpm -E '%_arch')"
RELEASE="$(rpm -E '%fedora')"

sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

if [[ -f $(find /tmp/akmods-rpms/ublue-os/ublue-os-*.rpm 2> /dev/null) ]]; then
    dnf install -y /tmp/akmods-rpms/ublue-os/ublue-os-*.rpm
fi


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

if [[ "${RELEASE}" -ge 41 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

curl -Lo /etc/yum.repos.d/_copr_ublue-os_staging.repo \
    "https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-${COPR_RELEASE}/ublue-os-staging-fedora-${COPR_RELEASE}.repo"

curl -Lo /etc/yum.repos.d/_copr_kylegospo_oversteer.repo \
    "https://copr.fedorainfracloud.org/coprs/kylegospo/oversteer/repo/fedora-${COPR_RELEASE}/kylegospo-oversteer-fedora-${COPR_RELEASE}.repo"

curl -Lo /etc/yum.repos.d/_copr_ublue-os-akmods.repo \
    "https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/repo/fedora-${COPR_RELEASE}/ublue-os-akmods-fedora-${COPR_RELEASE}.repo"

curl -Lo /etc/yum.repos.d/negativo17-fedora-multimedia.repo \
    "https://negativo17.org/repos/fedora-multimedia.repo"

if [[ -f $(find /tmp/akmods-rpms/kmods/kmod-vhba-*.rpm) ]]; then
curl -LsSf -o /etc/yum.repos.d/_copr_rok-cdemu.repo \
    "https://copr.fedorainfracloud.org/coprs/rok/cdemu/repo/fedora-${COPR_RELEASE}/rok-cdemu-fedora-${COPR_RELEASE}.repo"
fi

if [[ -f $(find /tmp/akmods-rpms/kmods/kmod-facetimehd-*.rpm) ]]; then
curl -LsSf -o /etc/yum.repos.d/_copr_mulderje-facetimehd-kmod.repo \
    "https://copr.fedorainfracloud.org/coprs/mulderje/facetimehd-kmod/repo/fedora-${COPR_RELEASE}/mulderje-facetimehd-kmod-fedora-${COPR_RELEASE}.repo"
fi

if [[ -f $(find /tmp/akmods-rpms/kmods/kmod-kvmfr-*.rpm) ]]; then
curl -LsSf -o /etc/yum.repos.d/_copr_hikariknight-looking-glass-kvmfr.repo \
    "https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/repo/fedora-${COPR_RELEASE}/hikariknight-looking-glass-kvmfr-fedora-${COPR_RELEASE}.repo"
fi

if [[ -f $(find /tmp/akmods-rpms/kmods/kmod-system76-io-*.rpm) ]]; then
curl -LsSf -o /etc/yum.repos.d/_copr_ssweeny-system76-io.repo \
    "https://copr.fedorainfracloud.org/coprs/ssweeny/system76-hwe/repo/fedora-${COPR_RELEASE}/ssweeny-system76-hwe-fedora-${COPR_RELEASE}.repo"
fi

if [[ -f $(find /tmp/akmods-rpms/kmods/kmod-nvidia-*.rpm) ]]; then
    curl -Lo /etc/yum.repos.d/negativo17-fedora-nvidia.repo \
        "https://negativo17.org/repos/fedora-nvidia.repo"
    curl -Lo /etc/yum.repos.d/nvidia-container-toolkit.repo \
        "https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo"
    curl -Lo /etc/yum.repos.d/nvidia-container.pp \
        "https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp"
    curl -Lo /tmp/nvidia-install.sh \
        "https://raw.githubusercontent.com/ublue-os/hwe/main/nvidia-install.sh"
    chmod +x /tmp/nvidia-install.sh
    sed -i "s@gpgcheck=0@gpgcheck=1@" /etc/yum.repos.d/nvidia-container-toolkit.repo
fi

dnf install -y \
    "${RPMFUSION_MIRROR_RPMS}"/free/fedora/rpmfusion-free-release-"${RELEASE}".noarch.rpm \
    "${RPMFUSION_MIRROR_RPMS}"/nonfree/fedora/rpmfusion-nonfree-release-"${RELEASE}".noarch.rpm \
    fedora-repos-archive \
    openssl


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

if [[ ! -s "/tmp/certs/private_key.priv" ]]; then
    echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
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
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/negativo17-fedora-nvidia.repo
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/nvidia-container-toolkit.repo
    source /tmp/akmods-rpms/kmods/nvidia-vars
    dnf install -y \
        libnvidia-fbc \
        libnvidia-ml.i686 \
        libva-nvidia-driver \
        mesa-vulkan-drivers.i686 \
        nvidia-driver \
        nvidia-driver-cuda \
        nvidia-driver-cuda-libs.i686 \
        nvidia-driver-libs.i686 \
        nvidia-modprobe \
        nvidia-persistenced \
        nvidia-settings \
        nvidia-container-toolkit \
        /tmp/akmods-rpms/kmods/kmod-nvidia-"${KERNEL_VERSION}"-"${NVIDIA_AKMOD_VERSION}".fc"${RELEASE}".rpm
elif [[ -f $(find /tmp/akmods-rpms/kmods/zfs/kmod-*.rpm 2> /dev/null) ]]; then
    dnf install -y \
        pv \
        /tmp/akmods-rpms/kmods/zfs/*.rpm
else
    dnf install -y \
        /tmp/akmods-rpms/kmods/*.rpm
fi

printf "KERNEL_NAME=%s" "$KERNEL_NAME" >> /tmp/info.sh
