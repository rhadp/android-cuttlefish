Name:           cuttlefish-defaults
Version:        1.34.0
Release:        1%{?dist}
Summary:        Cuttlefish Android Virtual Device - Experimental Features

License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish
Source0:        cuttlefish-base-%{version}.tar.gz

# Build dependencies will be added in Task 2
BuildRequires:

# Runtime dependencies will be added in Task 2
Requires:       cuttlefish-base

%description
May potentially enable new or experimental cuttlefish features
before being enabled by default.

%prep
# Source extraction and preparation
# Will be implemented in Task 7

%build
# No build step required for defaults package

%install
# Install files to buildroot
# Will be implemented in Task 7

%files
# List of files included in package
# Will be implemented in Task 7

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish experimental features
