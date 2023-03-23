Name:           ublue-os-akmods-key
Version:        0.1
Release:        1%{?dist}
Summary:        Signing key for ublue os akmods

License:        MIT
URL:            https://github.com/ublue-os/akmods

BuildArch:      noarch
Supplements:    mokutil policycoreutils

Source0:        public_key.der

%description
Add the signing key for importing with mokutil to enable secure boot for kernel modules

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
* Fri Mar 17 2034 David Hoell - 0.1
- Add key for inrolling ublue kernel modules with new build infrastucture
