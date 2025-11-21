# SELinux Policy Integration Guide

This document describes how to integrate SELinux policies into Cuttlefish RPM packages.

## Overview

Cuttlefish includes SELinux policy modules for:
- **cuttlefish_host_resources**: Network bridge and tap interface management
- **cuttlefish_operator**: WebRTC signaling server
- **cuttlefish_orchestration**: Host orchestrator service

## Policy Files Structure

```
base/rhel/selinux/
├── cuttlefish.if                          # SELinux interfaces
├── cuttlefish_host_resources.te           # Type enforcement policy
├── cuttlefish_host_resources.fc           # File contexts
└── Makefile                                # Compilation makefile

frontend/rhel/selinux/
├── cuttlefish_operator.te                 # Type enforcement policy
├── cuttlefish_operator.fc                 # File contexts
├── cuttlefish_orchestration.te            # Type enforcement policy
├── cuttlefish_orchestration.fc            # File contexts
└── Makefile                                # Compilation makefile
```

## Integration into RPM Spec Files

### Step 1: Add BuildRequires

Add to spec files:

```spec
BuildRequires:  selinux-policy-devel
BuildRequires:  checkpolicy
BuildRequires:  policycoreutils
```

### Step 2: Build Section

Compile SELinux policies during %build:

```spec
%build
# ... existing build commands ...

# Compile SELinux policy modules
cd rhel/selinux
make -f /usr/share/selinux/devel/Makefile cuttlefish_host_resources.pp
cd ../..
```

For frontend packages:

```spec
%build
# ... existing build commands ...

# Compile SELinux policy modules
cd rhel/selinux
make -f /usr/share/selinux/devel/Makefile cuttlefish_operator.pp
make -f /usr/share/selinux/devel/Makefile cuttlefish_orchestration.pp
cd ../..
```

### Step 3: Install Section

Install compiled .pp files:

```spec
%install
# ... existing install commands ...

# Install SELinux policy modules
mkdir -p %{buildroot}%{_datadir}/selinux/packages
install -m 644 rhel/selinux/cuttlefish_host_resources.pp \
    %{buildroot}%{_datadir}/selinux/packages/cuttlefish_host_resources.pp
```

### Step 4: Files Section

Add policy packages to %files:

```spec
%files
# ... existing files ...

# SELinux policy modules
%{_datadir}/selinux/packages/cuttlefish_host_resources.pp
```

### Step 5: Post-Install Script

Install and activate SELinux policies:

```spec
%post
# ... existing post commands ...

# Install SELinux policy module
if [ $1 -eq 1 ]; then
    # Fresh install
    semodule -n -i %{_datadir}/selinux/packages/cuttlefish_host_resources.pp
    if /usr/sbin/selinuxenabled; then
        load_policy
        restorecon -R /usr/lib/cuttlefish-common/bin/setup-host-resources.sh
        restorecon -R /var/run/cuttlefish-dnsmasq-* 2>/dev/null || true
        restorecon -R /run/cuttlefish-dnsmasq-* 2>/dev/null || true
    fi
fi

# Enable SELinux booleans
/usr/sbin/setsebool -P cuttlefish_networking on 2>/dev/null || true
/usr/sbin/setsebool -P cuttlefish_kvm on 2>/dev/null || true
```

### Step 6: Post-Uninstall Script

Remove SELinux policies on package removal:

```spec
%postun
# ... existing postun commands ...

# Remove SELinux policy module
if [ $1 -eq 0 ]; then
    # Complete removal
    if /usr/sbin/selinuxenabled; then
        semodule -n -r cuttlefish_host_resources 2>/dev/null || true
        load_policy
    fi
fi
```

## Complete Example: cuttlefish-base.spec

Here's how the cuttlefish-base.spec would be modified:

```spec
Name:           cuttlefish-base
# ... metadata ...

BuildRequires:  selinux-policy-devel
BuildRequires:  checkpolicy
BuildRequires:  policycoreutils

%build
# ... existing Bazel build ...

# Compile SELinux policy
cd rhel/selinux
make -f /usr/share/selinux/devel/Makefile cuttlefish_host_resources.pp
cd ../..

%install
# ... existing install commands ...

# Install SELinux policy
mkdir -p %{buildroot}%{_datadir}/selinux/packages
install -m 644 rhel/selinux/cuttlefish_host_resources.pp \
    %{buildroot}%{_datadir}/selinux/packages/

%files
# ... existing files ...
%{_datadir}/selinux/packages/cuttlefish_host_resources.pp

%post
# ... existing post commands ...

# SELinux policy installation
if [ $1 -eq 1 ]; then
    semodule -n -i %{_datadir}/selinux/packages/cuttlefish_host_resources.pp
    if /usr/sbin/selinuxenabled; then
        load_policy
        restorecon -R /usr/lib/cuttlefish-common/bin/setup-host-resources.sh
    fi
fi
/usr/sbin/setsebool -P cuttlefish_networking on || true
/usr/sbin/setsebool -P cuttlefish_kvm on || true

%postun
# ... existing postun commands ...

# SELinux policy removal
if [ $1 -eq 0 ]; then
    if /usr/sbin/selinuxenabled; then
        semodule -n -r cuttlefish_host_resources || true
        load_policy
    fi
fi
```

## Port Labeling

Some services may need custom port labels. Add to %post:

```spec
# Label operator ports
if /usr/sbin/selinuxenabled; then
    /usr/sbin/semanage port -a -t http_port_t -p tcp 1080 2>/dev/null || \
    /usr/sbin/semanage port -m -t http_port_t -p tcp 1080 || true

    /usr/sbin/semanage port -a -t http_port_t -p tcp 1443 2>/dev/null || \
    /usr/sbin/semanage port -m -t http_port_t -p tcp 1443 || true
fi
```

And remove in %postun:

```spec
if [ $1 -eq 0 ]; then
    if /usr/sbin/selinuxenabled; then
        /usr/sbin/semanage port -d -t http_port_t -p tcp 1080 2>/dev/null || true
        /usr/sbin/semanage port -d -t http_port_t -p tcp 1443 2>/dev/null || true
    fi
fi
```

## Testing SELinux Policies

### 1. Check if SELinux is Enforcing

```bash
getenforce
```

### 2. Install Package and Check Module

```bash
sudo dnf install cuttlefish-base
sudo semodule -l | grep cuttlefish
```

### 3. Test Service Startup

```bash
sudo systemctl start cuttlefish-host-resources
sudo systemctl status cuttlefish-host-resources
```

### 4. Check for AVC Denials

```bash
sudo ausearch -m avc -ts recent | grep cuttlefish
```

### 5. If Denials Found

Generate additional policy:

```bash
sudo ausearch -m avc -ts recent | audit2allow -M cuttlefish_additional
sudo semodule -i cuttlefish_additional.pp
```

## SELinux Policy Development Workflow

1. **Create minimal policy**: Start with basic permissions
2. **Test in permissive**: Set domain to permissive mode
3. **Collect denials**: Run service and collect AVC denials
4. **Add permissions**: Use audit2allow to generate rules
5. **Test in enforcing**: Re-test with SELinux enforcing
6. **Iterate**: Repeat until service works without denials

## SELinux Booleans Reference

| Boolean | Default | Description |
|---------|---------|-------------|
| `cuttlefish_networking` | `on` | Allow network bridge/NAT configuration |
| `cuttlefish_kvm` | `on` | Allow KVM kernel module loading |
| `cuttlefish_tls` | `on` | Allow TLS certificate operations |
| `cuttlefish_connect_any` | `off` | Allow connections to any port (dev only) |
| `cuttlefish_download_artifacts` | `on` | Allow artifact downloads |

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#selinux-issues) for detailed SELinux troubleshooting steps.

## References

- [SELinux Policy Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10/html/using_selinux/index)
- [Writing SELinux Policy](https://github.com/SELinuxProject/selinux-notebook/blob/main/src/types_of_policy.md)
- [RPM Packaging and SELinux](https://docs.fedoraproject.org/en-US/packaging-guidelines/SELinux/)
