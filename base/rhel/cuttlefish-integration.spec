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
# Source extraction and preparation
# Will be implemented in Task 7

%build
# No build step required for integration package

%install
# Install files to buildroot
# Will be implemented in Task 7

%files
# List of files included in package
# Will be implemented in Task 7

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish GCE integration
