Name:           cuttlefish-common
Version:        1.34.0
Release:        1%{?dist}
Summary:        Cuttlefish Android Virtual Device - Meta Package

License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish

# This is a meta-package with no source
BuildArch:      noarch

# Runtime dependencies will be added in Task 2
Requires:       cuttlefish-base
Requires:       cuttlefish-user

%description
Metapackage ensuring all packages needed to run and interact with
Cuttlefish device are installed.

%prep
# No prep needed for meta-package

%build
# No build needed for meta-package

%install
# No install needed for meta-package

%files
# Meta-package contains no files

%changelog
* Thu Nov 21 2024 Cuttlefish Team <cloud-android-ext@google.com> - 1.34.0-1
- Initial RHEL 10 meta-package for Cuttlefish
