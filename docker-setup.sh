#!/bin/bash
# Setup script for Docker deployment with external MQTT broker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker and Docker Compose are installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    log_success "Docker and Docker Compose are installed"
}

# Update configuration with user input
update_config() {
    log_info "Configuring external MQTT broker settings..."
    
    # Prompt for MQTT broker details
    read -p "Enter your MQTT broker IP address (e.g., 192.168.1.50): " mqtt_host
    read -p "Enter MQTT broker port [1883]: " mqtt_port
    mqtt_port=${mqtt_port:-1883}
    
    read -p "Enter MQTT username: " mqtt_username
    read -s -p "Enter MQTT password: " mqtt_password
    echo  # New line after password input
    
    read -p "Enter Trydan device IP address (e.g., 192.168.1.100): " trydan_host
    
    # Update the Docker config
    sed -i.bak "s/host: \"192.168.1.50\"/host: \"$mqtt_host\"/g" docker/config/config.yaml
    sed -i "s/port: 1883/port: $mqtt_port/g" docker/config/config.yaml
    sed -i "s/username: \"your_mqtt_username\"/username: \"$mqtt_username\"/g" docker/config/config.yaml
    sed -i "s/password: \"your_mqtt_password\"/password: \"$mqtt_password\"/g" docker/config/config.yaml
    sed -i "s/host: \"192.168.1.100\"/host: \"$trydan_host\"/g" docker/config/config.yaml
    
    log_success "Configuration updated"
}

# Set proper permissions
set_permissions() {
    log_info "Setting proper permissions..."
    
    # Create directories if they don't exist
    mkdir -p docker/logs
    
    # Set permissions for log directories
    chmod 755 docker/logs
    
    log_success "Permissions set"
}

# Build and start services
start_services() {
    log_info "Building and starting services..."
    
    # Build the application
    docker-compose build trydan2mqtt
    
    # Start all services
    docker-compose up -d
    
    log_success "Services started"
    log_info "You can check the status with: docker-compose ps"
    log_info "View logs with: docker-compose logs -f"
}

# Test MQTT connectivity
test_mqtt_connection() {
    log_info "Testing MQTT connectivity..."
    
    # Extract MQTT settings from config
    mqtt_host=$(grep "host:" docker/config/config.yaml | head -n2 | tail -n1 | sed 's/.*host: "\(.*\)".*/\1/')
    mqtt_port=$(grep "port:" docker/config/config.yaml | head -n2 | tail -n1 | sed 's/.*port: \(.*\)/\1/')
    
    # Test connection using a simple Python script in a container
    docker run --rm --network host python:3.11-slim sh -c "
        pip install paho-mqtt > /dev/null 2>&1
        python -c \"
import paho.mqtt.client as mqtt
import time
import sys

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print('MQTT connection successful')
        client.disconnect()
    else:
        print(f'MQTT connection failed with code {rc}')
        sys.exit(1)

client = mqtt.Client()
client.on_connect = on_connect
try:
    client.connect('$mqtt_host', $mqtt_port, 60)
    client.loop_start()
    time.sleep(2)
    client.loop_stop()
except Exception as e:
    print(f'MQTT connection error: {e}')
    sys.exit(1)
\"
    " && log_success "MQTT broker is reachable" || log_warning "Could not connect to MQTT broker - please check your settings"
}

# Show service information
show_info() {
    echo
    log_info "Service Information:"
    echo "===================="
    echo "Application: Trydan to MQTT Bridge"
    echo "External MQTT Broker: $(grep "host:" docker/config/config.yaml | head -n2 | tail -n1 | sed 's/.*host: "\(.*\)".*/\1/')"
    echo "Trydan Device: $(grep "host:" docker/config/config.yaml | head -n1 | sed 's/.*host: "\(.*\)".*/\1/')"
    echo "MQTT Topic Prefix: $(grep "topic_prefix:" docker/config/config.yaml | sed 's/.*topic_prefix: "\(.*\)".*/\1/')"
    echo
    log_info "Common commands:"
    echo "  - Check status: docker-compose ps"
    echo "  - View logs: docker-compose logs -f"
    echo "  - Stop services: docker-compose down"
    echo "  - Restart: docker-compose restart"
    echo "  - Update config and restart: docker-compose restart trydan2mqtt"
    echo
    log_warning "The application uses host networking to access your existing MQTT broker"
}

# Main setup function
main() {
    log_info "Starting Docker setup for Trydan to MQTT Bridge (External MQTT)..."
    
    check_docker
    set_permissions
    update_config
    start_services
    test_mqtt_connection
    show_info
    
    log_success "Setup completed successfully!"
}

# Script execution
case "${1:-setup}" in
    setup)
        main
        ;;
    config)
        update_config
        ;;
    start)
        docker-compose up -d
        ;;
    stop)
        docker-compose down
        ;;
    logs)
        docker-compose logs -f
        ;;
    restart)
        docker-compose restart
        ;;
    test)
        test_mqtt_connection
        ;;
    *)
        echo "Usage: $0 [setup|config|start|stop|logs|restart|test]"
        echo
        echo "Commands:"
        echo "  setup      Full setup (default)"
        echo "  config     Update configuration only"
        echo "  start      Start services"
        echo "  stop       Stop services"
        echo "  logs       View logs"
        echo "  restart    Restart services"
        echo "  test       Test MQTT connectivity"
        exit 1
        ;;
esac