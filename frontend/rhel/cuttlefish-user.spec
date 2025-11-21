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
%setup -q -n cuttlefish-frontend-%{version}

%build
# Build operator Go binary with RHEL-compliant flags (Task 5.2)
# Based on frontend/debian/rules override_dh_auto_build
export CGO_ENABLED=1
export GOFLAGS="-buildmode=pie -trimpath -ldflags=-linkmode=external -ldflags=-extldflags=-Wl,-z,relro,-z,now"

cd src/operator
go build -v -o operator
cd ../..

# Build web UI
if [ -x ./build-webui.sh ]; then
    ./build-webui.sh
fi

%install
# Create directory structure (Task 5.3)
mkdir -p %{buildroot}/usr/lib/cuttlefish-common/bin
mkdir -p %{buildroot}%{_unitdir}
mkdir -p %{buildroot}/etc/sysconfig
mkdir -p %{buildroot}/usr/share/cuttlefish-common/operator

# Install operator binary (based on frontend/debian/cuttlefish-user.install)
install -m 755 src/operator/operator \
    %{buildroot}/usr/lib/cuttlefish-common/bin/operator

# Install operator web UI and assets
if [ -d src/operator/webui/dist/static ]; then
    cp -r src/operator/webui/dist/static \
        %{buildroot}/usr/share/cuttlefish-common/operator/
fi
if [ -d src/operator/intercept ]; then
    cp -r src/operator/intercept \
        %{buildroot}/usr/share/cuttlefish-common/operator/
fi

# Install systemd unit file
install -m 644 rhel/cuttlefish-operator.service \
    %{buildroot}%{_unitdir}/cuttlefish-operator.service

# Install config file to /etc/sysconfig/
install -m 644 rhel/cuttlefish-operator.default \
    %{buildroot}/etc/sysconfig/cuttlefish-operator

# Install certificate generation script
install -m 755 rhel/generate-operator-certs.sh \
    %{buildroot}/usr/lib/cuttlefish-common/bin/generate-operator-certs.sh

%files
# Operator binary and certificate generation script
%attr(755,root,root) /usr/lib/cuttlefish-common/bin/operator
%attr(755,root,root) /usr/lib/cuttlefish-common/bin/generate-operator-certs.sh

# Operator web UI and assets
/usr/share/cuttlefish-common/operator/*

# Systemd unit file
%{_unitdir}/cuttlefish-operator.service

# Configuration file (noreplace to preserve user modifications)
%config(noreplace) /etc/sysconfig/cuttlefish-operator

%pre
# Create _cutf-operator user if it doesn't exist (Task 5.5)
# Based on frontend/debian/cuttlefish-user.postinst
# The cvdnetwork group is created by cuttlefish-base
getent passwd _cutf-operator >/dev/null || \
    useradd -r -s /sbin/nologin -d /var/empty -M -g cvdnetwork _cutf-operator

%post
# Post-installation scriptlet (Task 5.6)
# Use systemd macros for service management
%systemd_post cuttlefish-operator.service

# Create certificate directory with proper ownership
mkdir -p /etc/cuttlefish-common/operator/cert
chown _cutf-operator:cvdnetwork /etc/cuttlefish-common/operator/cert
chmod 755 /etc/cuttlefish-common/operator/cert

%preun
# Pre-uninstall scriptlet (Task 5.6)
%systemd_preun cuttlefish-operator.service

%postun
# Post-uninstall scriptlet (Task 5.6)
%systemd_postun cuttlefish-operator.service

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish operator service
