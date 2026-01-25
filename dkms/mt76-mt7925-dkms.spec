%define module_name mt76-mt7925
%define version 1.4.0

Name:           %{module_name}-dkms
Version:        %{version}
Release:        1%{?dist}
Summary:        MediaTek MT7925/MT7921 WiFi driver with MLO fixes (DKMS)
License:        GPL-2.0
URL:            https://github.com/zbowling/mt7925
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Requires:       dkms
Requires:       kernel-devel
Requires:       linux-firmware

%description
DKMS package for MediaTek MT7925 and MT7921 WiFi chipsets with
Multi-Link Operation (MLO) fixes for WiFi 7 support.
Requires kernel 6.17 or newer.

%prep
%setup -q -n %{name}-%{version}

%install
mkdir -p %{buildroot}%{_usrsrc}/%{module_name}-%{version}
cp -r src/* %{buildroot}%{_usrsrc}/%{module_name}-%{version}/
cp dkms.conf %{buildroot}%{_usrsrc}/%{module_name}-%{version}/

%post
dkms add -m %{module_name} -v %{version} --rpm_safe_upgrade || :
dkms build -m %{module_name} -v %{version} || :
dkms install -m %{module_name} -v %{version} --force || :

%preun
dkms remove -m %{module_name} -v %{version} --all --rpm_safe_upgrade || :

%files
%{_usrsrc}/%{module_name}-%{version}
