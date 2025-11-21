Name:           cuttlefish-base
Version:        1.34.0
Release:        1%{?dist}
Summary:        Cuttlefish Android Virtual Device - Base Package

License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish
Source0:        %{name}-%{version}.tar.gz

# Build dependencies will be added in Task 2
BuildRequires:

# Runtime dependencies will be added in Task 2
Requires:

%description
Cuttlefish Android Virtual Device companion package.
Contains set of tools and binaries required to boot up and manage
Cuttlefish Android Virtual Device that are used in all deployments.

%prep
# Source extraction and preparation
# Will be implemented in Task 4

%build
# Build C++ components using Bazel
# Will be implemented in Task 4

%install
# Install files to buildroot
# Will be implemented in Task 4

%files
# List of files included in package
# Will be implemented in Task 4

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish base components
