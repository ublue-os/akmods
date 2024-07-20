Name:           ublue-os-ucore-nvidia
Version:        0.3
Release:        1%{?dist}
Summary:        Additional files for nvidia driver support on CoreOS

License:        MIT
URL:            https://github.com/ublue-os/akmods

BuildArch:      noarch
Supplements:    mokutil policycoreutils

Source0:        nvidia-container-toolkit.repo
Source1:        nvidia-container.pp
Source2:        ublue-nvctk-cdi.service
Source3:        70-ublue-nvctk-cdi.preset

%description
Adds various runtime files for nvidia support on Fedora CoreOS.

%prep
%setup -q -c -T


%build
install -Dm0644 %{SOURCE0} %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo
install -Dm0644 %{SOURCE1} %{buildroot}%{_datadir}/ublue-os/%{_datadir}/selinux/packages/nvidia-container.pp
install -Dm0644 %{SOURCE2} %{buildroot}%{_datadir}/ublue-os/%{_unitdir}/ublue-nvctk-cdi.service
install -Dm0644 %{SOURCE3} %{buildroot}%{_presetdir}/70-ublue-nvctk-cdi.preset

sed -i 's@enabled=1@enabled=0@g' %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo

install -Dm0644 %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo     %{buildroot}%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo
install -Dm0644 %{buildroot}%{_datadir}/ublue-os/%{_datadir}/selinux/packages/nvidia-container.pp             %{buildroot}%{_datadir}/selinux/packages/nvidia-container.pp
install -Dm0644 %{buildroot}%{_datadir}/ublue-os/%{_unitdir}/ublue-nvctk-cdi.service                          %{buildroot}%{_unitdir}/ublue-nvctk-cdi.service

%files
%attr(0644,root,root) %{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo
%attr(0644,root,root) %{_datadir}/ublue-os/%{_datadir}/selinux/packages/nvidia-container.pp
%attr(0644,root,root) %{_datadir}/ublue-os/%{_unitdir}/ublue-nvctk-cdi.service
%attr(0644,root,root) %{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo
%attr(0644,root,root) %{_datadir}/selinux/packages/nvidia-container.pp
%attr(0644,root,root) %{_unitdir}/ublue-nvctk-cdi.service
%attr(0644,root,root) %{_presetdir}/70-ublue-nvctk-cdi.preset

%changelog
* Fri Oct 6 2023 Benjamin Sherman <benjamin@holyarmy.org> - 0.3
- add ublue-nvctk-cdi service to auto-generate NVIDIA CDI GPU definitions

* Wed Oct 04 2023 Benjamin Sherman <benjamin@holyarmy.org> - 0.2
- use newer nvidia-container-toolkit repo
- repo provides newer toolkit, no longer requires config.toml

* Sat Aug 19 2023 Benjamin Sherman <benjamin@holyarmy.org> - 0.1
First release for Fedora CoreOS based on ublue-os-nvidia-addons includes:
- nvidia-container-runtime repo
- nvidia-container-runtime rootless config
- nvidia-container-runtime selinux policy file
