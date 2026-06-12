#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

# TUXEDO laptop platform drivers, built straight from upstream as an akmod.
#
# Upstream (the only maintained source) is TUXEDO's GitLab. Everything needed to
# build the kmod is generated in this script: we fetch the release tarball and
# generate the akmod + common spec files inline, so there is no dependency on any
# third-party COPR/Terra package or external spec repo.
#
# Bump this to update the drivers. Tags: https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers/-/tags
# renovate: datasource=gitlab-tags depName=tuxedocomputers/development/packages/tuxedo-drivers registryUrl=https://gitlab.com
TUXEDO_DRIVERS_VERSION="4.22.2"

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

# TUXEDO devices are x86_64 laptops; the drivers use x86 port-IO / WMI / ACPI and
# do not build on other arches. Skip cleanly so aarch64 common builds still pass.
if [[ "${ARCH}" != "x86_64" ]]; then
    echo "Skipping tuxedo-drivers on ${ARCH}"
    exit 0
fi

KMOD_NAME="tuxedo-drivers"
TOPDIR="/tmp/tuxedo-drivers/rpmbuild"
SRC_DIR="tuxedo-drivers-v${TUXEDO_DRIVERS_VERSION}"
SRC_TARBALL="${SRC_DIR}.tar.gz"
SRC_URL="https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers/-/archive/v${TUXEDO_DRIVERS_VERSION}/${SRC_TARBALL}"
# rpm changelog dates must be English (Fri Jun 12 2026); force the C locale.
BUILD_DATE="$(LC_ALL=C date '+%a %b %d %Y')"

mkdir -p "${TOPDIR}"/{SOURCES,SPECS,BUILD,BUILDROOT,RPMS,SRPMS}

### Fetch source straight from TUXEDO upstream
curl -LsSf -o "${TOPDIR}/SOURCES/${SRC_TARBALL}" "${SRC_URL}"

### Generate the akmod spec (kmodtool driven).
# Notes on the fixes vs. the reference projects this is based on:
#   * kmodtool is given the *short* kmod name (tuxedo-drivers), so the packages
#     are akmod-tuxedo-drivers / kmod-tuxedo-drivers (not the doubled
#     -kmod-kmod suffix the references produced, which broke installation).
#   * The modules are spread over many sub-directories, so we collect every .ko
#     with `find` and flatten them into a single extra/<kmod>/ dir. A `**/*.ko`
#     glob (used upstream-of-us) silently misses the nested modules.
cat > "${TOPDIR}/SPECS/tuxedo-drivers-kmod.spec" <<'SPECEOF'
%global debug_package %{nil}
%global kmod_name tuxedo-drivers

%if 0%{?fedora}
%global buildforkernels akmod
%endif

Name:           %{kmod_name}-kmod
Version:        @VERSION@
Release:        1%{?dist}
Summary:        TUXEDO laptop platform kernel modules (akmod)
License:        GPL-2.0-or-later
URL:            https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers
Source0:        tuxedo-drivers-v%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  kmodtool

# kmodtool generates the akmod-/kmod- sub-packages and the %{?kernel_versions}
# list / %{?akmod_install} macro used below.
%{expand:%(kmodtool --target %{_target_cpu} --kmodname %{kmod_name} %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null)}

%description
Kernel modules for TUXEDO Computers notebooks: keyboard backlight, fan control,
hardware sensors and the WMI/ACPI platform interfaces.

%prep
%setup -q -n tuxedo-drivers-v%{version}
# One build tree per kernel kmodtool asked us to build for.
for kernel_version in %{?kernel_versions} ; do
    cp -a src "_kmod_build_${kernel_version%%___*}"
done

%build
for kernel_version in %{?kernel_versions} ; do
    make %{?_smp_mflags} \
        -C "${kernel_version##*___}" \
        M="${PWD}/_kmod_build_${kernel_version%%___*}" \
        modules
done

%install
for kernel_version in %{?kernel_versions} ; do
    install -d "%{buildroot}/lib/modules/${kernel_version%%___*}/extra/%{kmod_name}/"
    # Modules build into several sub-directories; flatten every .ko into one
    # extra/<kmod>/ dir (single level, as required by the akmods module signer).
    find "_kmod_build_${kernel_version%%___*}" -name '*.ko' -exec \
        install -m 0755 {} "%{buildroot}/lib/modules/${kernel_version%%___*}/extra/%{kmod_name}/" \;
done
%{?akmod_install}

%changelog
* @DATE@ ublue-os <ublue-os> - @VERSION@-1
- Built from TUXEDO upstream v@VERSION@
SPECEOF

### Generate the common spec (config files shipped alongside the modules).
# These are the udev rules, hwdb entries and the modprobe blacklist upstream
# ships in files/usr. Autoloading is handled by the modules' own modaliases
# (MODULE_DEVICE_TABLE / MODULE_ALIAS), exactly like upstream and like the other
# akmods here, so we deliberately do NOT force-load every module via
# modules-load.d (that spams errors on non-TUXEDO hardware).
cat > "${TOPDIR}/SPECS/tuxedo-drivers-kmod-common.spec" <<'SPECEOF'
%global kmod_name tuxedo-drivers

Name:           %{kmod_name}-kmod-common
Version:        @VERSION@
Release:        1%{?dist}
Summary:        Config files for the TUXEDO laptop kernel modules
License:        GPL-2.0-or-later
URL:            https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers
Source0:        tuxedo-drivers-v%{version}.tar.gz
BuildArch:      noarch

%description
udev rules, hwdb entries and modprobe configuration shipped with the TUXEDO
laptop kernel modules (%{kmod_name}-kmod).

%prep
%setup -q -n tuxedo-drivers-v%{version}

%build

%install
mkdir -p %{buildroot}
cp -a files/usr %{buildroot}/usr

%files
%license LICENSE
%doc README.md
/usr/lib/modprobe.d/*
/usr/lib/udev/rules.d/*
/usr/lib/udev/hwdb.d/*

%changelog
* @DATE@ ublue-os <ublue-os> - @VERSION@-1
- Built from TUXEDO upstream v@VERSION@
SPECEOF

# Bake in the upstream version / build date (kept out of the heredocs so the spec
# text itself stays verbatim).
sed -i "s/@VERSION@/${TUXEDO_DRIVERS_VERSION}/g; s/@DATE@/${BUILD_DATE}/g" \
    "${TOPDIR}/SPECS/tuxedo-drivers-kmod.spec" \
    "${TOPDIR}/SPECS/tuxedo-drivers-kmod-common.spec"

### BUILD the akmod + common RPMs from the generated specs
rpmbuild -ba --define "_topdir ${TOPDIR}" "${TOPDIR}/SPECS/tuxedo-drivers-kmod-common.spec"
rpmbuild -ba --define "_topdir ${TOPDIR}" "${TOPDIR}/SPECS/tuxedo-drivers-kmod.spec"

### BUILD tuxedo-drivers kmod (succeed or fail-fast with debug output)
# Installing the akmod drops the source RPM where akmods can find it.
dnf install -y "${TOPDIR}/RPMS/${ARCH}/akmod-${KMOD_NAME}-"*.rpm
akmods --force --kernels "${KERNEL}" --kmod "${KMOD_NAME}"
modinfo /usr/lib/modules/"${KERNEL}"/extra/"${KMOD_NAME}"/tuxedo_keyboard.ko.xz > /dev/null \
|| (find /var/cache/akmods/"${KMOD_NAME}"/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/"${KMOD_NAME}"/tuxedo_io.ko.xz > /dev/null \
|| (find /var/cache/akmods/"${KMOD_NAME}"/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
cp "${TOPDIR}/RPMS/noarch/${KMOD_NAME}-kmod-common-"*.rpm /var/cache/rpms/common/

rm -f /var/cache/rpms/common/*.src.rpm

rm -rf "${TOPDIR%/rpmbuild}"
