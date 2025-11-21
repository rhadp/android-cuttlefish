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
%setup -q -n %{name}-%{version}
# Verify WORKSPACE file exists for Bazel builds
if [ ! -f cvd/WORKSPACE ]; then
    echo "ERROR: WORKSPACE file not found in cvd/ directory"
    exit 1
fi

%build
# Export RPM build flags for Bazel
export RPM_OPT_FLAGS="%{optflags}"
export RPM_LD_FLAGS="%{__global_ldflags}"

# Build C++ components using Bazel
# Based on base/debian/rules override_dh_auto_build
cd cvd
bazel build \
    --compilation_mode=opt \
    --copt="${RPM_OPT_FLAGS}" \
    --linkopt="${RPM_LD_FLAGS}" \
    --linkopt="-Wl,--build-id=sha1" \
    --spawn_strategy=local \
    --workspace_status_command=../stamp_helper.sh \
    --build_tag_filters=-clang-tidy \
    'cuttlefish/package:cvd'
cd ..

%install
# Detect build architecture and set bazel output path (Task 4.4.1)
%ifarch x86_64
%define bazel_output_path cvd/bazel-out/k8-opt/bin
%endif
%ifarch aarch64
%define bazel_output_path cvd/bazel-out/aarch64-opt/bin
%endif

# Create directory structure (Task 4.4.2)
mkdir -p %{buildroot}/usr/lib/cuttlefish-common/bin
mkdir -p %{buildroot}%{_unitdir}
mkdir -p %{buildroot}/etc/sysconfig
mkdir -p %{buildroot}/usr/lib/udev/rules.d
mkdir -p %{buildroot}/usr/bin

# Copy binaries from architecture-specific Bazel output (Task 4.4.3)
# Based on base/debian/cuttlefish-base.install
cp -r %{bazel_output_path}/cuttlefish/package/cuttlefish-common/* \
    %{buildroot}/usr/lib/cuttlefish-common/

# Install additional scripts (capability_query.py)
install -m 755 host/deploy/capability_query.py \
    %{buildroot}/usr/lib/cuttlefish-common/bin/

# Install files from host/packages/cuttlefish-base/* (Task 4.4.2)
# These include /etc configuration files
cp -r host/packages/cuttlefish-base/* %{buildroot}/

# Install systemd unit file (Task 4.4.4)
install -m 644 rhel/cuttlefish-host-resources.service \
    %{buildroot}%{_unitdir}/cuttlefish-host-resources.service

# Install config file to /etc/sysconfig/ (Task 4.4.5)
install -m 644 rhel/cuttlefish-host-resources.default \
    %{buildroot}/etc/sysconfig/cuttlefish-host-resources

# Install udev rules (Task 4.4.6)
install -m 644 debian/cuttlefish-base.udev \
    %{buildroot}/usr/lib/udev/rules.d/99-cuttlefish-base.rules

# Install wrapper script (Task 4.4.7)
install -m 755 rhel/setup-host-resources.sh \
    %{buildroot}/usr/lib/cuttlefish-common/bin/setup-host-resources.sh

# Create symlink from /usr/bin/cvd to /usr/lib/cuttlefish-common/bin/cvd (Task 4.4.8)
ln -s /usr/lib/cuttlefish-common/bin/cvd %{buildroot}/usr/bin/cvd

# Create additional symlinks from base/debian/cuttlefish-base.links
ln -s /usr/lib/cuttlefish-common/bin/graphics_detector \
    %{buildroot}/usr/lib/cuttlefish-common/bin/aarch64-linux-gnu/gfxstream_graphics_detector || true
ln -s /usr/lib/cuttlefish-common/bin/libvk_swiftshader.so \
    %{buildroot}/usr/lib/cuttlefish-common/bin/aarch64-linux-gnu/libvk_swiftshader.so || true
ln -s /usr/lib/cuttlefish-common/bin/graphics_detector \
    %{buildroot}/usr/lib/cuttlefish-common/bin/x86_64-linux-gnu/gfxstream_graphics_detector || true
mkdir -p %{buildroot}/usr/lib/cuttlefish-common/lib64 || true
ln -s /usr/lib/cuttlefish-common/bin/libvk_lavapipe.so \
    %{buildroot}/usr/lib/cuttlefish-common/lib64/vulkan.lvp.so || true
ln -s /usr/lib/cuttlefish-common/bin/libvk_swiftshader.so \
    %{buildroot}/usr/lib/cuttlefish-common/lib64/vulkan.pastel.so || true

# Remove bazel metadata (based on base/debian/rules override_dh_install)
rm -rf %{buildroot}/usr/lib/cuttlefish-common/bin/cvd.repo_mapping || true
rm -rf %{buildroot}/usr/lib/cuttlefish-common/bin/cvd.runfiles* || true

# Fix permissions for json files and etc files (based on base/debian/rules override_dh_fixperms)
chmod -x %{buildroot}/usr/lib/cuttlefish-common/bin/*.json || true
find %{buildroot}/usr/lib/cuttlefish-common/etc -type f -exec chmod -x '{}' ';' || true

# Create /var/empty directory
mkdir -p %{buildroot}/var/empty

%files
# Binaries and libraries
%attr(755,root,root) /usr/lib/cuttlefish-common/bin/*
/usr/lib/cuttlefish-common/etc/*
/usr/lib/cuttlefish-common/lib64/*

# Symlink to make cvd available in PATH
/usr/bin/cvd

# Systemd unit file
%{_unitdir}/cuttlefish-host-resources.service

# Configuration file (noreplace to preserve user modifications)
%config(noreplace) /etc/sysconfig/cuttlefish-host-resources

# System configuration files from host/packages/cuttlefish-base
%config(noreplace) /etc/modules-load.d/cuttlefish-common.conf
%config(noreplace) /etc/NetworkManager/conf.d/99-cuttlefish.conf
%config(noreplace) /etc/security/limits.d/1_cuttlefish.conf

# Udev rules
/usr/lib/udev/rules.d/99-cuttlefish-base.rules

# /var/empty directory
%dir /var/empty

%pre
# Create cvdnetwork group if it doesn't exist (Task 4.6)
# Based on base/debian/cuttlefish-base.postinst
getent group cvdnetwork >/dev/null || groupadd -r cvdnetwork

# Create kvm group when running inside a docker container
if [ -f /.dockerenv ]; then
    getent group kvm >/dev/null || groupadd -r kvm
fi

%post
# Post-installation scriptlet (Task 4.7)
# Based on base/debian/cuttlefish-base.postinst

# Use systemd macros for service management
%systemd_post cuttlefish-host-resources.service

# Reload udev rules
udevadm control --reload-rules || true
udevadm trigger || true

# Set capabilities on cvdalloc binary
if [ -f /usr/lib/cuttlefish-common/bin/cvdalloc ]; then
    setcap cap_net_admin,cap_net_bind_service,cap_net_raw=+ep \
        /usr/lib/cuttlefish-common/bin/cvdalloc || true
fi

# Ensure /var/empty is a directory (not a symlink or file)
if [ -L /var/empty ]; then
    unlink /var/empty
fi
if [ -f /var/empty ]; then
    rm -rf /var/empty
fi
mkdir -p /var/empty

%preun
# Pre-uninstall scriptlet (Task 4.8)
%systemd_preun cuttlefish-host-resources.service

%postun
# Post-uninstall scriptlet (Task 4.9)
%systemd_postun cuttlefish-host-resources.service

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish base components
