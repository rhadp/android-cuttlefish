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
%setup -q -n cuttlefish-frontend-%{version}

%build
# Build host_orchestrator Go binary with RHEL-compliant flags (Task 6.2)
# Based on frontend/debian/rules override_dh_auto_build
export CGO_ENABLED=1
export GOFLAGS="-buildmode=pie -trimpath -ldflags=-linkmode=external -ldflags=-extldflags=-Wl,-z,relro,-z,now"

cd src/host_orchestrator
go build -v -o host_orchestrator
cd ../..

%install
# Create directory structure (Task 6.3)
mkdir -p %{buildroot}/usr/lib/cuttlefish-common/bin
mkdir -p %{buildroot}%{_unitdir}
mkdir -p %{buildroot}/etc/sysconfig
mkdir -p %{buildroot}/etc/nginx/conf.d
mkdir -p %{buildroot}/var/lib/cuttlefish-common

# Install host_orchestrator binary
install -m 755 src/host_orchestrator/host_orchestrator \
    %{buildroot}/usr/lib/cuttlefish-common/bin/host_orchestrator

# Install systemd unit file
install -m 644 rhel/cuttlefish-host_orchestrator.service \
    %{buildroot}%{_unitdir}/cuttlefish-host_orchestrator.service

# Install config file to /etc/sysconfig/
install -m 644 rhel/cuttlefish-host_orchestrator.default \
    %{buildroot}/etc/sysconfig/cuttlefish-host_orchestrator

# Install nginx configuration to /etc/nginx/conf.d/ (RHEL path, not sites-available)
install -m 644 host/packages/cuttlefish-orchestration/etc/nginx/sites-available/cuttlefish-orchestration.conf \
    %{buildroot}/etc/nginx/conf.d/cuttlefish-orchestration.conf

%files
# Host orchestrator binary
%attr(755,root,root) /usr/lib/cuttlefish-common/bin/host_orchestrator

# Systemd unit file
%{_unitdir}/cuttlefish-host_orchestrator.service

# Configuration files (noreplace to preserve user modifications)
%config(noreplace) /etc/sysconfig/cuttlefish-host_orchestrator
%config(noreplace) /etc/nginx/conf.d/cuttlefish-orchestration.conf

# Artifacts directory
%dir %attr(755,httpcvd,cvdnetwork) /var/lib/cuttlefish-common

%pre
# Create httpcvd user and group if they don't exist (Task 6.5)
# Based on frontend/debian/cuttlefish-orchestration.postinst
# The cvdnetwork group is created by cuttlefish-base
getent group httpcvd >/dev/null || groupadd -r httpcvd
getent passwd httpcvd >/dev/null || \
    useradd -r -s /sbin/nologin -d /var/empty -M -g httpcvd httpcvd

# Add httpcvd user to cvdnetwork and kvm groups
usermod -a -G cvdnetwork httpcvd || true
usermod -a -G kvm httpcvd || true

%post
# Post-installation scriptlet (Task 6.6)
# Use systemd macros for service management
%systemd_post cuttlefish-host_orchestrator.service

# Create artifacts directory with proper ownership
mkdir -p /var/lib/cuttlefish-common
chown httpcvd:cvdnetwork /var/lib/cuttlefish-common
chmod 755 /var/lib/cuttlefish-common

# Create SSL certificate directory for nginx
mkdir -p /etc/cuttlefish-orchestration/ssl/cert
openssl req -newkey rsa:4096 -x509 -sha256 -days 36000 -nodes \
    -out /etc/cuttlefish-orchestration/ssl/cert/cert.pem \
    -keyout /etc/cuttlefish-orchestration/ssl/cert/key.pem \
    -subj "/C=US/ST=California/L=Mountain View/O=Android/CN=cuttlefish-orchestration" \
    2>/dev/null || true
chmod 644 /etc/cuttlefish-orchestration/ssl/cert/cert.pem || true
chmod 600 /etc/cuttlefish-orchestration/ssl/cert/key.pem || true

# Reload nginx to pick up new configuration
systemctl reload nginx 2>/dev/null || true

%preun
# Pre-uninstall scriptlet (Task 6.6)
%systemd_preun cuttlefish-host_orchestrator.service

%postun
# Post-uninstall scriptlet (Task 6.6)
%systemd_postun cuttlefish-host_orchestrator.service

# Reload nginx after removing configuration
if [ $1 -eq 0 ]; then
    systemctl reload nginx 2>/dev/null || true
fi

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish host orchestrator
