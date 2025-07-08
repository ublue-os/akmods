#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

# ensures we pass a known dir for volume mount of output rpm files
KCWD=/tmp/kernel-cache
find "${KCWD}"

#shellcheck disable=SC2153
kernel_name="${KERNEL_NAME}"
#shellcheck disable=SC2153
kernel_version="${KERNEL_VERSION}"
#shellcheck disable=SC2153
kernel_flavor="${KERNEL_FLAVOR}"
build_tag="${KERNEL_BUILD_TAG:-latest}"

ARCH=$(uname -m)

dnf install -y --setopt=install_weak_deps=False dnf-plugins-core openssl
if [[ "$kernel_flavor" =~ "centos" ]]; then
    CENTOS_VER=$(rpm -E %centos)
    dnf config-manager --set-enabled crb
    dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${CENTOS_VER}.noarch.rpm"
fi
dnf -y install --setopt=install_weak_deps=False rpmrebuild sbsigntools

case "$kernel_flavor" in
    "bazzite"|"centos"*|"coreos"*|"main")
        ;;
    "longterm"*)
        dnf -y copr enable kwizart/kernel-"${kernel_flavor}"
        ;;
    *)
        echo "unexpected kernel_flavor ${kernel_flavor} for query" >&2
        exit 1
        ;;
esac

if [[ "${kernel_flavor}" == "bazzite" ]]; then
    # Using curl for bazzite release
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-core-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-modules-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-modules-core-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-modules-extra-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-devel-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-devel-matched-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-tools-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-tools-libs-"$kernel_version".rpm
    # curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-uki-virt-"$kernel_version".rpm
    # curl -LO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-uki-virt-addons-"$kernel_version".rpm
elif [[ "${kernel_flavor}" == "centos" ]]; then
    # Using curl instead of dnf download for https links
    curl -#fLO https://mirror.stream.centos.org/"$CENTOS_VER"-stream/BaseOS/"$ARCH"/os/Packages/kernel-"$kernel_version".rpm
    curl -#fLO https://mirror.stream.centos.org/"$CENTOS_VER"-stream/BaseOS/"$ARCH"/os/Packages/kernel-core-"$kernel_version".rpm
    curl -#fLO https://mirror.stream.centos.org/"$CENTOS_VER"-stream/BaseOS/"$ARCH"/os/Packages/kernel-modules-"$kernel_version".rpm
    curl -#fLO https://mirror.stream.centos.org/"$CENTOS_VER"-stream/BaseOS/"$ARCH"/os/Packages/kernel-modules-core-"$kernel_version".rpm
    curl -#fLO https://mirror.stream.centos.org/"$CENTOS_VER"-stream/BaseOS/"$ARCH"/os/Packages/kernel-modules-extra-"$kernel_version".rpm
    curl -#fLO https://mirror.stream.centos.org/"$CENTOS_VER"-stream/BaseOS/"$ARCH"/os/Packages/kernel-uki-virt-"$kernel_version".rpm
    curl -#fLO https://mirror.stream.centos.org/"$CENTOS_VER"-stream/AppStream/"$ARCH"/os/Packages/kernel-devel-"$kernel_version".rpm
    curl -#fLO https://mirror.stream.centos.org/"$CENTOS_VER"-stream/AppStream/"$ARCH"/os/Packages/kernel-devel-matched-"$kernel_version".rpm
elif [[ "${kernel_flavor}" == "centos-hsk" ]]; then
    dnf -y install centos-release-hyperscale-kernel
    dnf download -y --enablerepo="centos-hyperscale" \
        kernel-"${kernel_version}" \
        kernel-core-"${kernel_version}" \
        kernel-modules-"${kernel_version}" \
        kernel-modules-core-"${kernel_version}" \
        kernel-modules-extra-"${kernel_version}" \
        kernel-devel-"${kernel_version}" \
        kernel-devel-matched-"${kernel_version}" \
        kernel-uki-virt-"${kernel_version}"
elif [[ "${kernel_flavor}" =~ "longterm" ]]; then
    dnf download -y --enablerepo="copr:copr.fedorainfracloud.org:kwizart:kernel-${kernel_flavor}" \
        kernel-longterm-"${kernel_version}" \
        kernel-longterm-core-"${kernel_version}" \
        kernel-longterm-modules-"${kernel_version}" \
        kernel-longterm-modules-core-"${kernel_version}" \
        kernel-longterm-modules-extra-"${kernel_version}" \
        kernel-longterm-devel-"${kernel_version}" \
        kernel-longterm-devel-matched-"${kernel_version}"
else
    KERNEL_MAJOR_MINOR_PATCH=$(echo "$kernel_version" | cut -d '-' -f 1)
    KERNEL_RELEASE="$(echo "$kernel_version" | cut -d - -f 2 | rev | cut -d . -f 2- | rev)"
    
    # Using curl instead of dnf download for https links
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-"$kernel_version".rpm
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-core-"$kernel_version".rpm
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-modules-"$kernel_version".rpm
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-modules-core-"$kernel_version".rpm
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-modules-extra-"$kernel_version".rpm
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-devel-"$kernel_version".rpm
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-devel-matched-"$kernel_version".rpm
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-uki-virt-"$kernel_version".rpm
fi

if [[ ! -s "${KCWD}"/certs/private_key.priv ]]; then
    echo "WARNING: Using test signing key."
    cp "${KCWD}"/certs/private_key.priv{.test,}
    cp "${KCWD}"/certs/public_key.der{.test,}
fi

trap 'rm -rf "${KCWD}/certs" /etc/pki/kernel/private/private_key*.priv /etc/pki/kernel/public/public_key*.crt' EXIT SIGINT

PUBLIC_KEY_PATH="/etc/pki/kernel/public/public_key.crt"
PRIVATE_KEY_PATH="/etc/pki/kernel/private/private_key.priv"

openssl x509 -in "${KCWD}"/certs/public_key.der -out "${KCWD}"/certs/public_key.crt

install -Dm644 "${KCWD}"/certs/public_key.crt "$PUBLIC_KEY_PATH"
install -Dm644 "${KCWD}"/certs/private_key.priv "$PRIVATE_KEY_PATH"

ls -la /
dnf install -y \
    /"${kernel_name}-$kernel_version.rpm" \
    /"${kernel_name}-core-$kernel_version.rpm" \
    /"${kernel_name}-modules-$kernel_version.rpm" \
    /"${kernel_name}-modules-core-$kernel_version.rpm" \
    /"${kernel_name}-modules-extra-$kernel_version.rpm"

# Strip Signatures from non-fedora Kernels
if [[ ${kernel_flavor} =~ main|coreos|centos ]]; then
    echo "Will not strip Fedora/CentOS signature(s) from ${kernel_flavor} kernel."
else
    EXISTING_SIGNATURES="$(sbverify --list /usr/lib/modules/"$kernel_version"/vmlinuz | grep '^signature \([0-9]\+\)$' | sed 's/^signature \([0-9]\+\)$/\1/')" || true
    if [[ -n "$EXISTING_SIGNATURES" ]]; then
        for SIGNUM in $EXISTING_SIGNATURES; do
            echo "Found existing signature at signum $SIGNUM, removing..."
            sbattach --remove /usr/lib/modules/"${kernel_version}"/vmlinuz
        done
    fi
fi

# Sign Kernel with Key
sbsign --cert "$PUBLIC_KEY_PATH" --key "$PRIVATE_KEY_PATH" /usr/lib/modules/"${kernel_version}"/vmlinuz --output /usr/lib/modules/"${kernel_version}"/vmlinuz

# Verify Signatures
sbverify --list /usr/lib/modules/"${kernel_version}"/vmlinuz
if ! sbverify --cert "$PUBLIC_KEY_PATH" /usr/lib/modules/"${kernel_version}"/vmlinuz; then
    exit 1
fi

rm -f "$PRIVATE_KEY_PATH"

if [[ ${DUAL_SIGN:-} == "true" ]]; then
    SECOND_PUBLIC_KEY_PATH="/etc/pki/kernel/public/public_key_2.crt"
    SECOND_PRIVATE_KEY_PATH="/etc/pki/kernel/private/public_key_2.priv"
    if [[ ! -s "${KCWD}"/certs/private_key_2.priv ]]; then
        echo "WARNING: Using test signing key."
        cp "${KCWD}"/certs/private_key_2.priv{.test,}
        cp "${KCWD}"/certs/public_key_2.der{.test,}
        find "${KCWD}"/certs/
    fi
    openssl x509 -in "${KCWD}"/certs/public_key_2.der -out "${KCWD}"/certs/public_key_2.crt
    install -Dm644 "${KCWD}"/certs/public_key_2.crt "$SECOND_PUBLIC_KEY_PATH"
    install -Dm644 "${KCWD}"/certs/private_key_2.priv "$SECOND_PRIVATE_KEY_PATH"
    sbsign --cert "$SECOND_PUBLIC_KEY_PATH" --key "$SECOND_PRIVATE_KEY_PATH" /usr/lib/modules/"${kernel_version}"/vmlinuz --output /usr/lib/modules/"${kernel_version}"/vmlinuz
    sbverify --list /usr/lib/modules/"${kernel_version}"/vmlinuz
    if ! sbverify --cert "$SECOND_PUBLIC_KEY_PATH" /usr/lib/modules/"${kernel_version}"/vmlinuz; then
        exit 1
    fi
    rm -f "$SECOND_PRIVATE_KEY_PATH"
fi

ln -s / /tmp/buildroot

# Rebuild RPMs and Verify
rpmrebuild --additional=--buildroot=/tmp/buildroot --batch "${kernel_name}-core-${kernel_version}"
rm -f /usr/lib/modules/"${kernel_version}"/vmlinuz
find /tmp
find /root
dnf reinstall -y /root/rpmbuild/RPMS/"$(uname -m)"/kernel-*.rpm

# Verify Again
sbverify --list /usr/lib/modules/"${kernel_version}"/vmlinuz
if ! sbverify --cert "$PUBLIC_KEY_PATH" /usr/lib/modules/"${kernel_version}"/vmlinuz; then
    exit 1
fi
if [[ "${DUAL_SIGN:-}" == "true" ]] && ! sbverify --cert "${SECOND_PUBLIC_KEY_PATH:-}" /usr/lib/modules/"${kernel_version}"/vmlinuz; then
    exit 1
fi

# Make Temp Dir
mkdir -p "${KCWD}"/rpms

# Move RPMs over
mv /kernel-*.rpm "${KCWD}"/rpms
if [ -d /root/rpmbuild/RPMS/"$(uname -m)" ]; then
  mv /root/rpmbuild/RPMS/"$(uname -m)"/kernel-*.rpm "${KCWD}"/rpms
fi

# Delete keys in /tmp if we decide to publish this later
rm -rf "${KCWD}"/certs
