#!/bin/bash
# Trydan to MQTT Bridge Installation Script
# This script installs and configures the Trydan to MQTT bridge on Linux systems

set -e

# Configuration
APP_NAME="trydan2mqtt"
APP_DIR="/opt/$APP_NAME"
CONFIG_DIR="/etc/$APP_NAME"
LOG_DIR="/var/log"
SERVICE_FILE="systemd/$APP_NAME.service"
SYSTEMD_DIR="/etc/systemd/system"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    log_info "Detected distribution: $DISTRO $VERSION"
}

# Install system dependencies
install_dependencies() {
    log_info "Installing system dependencies..."
    
    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y python3 python3-pip python3-venv python3-systemd git
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y python3 python3-pip python3-systemd git
            else
                yum install -y python3 python3-pip python3-systemd git
            fi
            ;;
        arch)
            pacman -Sy --noconfirm python python-pip python-systemd git
            ;;
        *)
            log_warning "Unsupported distribution: $DISTRO"
            log_info "Please install python3, python3-pip, and git manually"
            ;;
    esac
    
    log_success "System dependencies installed"
}

# Create application user
create_user() {
    log_info "Creating application user..."
    
    if ! id "$APP_NAME" &>/dev/null; then
        useradd --system --home-dir $APP_DIR --create-home --shell /bin/false $APP_NAME
        log_success "User '$APP_NAME' created"
    else
        log_info "User '$APP_NAME' already exists"
    fi
}

# Install application files
install_application() {
    log_info "Installing application files..."
    
    # Create directories
    mkdir -p $APP_DIR
    mkdir -p $CONFIG_DIR
    
    # Copy application files
    cp -r src/ $APP_DIR/
    echo "Installing configuration files..."
    cp config/config.yaml $CONFIG_DIR/
    
    # Set permissions
    chown -R $APP_NAME:$APP_NAME $APP_DIR
    chown -R $APP_NAME:$APP_NAME $CONFIG_DIR
    chmod +x $APP_DIR/src/$APP_NAME.py
    
    log_success "Application files installed"
}

# Install Python dependencies
install_python_deps() {
    log_info "Installing Python dependencies..."
    
    # Install pytrydan system package if available
    case $DISTRO in
        ubuntu|debian)
            if apt-cache show python3-pytrydan &>/dev/null; then
                apt-get install -y python3-pytrydan
                log_success "Installed python3-pytrydan from system packages"
            else
                log_warning "python3-pytrydan not available in system packages"
            fi
            ;;
    esac
    
    # Install other dependencies via pip
    pip3 install -r requirements.txt
    
    log_success "Python dependencies installed"
}

# Install systemd service
install_service() {
    log_info "Installing systemd service..."
    
    cp $SERVICE_FILE $SYSTEMD_DIR/
    systemctl daemon-reload
    systemctl enable $APP_NAME.service
    
    log_success "Systemd service installed and enabled"
}

# Configure firewall (if needed)
configure_firewall() {
    log_info "Checking firewall configuration..."
    
    # Check if firewall is active
    if systemctl is-active --quiet ufw; then
        log_info "UFW detected, you may need to allow MQTT traffic (port 1883/8883)"
        log_info "Run: sudo ufw allow 1883 (for standard MQTT)"
        log_info "Run: sudo ufw allow 8883 (for MQTT over TLS)"
    elif systemctl is-active --quiet firewalld; then
        log_info "Firewalld detected, you may need to allow MQTT traffic"
        log_info "Run: sudo firewall-cmd --permanent --add-port=1883/tcp"
        log_info "Run: sudo firewall-cmd --reload"
    fi
}

# Create log rotation
setup_logging() {
    log_info "Setting up log rotation..."
    
    cat > /etc/logrotate.d/$APP_NAME << EOF
$LOG_DIR/$APP_NAME.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $APP_NAME $APP_NAME
    postrotate
        systemctl reload $APP_NAME.service
    endscript
}
EOF
    
    log_success "Log rotation configured"
}

# Configuration helper
configure_app() {
    log_info "Application installed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Edit the configuration file: $CONFIG_DIR/config.yaml"
    echo "2. Update the Trydan device IP address and MQTT broker settings"
    echo "3. Start the service: sudo systemctl start $APP_NAME"
    echo "4. Check service status: sudo systemctl status $APP_NAME"
    echo "5. View logs: sudo journalctl -u $APP_NAME -f"
    echo
    log_warning "Remember to configure your firewall if needed!"
}

# Uninstall function
uninstall() {
    log_info "Uninstalling $APP_NAME..."
    
    # Stop and disable service
    systemctl stop $APP_NAME.service 2>/dev/null || true
    systemctl disable $APP_NAME.service 2>/dev/null || true
    
    # Remove files
    rm -f $SYSTEMD_DIR/$APP_NAME.service
    rm -rf $APP_DIR
    rm -rf $CONFIG_DIR
    rm -f /etc/logrotate.d/$APP_NAME
    
    # Remove user
    userdel $APP_NAME 2>/dev/null || true
    
    systemctl daemon-reload
    
    log_success "Uninstallation complete"
}

# Main installation function
install() {
    log_info "Starting installation of $APP_NAME..."
    
    check_root
    detect_distro
    install_dependencies
    create_user
    install_application
    install_python_deps
    install_service
    setup_logging
    configure_firewall
    configure_app
    
    log_success "Installation completed successfully!"
}

# Script usage
usage() {
    echo "Usage: $0 [install|uninstall]"
    echo
    echo "Commands:"
    echo "  install     Install the Trydan to MQTT bridge"
    echo "  uninstall   Remove the Trydan to MQTT bridge"
    echo
    exit 1
}

# Main script logic
case "${1:-install}" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        usage
        ;;
esac