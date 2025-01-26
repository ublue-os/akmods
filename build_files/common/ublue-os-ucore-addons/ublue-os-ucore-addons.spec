Name:           ublue-os-ucore-addons
Version:        0.1
Release:        1%{?dist}
Summary:        Signing key for ucore kmods

License:        MIT
URL:            https://github.com/ublue-os/ucore-kmods

BuildArch:      noarch
Supplements:    mokutil policycoreutils

Source0:        public_key.der

%description
Adds the signing key for importing with mokutil to enable secure boot for kernel modules.

%prep
%setup -q -c -T


%build
# Have different name for *.der in case kmodgenca is needed for creating more keys
install -Dm0644 %{SOURCE0} %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/pki/akmods/certs/akmods-ublue.der

install -Dm0644 %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/pki/akmods/certs/akmods-ublue.der            %{buildroot}%{_sysconfdir}/pki/akmods/certs/akmods-ublue.der

%files
%attr(0644,root,root) %{_datadir}/ublue-os/%{_sysconfdir}/pki/akmods/certs/akmods-ublue.der
%attr(0644,root,root) %{_sysconfdir}/pki/akmods/certs/akmods-ublue.der

%changelog
* Sat Dec 30 2023 Benjamin Sherman <benjamin@holyarmy.org> - 0.1
- Add key for enrolling ucore kernel modules for secure boot
