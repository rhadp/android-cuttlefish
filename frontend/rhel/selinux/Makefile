# Makefile for compiling Cuttlefish Frontend SELinux policy modules
#
# This Makefile compiles .te (type enforcement) files into .pp (policy package) files
# that can be installed with semodule.

# Policy names
POLICIES = cuttlefish_operator cuttlefish_orchestration

# Tools
CHECKMODULE = checkmodule
SEMODULE_PACKAGE = semodule_package

.PHONY: all clean install uninstall

all: $(addsuffix .pp,$(POLICIES))

# Compile .te file to .mod file
%.mod: %.te
	$(CHECKMODULE) -M -m -o $@ $<

# Package .mod and .fc files into .pp file
%.pp: %.mod %.fc
	$(SEMODULE_PACKAGE) -o $@ -m $< -f $*.fc

# Install all policy modules
install: all
	for policy in $(POLICIES); do \
		semodule -i $$policy.pp; \
	done
	restorecon -R /usr/lib/cuttlefish-common/bin/operator || true
	restorecon -R /usr/lib/cuttlefish-common/bin/host_orchestrator || true
	restorecon -R /usr/lib/cuttlefish-common/bin/generate-operator-certs.sh || true
	restorecon -R /etc/cuttlefish-common/operator/cert || true
	restorecon -R /run/cuttlefish || true
	restorecon -R /var/lib/cuttlefish-common || true
	restorecon -R /usr/share/cuttlefish-common/operator || true

# Uninstall all policy modules
uninstall:
	for policy in $(POLICIES); do \
		semodule -r $$policy || true; \
	done

# Clean build artifacts
clean:
	rm -f *.mod *.pp

# Help target
help:
	@echo "Cuttlefish Frontend SELinux Policy Makefile"
	@echo "Targets:"
	@echo "  all       - Build all policy modules (default)"
	@echo "  install   - Install policy modules"
	@echo "  uninstall - Remove policy modules"
	@echo "  clean     - Remove build artifacts"
