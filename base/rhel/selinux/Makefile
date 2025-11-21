# Makefile for compiling Cuttlefish SELinux policy modules
#
# This Makefile compiles .te (type enforcement) files into .pp (policy package) files
# that can be installed with semodule.

# Policy name
POLICY = cuttlefish_host_resources

# Targets
TARGETS = $(POLICY).pp

# Tools
CHECKMODULE = checkmodule
SEMODULE_PACKAGE = semodule_package

.PHONY: all clean install uninstall

all: $(TARGETS)

# Compile .te file to .mod file
%.mod: %.te
	$(CHECKMODULE) -M -m -o $@ $<

# Package .mod and .fc files into .pp file
%.pp: %.mod %.fc
	$(SEMODULE_PACKAGE) -o $@ -m $< -f $(POLICY).fc

# Optional: include interface file if present
ifneq (,$(wildcard cuttlefish.if))
$(POLICY).pp: cuttlefish.if
endif

# Install policy module
install: $(TARGETS)
	semodule -i $(TARGETS)
	restorecon -R /usr/lib/cuttlefish-common/bin/setup-host-resources.sh
	restorecon -R /var/run/cuttlefish-dnsmasq-* || true
	restorecon -R /run/cuttlefish-dnsmasq-* || true

# Uninstall policy module
uninstall:
	semodule -r $(POLICY) || true

# Clean build artifacts
clean:
	rm -f *.mod *.pp

# Help target
help:
	@echo "Cuttlefish SELinux Policy Makefile"
	@echo "Targets:"
	@echo "  all       - Build all policy modules (default)"
	@echo "  install   - Install policy modules"
	@echo "  uninstall - Remove policy modules"
	@echo "  clean     - Remove build artifacts"
