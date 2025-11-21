Cuttlefish is an Android Virtual Device (AVD) platform that provides a configurable virtual Android environment for local Linux systems and Google Compute Engine instances.

  Repository Structure

  Core Components:
  - base/cvd/cuttlefish/host/commands/ - Main executable commands
  - base/cvd/cuttlefish/host/frontend/ - User interface components
  - e2etests/ - End-to-end testing infrastructure
  - docker/ - Docker configurations
  - docs/ - Documentation

  Key Executables:
  - run_cvd - Launch virtual device
  - assemble_cvd - Prepare device configuration
  - cvd - Main management utility
  - Various simulators (modem, sensors, location)

  Technology Stack

  Languages:
  - C++ (Primary) - 581 .cpp files, 782 headers - core system components
  - Go - 78 files - utility scripts and build tools
  - Rust - 12 files - performance-critical components
  - Python - Supplementary scripting

  Build System:
  - Bazel - Primary build tool with extensive .bazel and BUILD.bazel files

  Key Technologies:
  - WebRTC for remote device streaming
  - gRPC for inter-service communication
  - Docker containerization support
  - KVM virtualization
  - Network and hardware simulation

  Debian Packages

  - cuttlefish-base - Static device resources
  - cuttlefish-user - Web server for device interactions
  - cuttlefish-integration - GCE utilities
  - cuttlefish-orchestration - Advanced device management

  Use Cases

  - Android development and testing
  - Device feature simulation
  - Cloud-based Android environments
  - CI/CD integration