#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

#shellcheck source-path=SCRIPTDIR
#shellcheck source=build_files/prep/dnf-retry.sh
source /tmp/kernel-cache/dnf-retry.sh

#shellcheck source=build_files/prep/check-signing-key.sh
source /tmp/kernel-cache/check-signing-key.sh

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

dnf_retry install -y --setopt=install_weak_deps=False dnf-plugins-core openssl
dnf_retry -y install --setopt=install_weak_deps=False dracut rpmrebuild sbsigntools

case "$kernel_flavor" in
    "coreos"*|"main")
        ;;
    "longterm"*)
        dnf -y copr enable kwizart/kernel-"${kernel_flavor}"
        ;;
    "ogc"|"ogc-lts")
        ;;
    *)
        echo "unexpected kernel_flavor ${kernel_flavor} for query" >&2
        exit 1
        ;;
esac

if [[ "${kernel_flavor}" =~ "longterm" ]]; then
    dnf_retry download -y --enablerepo="copr:copr.fedorainfracloud.org:kwizart:kernel-${kernel_flavor}" \
        kernel-longterm-"${kernel_version}" \
        kernel-longterm-core-"${kernel_version}" \
        kernel-longterm-modules-"${kernel_version}" \
        kernel-longterm-modules-core-"${kernel_version}" \
        kernel-longterm-modules-extra-"${kernel_version}" \
        kernel-longterm-devel-"${kernel_version}" \
        kernel-longterm-devel-matched-"${kernel_version}"
elif [[ "${kernel_flavor}" =~ ^ogc ]]; then
    ogc_image="${OGC_IMAGE:?OGC_IMAGE env var must be set}"
    dnf_retry install -y --setopt=install_weak_deps=False jq skopeo

    # Fetch the OCI artifact and parse its manifest for kernel RPM filenames
    tmpdir=$(mktemp -d)
    skopeo copy "docker://${ogc_image}" "dir:${tmpdir}"
    manifest=$(<"${tmpdir}/manifest.json")
    needed_prefixes="^kernel-[0-9]+\.[0-9]|^kernel-core-|^kernel-devel-|^kernel-devel-matched-|^kernel-modules-[0-9]"

    while read -r layer; do
        title=$(echo "$layer" | jq -r '.annotations["org.opencontainers.image.title"]')
        digest=$(echo "$layer" | jq -r '.digest')
        if echo "$title" | grep -qE "$needed_prefixes"; then
            echo "Fetching ${title}..."
            blob_path="${tmpdir}/${digest#*:}"
            # Layer may be a tar wrapping the RPM, or the RPM itself
            if file "$blob_path" | grep -q "POSIX tar"; then
                tar xf "$blob_path" -C /
            else
                mv "$blob_path" "/${title}"
            fi
        fi
    done < <(echo "$manifest" | jq -c '.layers[]')
    rm -rf "$tmpdir"
else
    KERNEL_MAJOR_MINOR_PATCH=$(echo "$kernel_version" | cut -d '-' -f 1)
    KERNEL_RELEASE="$(echo "$kernel_version" | cut -d - -f 2 | rev | cut -d . -f 2- | rev)"
    BASE_URL="https://kojipkgs.fedoraproject.org//packages/kernel/${KERNEL_MAJOR_MINOR_PATCH}/${KERNEL_RELEASE}/${ARCH}"
    # Using curl instead of dnf download for https links
    for pkg in \
        kernel \
        kernel-core \
        kernel-modules \
        kernel-modules-core \
        kernel-modules-extra \
        kernel-devel \
        kernel-devel-matched \
        kernel-uki-virt; do
        curl -#fLO "${BASE_URL}/${pkg}-${kernel_version}.rpm"
    done
fi

trap 'rm -rf "${KCWD}/certs"' EXIT SIGINT
load_signing_keys "${KCWD}/certs" "${KSIGN_MODE:-test}"
for id in "${KSIGN_IDS[@]}"; do
    check_signing_key "$KSIGN_DIR/$id.key" "$KSIGN_DIR/$id.der"
    openssl x509 -in "$KSIGN_DIR/$id.der" -out "${KCWD}/certs/$id.crt"
done

ls -la /
if [[ "${kernel_flavor}" =~ ^ogc ]]; then
  dnf_retry install -y \
      /"${kernel_name}-$kernel_version.rpm" \
      /"${kernel_name}-core-$kernel_version.rpm" \
      /"${kernel_name}-modules-$kernel_version.rpm"
else
  dnf_retry install -y \
      /"${kernel_name}-$kernel_version.rpm" \
      /"${kernel_name}-core-$kernel_version.rpm" \
      /"${kernel_name}-modules-$kernel_version.rpm" \
      /"${kernel_name}-modules-core-$kernel_version.rpm" \
      /"${kernel_name}-modules-extra-$kernel_version.rpm"
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

# Sign and verify the kernel against each active certificate.
for id in "${KSIGN_IDS[@]}"; do
    sbsign --cert "${KCWD}/certs/$id.crt" --key "$KSIGN_DIR/$id.key" /usr/lib/modules/"${kernel_version}"/vmlinuz --output /usr/lib/modules/"${kernel_version}"/vmlinuz
done
sbverify --list /usr/lib/modules/"${kernel_version}"/vmlinuz
for id in "${KSIGN_IDS[@]}"; do
    sbverify --cert "${KCWD}/certs/$id.crt" /usr/lib/modules/"${kernel_version}"/vmlinuz
done

ln -s / /tmp/buildroot

# Rebuild RPMs and Verify
rpmrebuild --notest-install --additional=--buildroot=/tmp/buildroot --batch "${kernel_name}-core-${kernel_version}"
rm -f /usr/lib/modules/"${kernel_version}"/vmlinuz
find /tmp
find /root
dnf_retry reinstall -y /root/rpmbuild/RPMS/"$(uname -m)"/kernel-*.rpm

# Verify the rebuilt RPM still carries every signature.
sbverify --list /usr/lib/modules/"${kernel_version}"/vmlinuz
for id in "${KSIGN_IDS[@]}"; do
    sbverify --cert "${KCWD}/certs/$id.crt" /usr/lib/modules/"${kernel_version}"/vmlinuz
done

# Make Temp Dir
mkdir -p "${KCWD}"/rpms

# Move RPMs over
mv /kernel-*.rpm "${KCWD}"/rpms
if [ -d /root/rpmbuild/RPMS/"$(uname -m)" ]; then
  mv /root/rpmbuild/RPMS/"$(uname -m)"/kernel-*.rpm "${KCWD}"/rpms
fi

# Delete keys in /tmp if we decide to publish this later
rm -rf "${KCWD}"/certs
