# Trydan to MQTT Bridge - Docker Deployment

This document provides instructions for deploying the Trydan to MQTT Bridge using Docker with your existing MQTT broker.

## Quick Start

1. **Prerequisites**:
   - Docker installed
   - Docker Compose installed
   - Existing MQTT broker on your network
   - Trydan EV charger accessible on your network

2. **Setup and run**:
   ```bash
   # Make setup script executable
   chmod +x docker-setup.sh
   
   # Run the interactive setup script
   ./docker-setup.sh
   ```
   
   The setup script will prompt you for:
   - Your MQTT broker IP address
   - MQTT broker port (default: 1883)
   - MQTT username and password
   - Your Trydan device IP address

3. **Manual configuration** (alternative to setup script):
   ```bash
   # Edit the configuration file
   nano docker/config/config.yaml
   
   # Update these settings:
   # - Trydan host IP address
   # - MQTT broker host IP address
   # - MQTT credentials
   ```

4. **Start the application**:
   ```bash
   docker-compose up -d
   ```

## Configuration

### Application Configuration

Edit `docker/config/config.yaml`:

```yaml
# Trydan EV Charger Configuration
trydan:
  host: "192.168.1.100"    # Your Trydan device IP
  port: 502                # Modbus port
  slave_id: 1              # Modbus slave ID

# External MQTT Broker Configuration
mqtt:
  host: "192.168.1.50"     # Your MQTT broker IP
  port: 1883               # Your MQTT broker port
  client_id: "trydan2mqtt"
  topic_prefix: "trydan"   # Generic topic prefix
  username: "your_mqtt_username"
  password: "your_mqtt_password"
  
  # Enable TLS if your broker supports it
  tls:
    enabled: false
```

### Environment Variables

You can also use environment variables by copying `.env.example` to `.env`:

```bash
cp .env.example .env
nano .env
```

## Docker Configuration

### Network Mode

The application uses **host networking** (`network_mode: "host"`) to access your existing MQTT broker and Trydan device on your local network. This means:

- The container shares the host's network interface
- No port mapping is needed
- The container can directly access devices on your network
- Security isolation is reduced but connectivity is simplified

### Services

The Docker Compose setup includes:

- **🔌 Trydan2MQTT Bridge**: Your Python application in a container

## Usage

### Common Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f trydan2mqtt
docker-compose logs -f mosquitto

# Restart a service
docker-compose restart trydan2mqtt

# Rebuild and restart
docker-compose up -d --build

# Check service status
docker-compose ps
```

### Testing MQTT Connection

```bash
# Test MQTT connection using mosquitto clients
# Subscribe to all Trydan topics
mosquitto_sub -h YOUR_MQTT_BROKER_IP -u your_username -P your_password -t "trydan/#"

# Publish a test command
mosquitto_pub -h YOUR_MQTT_BROKER_IP -u your_username -P your_password -t "trydan/command/start_charge" -m ""
```

### Using Docker Container for Testing

```bash
# Test MQTT connection from a container
docker run --rm --network host eclipse-mosquitto:2.0 \
  mosquitto_sub -h YOUR_MQTT_BROKER_IP -u your_username -P your_password -t "trydan/#"
```

### Accessing Logs

```bash
# Application logs
docker-compose logs -f trydan2mqtt

# All logs
docker-compose logs -f

# Container logs (alternative)
docker logs trydan-bridge -f
```

## MQTT Topics

The application publishes to these topics on your existing MQTT broker:

### Status Topics
- `trydan/sensor/status`
- `trydan/sensor/charging_current`
- `trydan/sensor/charging_power`
- `trydan/sensor/energy_delivered`
- `trydan/sensor/temperature`
- `trydan/sensor/voltage`
- `trydan/sensor/frequency`
- `trydan/data` (JSON)
- `trydan/availability`

### Command Topics
- `trydan/command/start_charge`
- `trydan/command/stop_charge`
- `trydan/command/set_charge_current`
- `trydan/command/set_charge_mode`

## Troubleshooting

### Container Won't Start

1. **Check logs**:
   ```bash
   docker-compose logs trydan2mqtt
   ```

2. **Verify configuration**:
   ```bash
   # Check config syntax
   docker run --rm -v "$(pwd)/docker/config:/config" python:3.11-slim python -c "
   import yaml
   with open('/config/config.yaml') as f:
       yaml.safe_load(f)
   print('Configuration is valid')
   "
   ```

3. **Check network connectivity**:
   ```bash
   # Test Trydan connectivity from container
   docker run --rm --network trydan2mqtt_trydan-network python:3.11-slim \
     python -c "import socket; socket.create_connection(('192.168.1.100', 502), timeout=5); print('Trydan reachable')"
   ```

### MQTT Connection Issues

1. **Verify MQTT credentials**:
   ```bash
   # Test MQTT connection
   docker exec -it trydan-mosquitto mosquitto_sub -h localhost -u trydan2mqtt -P your_password -t "test"
   ```

2. **Check Mosquitto logs**:
   ```bash
   docker-compose logs mosquitto
   ```

3. **Reset MQTT passwords**:
   ```bash
   ./docker-setup.sh passwords
   ```

### No Data Published

1. **Check Trydan connection** in application logs
2. **Verify Trydan IP address** in configuration
3. **Test MQTT publishing**:
   ```bash
   # Manual test publish
   docker exec -it trydan-mosquitto mosquitto_pub -h localhost -u trydan2mqtt -P your_password -t "test/topic" -m "test message"
   ```

### Performance Issues

1. **Adjust polling interval** in configuration
2. **Check system resources**:
   ```bash
   docker stats
   ```

3. **Monitor log sizes**:
   ```bash
   du -sh docker/logs/
   ```

## Security Considerations

### Network Security
- The application runs in an isolated Docker network
- Only necessary ports are exposed
- Consider using Docker secrets for passwords in production

### MQTT Security
- Strong passwords are required for MQTT authentication
- Consider enabling TLS for MQTT connections in production
- Restrict MQTT ACL rules based on your needs

### Container Security
- Containers run as non-root users
- File system permissions are properly configured
- Consider using read-only file systems in production

## Backup and Maintenance

### Backup Important Data

```bash
# Backup configuration
cp -r docker/config/ backup/config-$(date +%Y%m%d)/
```

### Update Application

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose up -d --build

# Or rebuild specific service
docker-compose build trydan2mqtt
docker-compose up -d trydan2mqtt
```

### Log Rotation

Consider setting up log rotation for Docker logs:

```bash
# Add to docker-compose.yml for each service
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## Production Deployment

For production deployment, consider:

1. **Use Docker secrets** for passwords
2. **Enable TLS** for MQTT connections
3. **Set up log rotation**
4. **Configure health checks**
5. **Use a reverse proxy** (nginx/traefik) if exposing services
6. **Regular backups** of configuration and data
7. **Monitor container health** and restart policies

## Support

- Check logs with `docker-compose logs -f`
- Verify configuration files
- Test network connectivity
- Consult the main README.md for application-specific troubleshooting