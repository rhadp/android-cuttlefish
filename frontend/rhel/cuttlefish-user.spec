Name:           cuttlefish-user
Version:        1.34.0
Release:        1%{?dist}
Summary:        Cuttlefish Android Virtual Device - WebRTC Signaling Server

License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish
Source0:        cuttlefish-frontend-%{version}.tar.gz

# Build dependencies
BuildRequires:  golang >= 1.13
BuildRequires:  protobuf-devel
BuildRequires:  protobuf-compiler

# Runtime dependencies
Requires:       cuttlefish-base
Requires:       shadow-utils
Requires:       openssl

%description
Cuttlefish Android Virtual Device companion package.
Contains the host signaling server supporting multi-device flows
over WebRTC.

%prep
# Source extraction and preparation
# Will be implemented in Task 5

%build
# Build Go components
# Will be implemented in Task 5

%install
# Install files to buildroot
# Will be implemented in Task 5

%files
# List of files included in package
# Will be implemented in Task 5

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish operator service
