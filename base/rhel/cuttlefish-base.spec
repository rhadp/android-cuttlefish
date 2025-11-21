Name:           cuttlefish-base
Version:        1.34.0
Release:        1%{?dist}
Summary:        Cuttlefish Android Virtual Device - Base Package

License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish
Source0:        %{name}-%{version}.tar.gz

# Build dependencies
BuildRequires:  cmake
BuildRequires:  git
BuildRequires:  libaom-devel
BuildRequires:  clang-devel
BuildRequires:  libcurl-devel
BuildRequires:  fmt-devel
BuildRequires:  gflags-devel
BuildRequires:  glog-devel
BuildRequires:  gtest-devel
BuildRequires:  jsoncpp-devel
BuildRequires:  xz-devel
BuildRequires:  opus-devel
BuildRequires:  protobuf-c-devel
BuildRequires:  protobuf-devel
BuildRequires:  libsrtp-devel
BuildRequires:  openssl-devel
BuildRequires:  libxml2-devel
BuildRequires:  z3-devel
BuildRequires:  pkgconf
BuildRequires:  protobuf-compiler
BuildRequires:  libuuid-devel
BuildRequires:  vim-common
# Note: Bazel will be installed via Bazelisk or vbatts/bazel Copr (see Task 9.1.4)

# Runtime dependencies
Requires:       shadow-utils
Requires:       curl
Requires:       dnsmasq
Requires:       ebtables-legacy
Requires:       iproute
Requires:       iptables
Requires:       bsdtar
Requires:       libcap
Requires:       libcurl
Requires:       libdrm
Requires:       libfdt
Requires:       fmt-devel
Requires:       gflags-devel
Requires:       mesa-libGL
Requires:       jsoncpp-devel
Requires:       xz-libs
Requires:       protobuf-devel
Requires:       libsrtp
Requires:       openssl-devel
Requires:       wayland
Requires:       libX11
Requires:       libXext
Requires:       libxml2-devel
Requires:       z3-libs
Requires:       net-tools
Requires:       openssl
Requires:       opus-tools
Requires:       python3
Requires:       xdg-utils

# Architecture-specific dependencies
%ifarch aarch64
Requires:       grub2-efi-aa64
Requires:       qemu-user-static
Requires:       systemd
%endif

%ifarch x86_64
Requires:       grub2-efi-ia32
%endif

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
