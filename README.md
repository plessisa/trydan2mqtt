# Trydan to MQTT Bridge

A Linux application that connects to Trydan EV chargers using the `python3-pytrydan` package and exposes data to an MQTT broker for integration with home automation systems.

## Features

- **Real-time Data Monitoring**: Continuously monitors Trydan EV charger status, power consumption, energy delivered, and more
- **MQTT Integration**: Publishes data to MQTT broker with configurable topics
- **Remote Control**: Accept commands via MQTT to control charging (start/stop, set current, change mode)
- **Generic MQTT Topics**: Uses standard topic structure compatible with any MQTT-based system
- **Robust Error Handling**: Automatic reconnection and error recovery
- **Systemd Service**: Runs as a Linux daemon with automatic startup
- **Configurable**: Extensive configuration options via YAML files
- **Secure**: Support for MQTT TLS/SSL authentication

## Prerequisites

- Linux system (Ubuntu, Debian, CentOS, RHEL, Fedora, Arch Linux)
- Python 3.7 or higher
- Trydan EV charger accessible via network
- MQTT broker (Mosquitto or cloud service)

## Quick Installation

1. **Clone or download the repository**:
   ```bash
   git clone https://github.com/your-username/trydan2mqtt.git
   cd trydan2mqtt
   ```

2. **Run the installation script**:
   ```bash
   sudo ./scripts/install.sh
   ```

3. **Configure the application**:
   ```bash
   sudo nano /etc/trydan2mqtt/config.yaml
   ```

4. **Start the service**:
   ```bash
   sudo systemctl start trydan2mqtt
   sudo systemctl status trydan2mqtt
   ```

## Manual Installation

### System Dependencies

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install python3 python3-pip python3-venv python3-systemd
```

**CentOS/RHEL/Fedora**:
```bash
sudo dnf install python3 python3-pip python3-systemd
# or for older systems:
sudo yum install python3 python3-pip python3-systemd
```

**Arch Linux**:
```bash
sudo pacman -S python python-pip python-systemd
```

### Python Dependencies

Install the Python packages:
```bash
pip3 install -r requirements.txt
```

If `python3-pytrydan` is available as a system package (recommended):
```bash
# Ubuntu/Debian
sudo apt-get install python3-pytrydan

# Or install via pip
pip3 install pytrydan
```

### Application Setup

1. **Create application user**:
   ```bash
   sudo useradd --system --home-dir /opt/trydan2mqtt --create-home --shell /bin/false trydan2mqtt
   ```

2. **Install application files**:
   ```bash
   sudo cp -r src/ /opt/trydan2mqtt/
   sudo mkdir -p /etc/trydan2mqtt
   sudo cp config/config.yaml /etc/trydan2mqtt/
   sudo chown -R trydan2mqtt:trydan2mqtt /opt/trydan2mqtt /etc/trydan2mqtt
   ```

3. **Install systemd service**:
   ```bash
   sudo cp systemd/trydan2mqtt.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable trydan2mqtt
   ```

## Configuration

Edit the configuration file at `/etc/trydan2mqtt/config.yaml`:

```yaml
# Trydan EV Charger Configuration
trydan:
  host: "192.168.1.100"  # Your Trydan IP address

# MQTT Broker Configuration
mqtt:
  host: "192.168.1.50"   # Your MQTT broker IP
  port: 1883             # MQTT port (1883 standard, 8883 SSL)
  client_id: "trydan2mqtt"
  topic_prefix: "trydan"
  username: "mqtt_user"   # Optional
  password: "mqtt_pass"   # Optional

# Bridge Configuration
bridge:
  poll_interval: 30      # Data collection interval in seconds
```

## Usage

### Starting the Service

```bash
# Start the service
sudo systemctl start trydan2mqtt

# Check status
sudo systemctl status trydan2mqtt

# View logs
sudo journalctl -u trydan2mqtt -f

# Stop the service
sudo systemctl stop trydan2mqtt
```

### Manual Execution

For testing or debugging:

```bash
# Run with default config
python3 /opt/trydan2mqtt/src/trydan2mqtt.py

# Run with custom config
python3 /opt/trydan2mqtt/src/trydan2mqtt.py /path/to/custom/config.yaml
```

### MQTT Topics

The application publishes data to the following MQTT topics:

#### Status Topics
- `trydan/sensor/status` - Charging status (charge_state)
- `trydan/sensor/charging_current` - Current charging current in Amperes (intensity)
- `trydan/sensor/charging_power` - Current charging power in Watts (charge_power)
- `trydan/sensor/energy_delivered` - Total energy delivered in kWh (charge_energy)
- `trydan/sensor/charge_time` - Current charging session time
- `trydan/sensor/voltage` - Installation voltage (voltage_installation)
- `trydan/sensor/house_power` - House power consumption
- `trydan/sensor/battery_power` - Battery power (if applicable)
- `trydan/sensor/fv_power` - PV/Solar power generation
- `trydan/sensor/max_intensity` - Maximum allowed charging current
- `trydan/sensor/min_intensity` - Minimum allowed charging current
- `trydan/sensor/ready_state` - Device ready state
- `trydan/sensor/locked` - Charger lock status (true/false)
- `trydan/sensor/paused` - Charging pause status (true/false)
- `trydan/sensor/dynamic` - Dynamic charging mode status
- `trydan/sensor/contracted_power` - Contracted power limit
- `trydan/sensor/firmware_version` - Device firmware version
- `trydan/sensor/device_id` - Unique device identifier
- `trydan/sensor/ip_address` - Device IP address
- `trydan/sensor/signal_status` - Communication signal status
- `trydan/data` - Complete data as JSON with timestamp
- `trydan/availability` - Device availability (online/offline)

#### Command Topics
Send commands to control the charger:
- `trydan/command/set_charge_current` - Set charging current (send amperage as payload)
- `trydan/command/pause_charge` - Pause charging
- `trydan/command/resume_charge` - Resume charging
- `trydan/command/lock` - Lock the charger
- `trydan/command/unlock` - Unlock the charger

#### Example Commands

Resume charging:
```bash
mosquitto_pub -h localhost -t "trydan/command/resume_charge" -m ""
```

Set charging current to 16A:
```bash
mosquitto_pub -h localhost -t "trydan/command/set_charge_current" -m "16"
```

Pause charging:
```bash
mosquitto_pub -h localhost -t "trydan/command/pause_charge" -m ""
```

Lock charger:
```bash
mosquitto_pub -h localhost -t "trydan/command/lock" -m ""
```

## Troubleshooting

### Common Issues

1. **Cannot connect to Trydan device**:
   - Check IP address in configuration
   - Verify network connectivity: `ping <trydan_ip>`
   - Ensure Modbus TCP is enabled on Trydan
   - Check firewall settings

2. **Cannot connect to MQTT broker**:
   - Verify MQTT broker is running
   - Check credentials and connection settings
   - Test with mosquitto client tools

3. **Service won't start**:
   - Check logs: `sudo journalctl -u trydan2mqtt -f`
   - Verify configuration file syntax
   - Check file permissions

4. **No data being published**:
   - Check Trydan connection status in logs
   - Verify MQTT topic configuration
   - Test with MQTT client: `mosquitto_sub -h <broker> -t "trydan/#"`

### Logs

View application logs:
```bash
# Service logs
sudo journalctl -u trydan2mqtt -f

# Application log file
sudo tail -f /var/log/trydan2mqtt.log
```

### Testing Connectivity

Test Trydan connection:
```bash
# Python test script
python3 -c "
import asyncio
from pytrydan import Trydan

async def test():
    trydan = Trydan('192.168.1.100')
    await trydan.connect()
    status = await trydan.get_status()
    print(f'Status: {status}')
    await trydan.disconnect()

asyncio.run(test())
"
```

Test MQTT connection:
```bash
# Subscribe to all topics
mosquitto_sub -h <mqtt_broker> -t "trydan/#"

# Publish test message
mosquitto_pub -h <mqtt_broker> -t "test/topic" -m "Hello MQTT"
```

## Security Considerations

- **Network Security**: Ensure Trydan device is on a secure network
- **MQTT Security**: Use TLS/SSL for MQTT connections when possible
- **Authentication**: Configure MQTT username/password authentication
- **Firewall**: Restrict access to necessary ports only
- **Updates**: Keep the application and dependencies updated

### Enabling MQTT TLS

Update configuration for secure MQTT:

```yaml
mqtt:
  host: "your-mqtt-broker.com"
  port: 8883
  tls:
    enabled: true
    ca_certs: "/etc/ssl/certs/ca-certificates.crt"
```

## Development

### Project Structure

```
trydan2mqtt/
├── src/
│   └── trydan2mqtt.py          # Main application
├── config/
│   └── config.yaml             # Default configuration
├── systemd/
│   └── trydan2mqtt.service     # Systemd service file
├── scripts/
│   └── install.sh              # Installation script
├── requirements.txt            # Python dependencies
└── README.md                   # This file
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Testing

Run basic tests:
```bash
# Install development dependencies
pip3 install pytest pytest-asyncio

# Run tests (if available)
pytest tests/
```

## Uninstallation

To remove the application:

```bash
sudo ./scripts/install.sh uninstall
```

Or manually:
```bash
sudo systemctl stop trydan2mqtt
sudo systemctl disable trydan2mqtt
sudo rm /etc/systemd/system/trydan2mqtt.service
sudo rm -rf /opt/trydan2mqtt
sudo rm -rf /etc/trydan2mqtt
sudo userdel trydan2mqtt
sudo systemctl daemon-reload
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **GitHub Issues**: Report bugs and request features
- **Documentation**: Check this README and configuration files
- **Community**: Join discussions in the repository

## Acknowledgments

- [pytrydan](https://github.com/trydan-project/pytrydan) - Python library for Trydan EV chargers
- [paho-mqtt](https://github.com/eclipse/paho.mqtt.python) - MQTT client library