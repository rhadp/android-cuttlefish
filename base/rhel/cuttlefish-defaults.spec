Name:           cuttlefish-defaults
Version:        1.34.0
Release:        1%{?dist}
Summary:        Cuttlefish Android Virtual Device - Experimental Features

License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish
Source0:        cuttlefish-base-%{version}.tar.gz

# No build dependencies needed for defaults package

# Runtime dependencies
Requires:       cuttlefish-base

%description
May potentially enable new or experimental cuttlefish features
before being enabled by default.

%prep
%setup -q -n cuttlefish-base-%{version}

%build
# No build step required for defaults package

%install
# Create directory structure (Task 7.3)
mkdir -p %{buildroot}/usr/lib/cuttlefish-common/etc

# Install configuration file (based on base/debian/cuttlefish-defaults.install)
install -m 644 debian/cf_defaults \
    %{buildroot}/usr/lib/cuttlefish-common/etc/cf_defaults

%files
# Configuration file for experimental features
%config(noreplace) /usr/lib/cuttlefish-common/etc/cf_defaults

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 package for Cuttlefish experimental features
