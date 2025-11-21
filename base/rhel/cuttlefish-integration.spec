Name:           cuttlefish-integration
Version:        1.34.0
Release:        1%{?dist}
Summary:        Cuttlefish Android Virtual Device - GCE Integration

License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish
Source0:        cuttlefish-base-%{version}.tar.gz

# No build dependencies needed for integration package

# Runtime dependencies
Requires:       cuttlefish-base
Requires:       qemu-system-arm >= 2.8.0
Requires:       qemu-system-x86 >= 2.8.0
Requires:       qemu-system-misc >= 2.8.0

%description
Configuration and utilities for Android cuttlefish devices running on
Google Compute Engine. Not intended for use on developer machines.

%prep
%setup -q -n cuttlefish-base-%{version}

%build
# No build step required for integration package

%install
# Create directory structure (Task 7.1)
mkdir -p %{buildroot}/usr/lib/udev/rules.d
mkdir -p %{buildroot}/etc/modprobe.d
mkdir -p %{buildroot}/etc/default
mkdir -p %{buildroot}/etc/rsyslog.d
mkdir -p %{buildroot}/etc/ssh

# Install udev rules (based on base/debian/cuttlefish-integration.udev)
install -m 644 debian/cuttlefish-integration.udev \
    %{buildroot}/usr/lib/udev/rules.d/99-cuttlefish-integration.rules

# Install files from host/packages/cuttlefish-integration
# (based on base/debian/cuttlefish-integration.install)
install -m 644 host/packages/cuttlefish-integration/etc/modprobe.d/cuttlefish-integration.conf \
    %{buildroot}/etc/modprobe.d/cuttlefish-integration.conf
install -m 644 host/packages/cuttlefish-integration/etc/default/instance_configs.cfg.template \
    %{buildroot}/etc/default/instance_configs.cfg.template
install -m 644 host/packages/cuttlefish-integration/etc/rsyslog.d/91-cuttlefish.conf \
    %{buildroot}/etc/rsyslog.d/91-cuttlefish.conf
install -m 644 host/packages/cuttlefish-integration/etc/ssh/sshd_config.cuttlefish \
    %{buildroot}/etc/ssh/sshd_config.cuttlefish

%files
# Udev rules
/usr/lib/udev/rules.d/99-cuttlefish-integration.rules

# Kernel module configuration
%config(noreplace) /etc/modprobe.d/cuttlefish-integration.conf

# GCE integration configuration files
%config(noreplace) /etc/default/instance_configs.cfg.template
%config(noreplace) /etc/rsyslog.d/91-cuttlefish.conf
%config(noreplace) /etc/ssh/sshd_config.cuttlefish

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish GCE integration
