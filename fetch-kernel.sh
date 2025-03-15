#!/usr/bin/bash

set -eoux pipefail

# ensures we pass a known dir for volume mount of output rpm files
KCWD=${1}
find "${KCWD}"

kernel_version="${KERNEL_VERSION}"
kernel_flavor="${KERNEL_FLAVOR}"
build_tag="${KERNEL_BUILD_TAG:-latest}"

dnf install -y --setopt=install_weak_deps=False dnf-plugins-core rpmrebuild sbsigntools openssl

case "$kernel_flavor" in
    "asus")
        dnf copr enable -y lukenukem/asus-kernel
        ;;
    "surface")
        if [[ "$(rpm -E %fedora)" -lt 41 ]]; then
            dnf config-manager --add-repo=https://pkg.surfacelinux.com/fedora/linux-surface.repo
        else
            dnf config-manager addrepo --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo
        fi
        ;;
    "coreos-stable")
        ;;
    "coreos-testing")
        ;;
    "bazzite")
        ;;
    "main")
        ;;
    *)
        echo "unexpected kernel_flavor ${kernel_flavor} for query"
        ;;
esac

if [[ "${kernel_flavor}" =~ asus ]]; then
    dnf download -y \
        kernel-"${kernel_version}" \
        kernel-modules-"${kernel_version}" \
        kernel-modules-core-"${kernel_version}" \
        kernel-modules-extra-"${kernel_version}" \
        kernel-devel-"${kernel_version}" \
        kernel-devel-matched-"${kernel_version}" \
        kernel-uki-virt-"${kernel_version}"

elif [[ "${kernel_flavor}" == "surface" ]]; then
    dnf download -y \
        kernel-surface-"${kernel_version}" \
        kernel-surface-modules-"${kernel_version}" \
        kernel-surface-modules-core-"${kernel_version}" \
        kernel-surface-modules-extra-"${kernel_version}" \
        kernel-surface-devel-"${kernel_version}" \
        kernel-surface-devel-matched-"${kernel_version}" \
        kernel-surface-default-watchdog-"${kernel_version}" \
        iptsd \
        libwacom-surface \
        libwacom-surface-data
elif [[ "${kernel_flavor}" == "bazzite" ]]; then
    # Using curl for bazzite release
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-core-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-modules-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-modules-core-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-modules-extra-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-devel-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-devel-matched-"$kernel_version".rpm
    curl -#fLO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-uki-virt-"$kernel_version".rpm
    # curl -LO https://github.com/bazzite-org/kernel-bazzite/releases/download/"$build_tag"/kernel-uki-virt-addons-"$kernel_version".rpm
else
    KERNEL_MAJOR_MINOR_PATCH=$(echo "$kernel_version" | cut -d '-' -f 1)
    KERNEL_RELEASE="$(echo "$kernel_version" | cut -d - -f 2 | rev | cut -d . -f 2- | rev)"
    ARCH=$(uname -m)
    
    # Using curl instead of dnf download for https links
    curl -#fLO https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-"$kernel_version".rpm
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

PUBLIC_KEY_PATH="/etc/pki/kernel/public/public_key.crt"
PRIVATE_KEY_PATH="/etc/pki/kernel/private/private_key.priv"

openssl x509 -in "${KCWD}"/certs/public_key.der -out "${KCWD}"/certs/public_key.crt

install -Dm644 "${KCWD}"/certs/public_key.crt "$PUBLIC_KEY_PATH"
install -Dm644 "${KCWD}"/certs/private_key.priv "$PRIVATE_KEY_PATH"

ls -la /
if [[ "${kernel_flavor}" =~ asus ]]; then
    dnf install -y \
        /kernel-"$kernel_version".rpm \
        /kernel-modules-"$kernel_version".rpm \
        /kernel-modules-core-"$kernel_version".rpm \
        /kernel-modules-extra-"$kernel_version".rpm \
        kernel-core-"${kernel_version}"
elif [[ "${kernel_flavor}" =~ surface ]]; then
    dnf install -y \
        /kernel-surface-"$kernel_version".rpm \
        /kernel-surface-modules-"$kernel_version".rpm \
        /kernel-surface-modules-core-"$kernel_version".rpm \
        /kernel-surface-modules-extra-"$kernel_version".rpm \
        kernel-surface-core-"${kernel_version}"
elif [[ "${kernel_flavor}" == "bazzite" ]]; then
    dnf install -y \
        /kernel-"$kernel_version".rpm \
        /kernel-core-"$kernel_version".rpm \
        /kernel-modules-"$kernel_version".rpm \
        /kernel-modules-core-"$kernel_version".rpm \
        /kernel-modules-extra-"$kernel_version".rpm
else
    dnf install -y \
        /kernel-"$kernel_version".rpm \
        /kernel-modules-"$kernel_version".rpm \
        /kernel-modules-core-"$kernel_version".rpm \
        /kernel-modules-extra-"$kernel_version".rpm \
        https://kojipkgs.fedoraproject.org//packages/kernel/"$KERNEL_MAJOR_MINOR_PATCH"/"$KERNEL_RELEASE"/"$ARCH"/kernel-core-"$kernel_version".rpm
fi

# Strip Signatures from non-fedora Kernels
if [[ ${kernel_flavor} =~ main|coreos ]]; then
    echo "Will not strip Fedora signature(s) from ${kernel_flavor} kernel."
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

rm -f "$PRIVATE_KEY_PATH" "$PUBLIC_KEY_PATH"

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
    rm -f "$SECOND_PRIVATE_KEY_PATH" "$SECOND_PUBLIC_KEY_PATH"
fi

ln -s / /tmp/buildroot

# Rebuild RPMs and Verify
if [[ "${kernel_flavor}" =~ surface ]]; then
    rpmrebuild --additional=--buildroot=/tmp/buildroot --batch kernel-surface-core-"${kernel_version}"
    rm -f /usr/lib/modules/"${kernel_version}"/vmlinuz
    dnf reinstall -y \
        /kernel-surface-"$kernel_version".rpm \
        /kernel-surface-modules-"$kernel_version".rpm \
        /kernel-surface-modules-core-"$kernel_version".rpm \
        /kernel-surface-modules-extra-"$kernel_version".rpm \
        /root/rpmbuild/RPMS/"$(uname -m)"/kernel-*.rpm
else
    rpmrebuild --additional=--buildroot=/tmp/buildroot --batch kernel-core-"${kernel_version}"
    rm -f /usr/lib/modules/"${kernel_version}"/vmlinuz
    find /tmp
    find /root
    dnf reinstall -y \
        /kernel-"$kernel_version".rpm \
        /kernel-modules-"$kernel_version".rpm \
        /kernel-modules-core-"$kernel_version".rpm \
        /kernel-modules-extra-"$kernel_version".rpm \
        /root/rpmbuild/RPMS/"$(uname -m)"/kernel-*.rpm
fi

sbverify --list /usr/lib/modules/"${kernel_version}"/vmlinuz

# Make Temp Dir
mkdir -p "${KCWD}"/rpms

# Move RPMs over
mv /kernel-*.rpm "${KCWD}"/rpms
mv /root/rpmbuild/RPMS/"$(uname -m)"/kernel-*.rpm "${KCWD}"/rpms

if [[ "${kernel_flavor}" =~ surface ]]; then
    cp iptsd-*.rpm libwacom-*.rpm "${KCWD}"/rpms
fi

# Delete keys in /tmp if we decide to publish this later
rm -rf "${KCWD}"/certs
