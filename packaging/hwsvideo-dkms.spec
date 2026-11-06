# Built by packaging/build-package.sh, which defines hws_version, hws_root and
# hws_scriptlet.
Name:           hwsvideo-dkms
Version:        %{hws_version}
Release:        1%{?dist}
Summary:        Driver for HWS PCIe capture cards (AVMatrix, ACASIS), DKMS sources
License:        GPL-3.0-only
URL:            https://github.com/GloriousEggroll/HWS_VIDEO_CAPTURE_GENERIC
BuildArch:      noarch
Requires:       dkms
Requires:       gcc
Requires:       make
Recommends:     kernel-devel
%global _hws_scriptlet %(cat %{hws_scriptlet})

%description
V4L2 and ALSA driver for the AVMatrix VC12-4K, VC41 and VC42, ACASIS's 4K, 1080p
and AHD capture cards, and related cards. DKMS builds the module for each kernel.

%install
cp -a %{hws_root}/. %{buildroot}/

%post
VER=%{version}
ACTION=postinst
%{_hws_scriptlet}

%preun
# $1 is 0 on removal, not on upgrade
if [ "$1" -eq 0 ]; then
VER=%{version}
ACTION=prerm
%{_hws_scriptlet}
fi

%files
/usr/src/hwsvideo-%{version}
%config(noreplace) /etc/modprobe.d/hwsvideo.conf
%doc /usr/share/doc/hwsvideo-dkms
