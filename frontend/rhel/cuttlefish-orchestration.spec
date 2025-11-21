Name:           cuttlefish-orchestration
Version:        1.34.0
Release:        1%{?dist}
Summary:        Cuttlefish Android Virtual Device - Host Orchestrator

License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish
Source0:        cuttlefish-frontend-%{version}.tar.gz

# Build dependencies (same as cuttlefish-user)
BuildRequires:  golang >= 1.13
BuildRequires:  protobuf-devel
BuildRequires:  protobuf-compiler

# Runtime dependencies
Requires:       cuttlefish-user
Requires:       shadow-utils
Requires:       openssl
Requires:       nginx
Requires:       systemd-journal-remote

%description
Cuttlefish Android Virtual Device companion package.
Contains the host orchestrator.

%prep
# Source extraction and preparation
# Will be implemented in Task 6

%build
# Build Go components
# Will be implemented in Task 6

%install
# Install files to buildroot
# Will be implemented in Task 6

%files
# List of files included in package
# Will be implemented in Task 6

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish host orchestrator
