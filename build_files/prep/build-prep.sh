#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

#shellcheck source-path=SCRIPTDIR
#shellcheck source=dnf-retry.sh
source /tmp/dnf-retry.sh

#shellcheck source=check-signing-key.sh
source /tmp/check-signing-key.sh

### PREPARE REPOS
# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

pushd /tmp/kernel_cache
KERNEL_VERSION=$(find "$KERNEL_NAME"-*.rpm | grep "$(uname -m)" | grep -P "$KERNEL_NAME-\d+\.\d+(\.\d+)?-\w+.*$(rpm -E '%{dist}')" | sed -E "s/$KERNEL_NAME-//;s/\.rpm//")
popd

echo "Building for Fedora"
RELEASE="$(rpm -E '%fedora')"

dnf config-manager setopt fedora-cisco-openh264.enabled=0

RPMFUSION_MIRROR_RPMS="https://download1.rpmfusion.org"
if [ -n "${RPMFUSION_MIRROR}" ]; then
    RPMFUSION_MIRROR_RPMS=${RPMFUSION_MIRROR}
fi
PREP_RPMS+=(
    "${RPMFUSION_MIRROR_RPMS}"/free/fedora/rpmfusion-free-release-"${RELEASE}".noarch.rpm \
    "${RPMFUSION_MIRROR_RPMS}"/nonfree/fedora/rpmfusion-nonfree-release-"${RELEASE}".noarch.rpm \
    fedora-repos-archive
)

# install kernel_cache provided kernel
echo "Installing ${KERNEL_FLAVOR} kernel-cache RPMs..."

# build image has no kernel so this needs nothing fancy, just install, but not UKIs
#shellcheck disable=SC2046 #we want word splitting
dnf_retry install -y --allowerasing --setopt=install_weak_deps=False "${PREP_RPMS[@]}" $(find /tmp/kernel_cache/*.rpm -type f | grep "$(uname -m)" | grep -v uki | xargs)

# after F46 launches, bump to 47
if [[ "${VERSION}" -ge 46 && -f /etc/fedora-release ]]; then
    # pre-release rpmfusion is in a different location
    sed -i "s%free/fedora/releases%free/fedora/development%" /usr/share/dnf5/repos.d/rpmfusion-*.repo
    # pre-release rpmfusion needs to enable testing
    dnf config-manager enable rpmfusion-free-updates-testing rpmfusion-nonfree-updates-testing
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

# The minimal Fedora builder has openssl-libs, but not the openssl executable.
dnf_retry install -y --setopt=install_weak_deps=False openssl
load_signing_keys /tmp/certs "${KSIGN_MODE:-test}"
for id in "${KSIGN_IDS[@]}"; do
    check_signing_key "$KSIGN_DIR/$id.key" "$KSIGN_DIR/$id.der"
done
primary="${KSIGN_IDS[0]}"
install -Dm644 "$KSIGN_DIR/$primary.der" /etc/pki/akmods/certs/public_key.der
install -Dm644 "$KSIGN_DIR/$primary.key" /etc/pki/akmods/private/private_key.priv
RPMS_TO_INSTALL+=(rpmrebuild)

# This is for ZFS more than CoreOS|Longterm
if [[ "${KERNEL_FLAVOR}" =~ "coreos" ]] || [[ "${KERNEL_FLAVOR}" =~ "longterm" ]]; then
    mkdir -p "$(dirname /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.x509)"
    install -Dm644 "$KSIGN_DIR/$primary.der" /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.x509
    install -Dm644 "$KSIGN_DIR/$primary.key" /lib/modules/"${KERNEL_VERSION}"/build/certs/signing_key.pem
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
dnf_retry install -y --allowerasing "${RPMS_TO_INSTALL[@]}"

# Normalize random akmods build roots before linking
original_build_pre="$(rpm --eval '%{macrobody:__spec_build_pre}')"

{
    printf '%%__spec_build_pre '
    printf '%s\n' "$original_build_pre" | sed 's/$/\\/'
    cat <<'EOF'
export KCFLAGS="${KCFLAGS:+${KCFLAGS} }-ffile-prefix-map=$(realpath -m "%{_builddir}")=/usr/src/akmods"
EOF
} > /etc/rpm/macros.akmods-reproducible

# Prepare signer identities and the certificate bundle for module signing.
umask 077
: > /tmp/certs/signing-chain.pem
for id in "${KSIGN_IDS[@]}"; do
    openssl x509 -in "$KSIGN_DIR/$id.der" -out "/tmp/certs/$id.crt"
    cat "$KSIGN_DIR/$id.key" "/tmp/certs/$id.crt" > "/tmp/certs/$id.pem"
    cat "/tmp/certs/$id.crt" >> /tmp/certs/signing-chain.pem
done
printf '%s\n' "${KSIGN_IDS[@]}" > /tmp/certs/active-signing-keys
umask 022

# Install FPM
gem install fpm

# protect against incorrect permissions in tmp dirs which can break akmods builds
chmod 1777 /tmp /var/tmp

# create directories for later copying resulting artifacts
mkdir -p /var/cache/rpms/{kmods,ublue-os,ucore}
