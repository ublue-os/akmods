Name:           ublue-os-nvidia-addons
Version:        0.12
Release:        1%{?dist}
Summary:        Additional files for nvidia driver support

License:        MIT
URL:            https://github.com/ublue-os/akmods

BuildArch:      noarch
Supplements:    mokutil policycoreutils

Source0:        nvidia-container-toolkit.repo
Source1:        nvidia-container.pp
Source2:        ublue-nvctk-cdi.service
Source3:        70-ublue-nvctk-cdi.preset
Source4:        environment
Source5:        negativo17-fedora-nvidia.repo
Source6:        60-nvidia-extra-devices-pm.rules

%description
Adds various runtime files for nvidia support.

%prep
%setup -q -c -T


%build
install -Dm0644 %{SOURCE0} %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo
install -Dm0644 %{SOURCE1} %{buildroot}%{_datadir}/ublue-os/%{_datadir}/selinux/packages/nvidia-container.pp
install -Dm0644 %{SOURCE2} %{buildroot}%{_datadir}/ublue-os/%{_unitdir}/ublue-nvctk-cdi.service
install -Dm0644 %{SOURCE3} %{buildroot}%{_presetdir}/70-ublue-nvctk-cdi.preset
install -Dm0644 %{SOURCE4} %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/sway/environment
install -Dm0644 %{SOURCE5} %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/negativo17-fedora-nvidia.repo

sed -i 's@enabled=1@enabled=0@g' %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/negativo17-fedora-nvidia.repo
sed -i 's@enabled=1@enabled=0@g' %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo

install -Dm0644 %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/negativo17-fedora-nvidia.repo     %{buildroot}%{_sysconfdir}/yum.repos.d/negativo17-fedora-nvidia.repo
install -Dm0644 %{buildroot}%{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo     %{buildroot}%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo
install -Dm0644 %{buildroot}%{_datadir}/ublue-os/%{_datadir}/selinux/packages/nvidia-container.pp             %{buildroot}%{_datadir}/selinux/packages/nvidia-container.pp
install -Dm0644 %{buildroot}%{_datadir}/ublue-os/%{_unitdir}/ublue-nvctk-cdi.service                          %{buildroot}%{_unitdir}/ublue-nvctk-cdi.service

%files
%attr(0644,root,root) %{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/negativo17-fedora-nvidia.repo
%attr(0644,root,root) %{_datadir}/ublue-os/%{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo
%attr(0644,root,root) %{_datadir}/ublue-os/%{_datadir}/selinux/packages/nvidia-container.pp
%attr(0644,root,root) %{_datadir}/ublue-os/%{_sysconfdir}/sway/environment
%attr(0644,root,root) %{_datadir}/ublue-os/%{_unitdir}/ublue-nvctk-cdi.service
%attr(0644,root,root) %{_sysconfdir}/yum.repos.d/negativo17-fedora-nvidia.repo
%attr(0644,root,root) %{_sysconfdir}/yum.repos.d/nvidia-container-toolkit.repo
%attr(0644,root,root) %{_datadir}/selinux/packages/nvidia-container.pp
%attr(0644,root,root) %{_unitdir}/ublue-nvctk-cdi.service
%attr(0644,root,root) %{_presetdir}/70-ublue-nvctk-cdi.preset

%changelog
* Sun Nov 24 2024 RJ Trujillo <eyecantcu@pm.me> - 0.12
- Remove supergfxctl copr as it has been relocated to staging

* Sat Apr 13 Benjamin Sherman <benjamin@holyarmy.org> - 0.11
- Add negativo17 fedora-nvidia repo for switch of NVIDIA driver source
- Provided third-party repos are no longer enabled by default

* Fri Oct 6 2023 Benjamin Sherman <benjamin@holyarmy.org> - 0.10
- add ublue-nvctk-cdi service to auto-generate NVIDIA CDI GPU definitions

* Thu Oct 5 2023 Benjamin Sherman <benjamin@holyarmy.org> - 0.9
- use newer nvidia-container-toolkit repo
- repo provides newer toolkit, no longer requires config.toml

* Thu Aug 3 2023 RJ Trujillo <eyecantcu@pm.me> - 0.8
- Add new copr for supergfxctl

* Sat Jun 17 2023 Benjamin Sherman <benjamin@holyarmy.org> - 0.7
- Remove MOK keys; now provided by ublue-os-akmods-addons

* Sat Jun 17 2023 RJ Trujillo <eyecantcu@pm.me> - 0.6
- Add supergfxctl-plasmoid COPR

* Wed May 17 2023 Benjamin Sherman <benjamin@holyarmy.org> - 0.5
- Add new ublue akmod public key for MOK enrollment

* Sun Mar 26 2023 Joshua Stone <joshua.gage.stone@gmail.com> - 0.4
- Add asus-linux COPR

* Fri Feb 24 2023 Joshua Stone <joshua.gage.stone@gmail.com> - 0.3
- Add sway environment file
- Put ublue-os modifications into a separate data directory

* Thu Feb 16 2023 Joshua Stone <joshua.gage.stone@gmail.com> - 0.2
- Add nvidia-container-runtime repo
- Add nvidia-container-runtime selinux policy file
- Re-purpose into a general-purpose add-on package
- Update URL to point to ublue-os project

* Fri Feb 03 2023 Joshua Stone <joshua.gage.stone@gmail.com> - 0.1
- Add key for enrolling kernel modules in alpha builds
