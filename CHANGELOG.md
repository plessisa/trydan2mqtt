# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-10-27

### Changed
- Simplified MQTT topic structure using generic prefix "trydan"
- Updated configuration for external MQTT broker usage
- Streamlined Docker setup for containerized deployment

### Removed
- Internal MQTT broker dependencies
- Specific integration configurations

## [1.0.0] - 2025-10-27

### Added
- Initial release of Trydan to MQTT Bridge
- Support for connecting to Trydan EV chargers via python3-pytrydan
- MQTT integration with configurable broker settings
- Real-time monitoring of charging status, power, current, and energy
- Remote control capabilities via MQTT commands
- Systemd service for daemon operation
- Comprehensive configuration system with YAML files
- Automatic installation script for multiple Linux distributions
- TLS/SSL support for secure MQTT connections
- User authentication support for MQTT
- Robust error handling and automatic reconnection
- Detailed logging with configurable levels
- Log rotation setup
- Security hardening in systemd service
- Complete documentation and usage examples

### Features
- Monitor Trydan EV charger data in real-time
- Publish data to MQTT broker with customizable topics
- Accept commands via MQTT for remote control
- Support for multiple Linux distributions
- Easy installation and configuration
- Production-ready systemd service
- Secure communication options