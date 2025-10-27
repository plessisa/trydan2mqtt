#!/usr/bin/env python3
"""
Trydan to MQTT Bridge
A Linux application that connects to Trydan EV chargers and publishes data to MQTT
"""

import asyncio
import json
import logging
import os
import signal
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional

import paho.mqtt.client as mqtt
import yaml
from pytrydan import Trydan


class TrydanMQTTBridge:
    """Bridge between Trydan EV charger and MQTT broker"""
    
    def __init__(self, config_path: str = "/etc/trydan2mqtt/config.yaml"):
        """Initialize the bridge with configuration"""
        self.config_path = config_path
        self.config = self._load_config()
        self.logger = self._setup_logging()
        
        # Initialize components
        self.trydan = None
        self.mqtt_client = None
        self.running = False
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as file:
                config = yaml.safe_load(file)
                
            # Validate required configuration
            required_sections = ['trydan', 'mqtt', 'bridge']
            for section in required_sections:
                if section not in config:
                    raise ValueError(f"Missing required configuration section: {section}")
                    
            return config
        except FileNotFoundError:
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML configuration: {e}")
    
    def _setup_logging(self) -> logging.Logger:
        """Setup logging configuration"""
        log_level = self.config.get('logging', {}).get('level', 'INFO')
        log_format = self.config.get('logging', {}).get('format', 
                                   '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        
        # Setup handlers list
        handlers = [logging.StreamHandler(sys.stdout)]
        
        # Add file handler if log directory exists (for container/systemd deployment)
        log_dir = '/app/logs' if Path('/app/logs').exists() else '/var/log'
        if Path(log_dir).exists() and Path(log_dir).is_dir():
            try:
                handlers.append(logging.FileHandler(f'{log_dir}/trydan2mqtt.log'))
            except PermissionError:
                # If we can't write to log directory, just use stdout
                pass
        
        logging.basicConfig(
            level=getattr(logging, log_level.upper()),
            format=log_format,
            handlers=handlers
        )
        
        return logging.getLogger('trydan2mqtt')
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False
    
    async def _connect_trydan(self) -> bool:
        """Connect to Trydan device"""
        try:
            trydan_config = self.config['trydan']
            
            self.trydan = Trydan(
                host=trydan_config['host'],
                port=trydan_config.get('port', 502),
                slave_id=trydan_config.get('slave_id', 1)
            )
            
            # Test connection
            await self.trydan.connect()
            self.logger.info(f"Connected to Trydan device at {trydan_config['host']}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to connect to Trydan device: {e}")
            return False
    
    def _connect_mqtt(self) -> bool:
        """Connect to MQTT broker"""
        try:
            mqtt_config = self.config['mqtt']
            
            self.mqtt_client = mqtt.Client(
                client_id=mqtt_config.get('client_id', 'trydan2mqtt'),
                protocol=mqtt.MQTTv311
            )
            
            # Set up authentication if provided
            if 'username' in mqtt_config and 'password' in mqtt_config:
                self.mqtt_client.username_pw_set(
                    mqtt_config['username'], 
                    mqtt_config['password']
                )
            
            # Set up TLS if enabled
            if mqtt_config.get('tls', {}).get('enabled', False):
                tls_config = mqtt_config['tls']
                self.mqtt_client.tls_set(
                    ca_certs=tls_config.get('ca_certs'),
                    certfile=tls_config.get('certfile'),
                    keyfile=tls_config.get('keyfile')
                )
            
            # Set up callbacks
            self.mqtt_client.on_connect = self._on_mqtt_connect
            self.mqtt_client.on_disconnect = self._on_mqtt_disconnect
            self.mqtt_client.on_message = self._on_mqtt_message
            
            # Connect to broker
            self.mqtt_client.connect(
                mqtt_config['host'],
                mqtt_config.get('port', 1883),
                mqtt_config.get('keepalive', 60)
            )
            
            self.mqtt_client.loop_start()
            self.logger.info(f"Connected to MQTT broker at {mqtt_config['host']}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to connect to MQTT broker: {e}")
            return False
    
    def _on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            self.logger.info("MQTT connected successfully")
            
            # Subscribe to command topics
            command_topic = f"{self.config['mqtt']['topic_prefix']}/command/+"
            client.subscribe(command_topic)
            self.logger.info(f"Subscribed to command topic: {command_topic}")
        else:
            self.logger.error(f"MQTT connection failed with code {rc}")
    
    def _on_mqtt_disconnect(self, client, userdata, rc):
        """MQTT disconnection callback"""
        if rc != 0:
            self.logger.warning("Unexpected MQTT disconnection")
    
    def _on_mqtt_message(self, client, userdata, msg):
        """Handle incoming MQTT messages"""
        try:
            topic_parts = msg.topic.split('/')
            if len(topic_parts) >= 3 and topic_parts[-2] == 'command':
                command = topic_parts[-1]
                payload = msg.payload.decode('utf-8')
                
                self.logger.info(f"Received command: {command} with payload: {payload}")
                asyncio.create_task(self._handle_command(command, payload))
                
        except Exception as e:
            self.logger.error(f"Error processing MQTT message: {e}")
    
    async def _handle_command(self, command: str, payload: str):
        """Handle commands received via MQTT"""
        try:
            if not self.trydan:
                self.logger.error("Trydan device not connected")
                return
            
            if command == "set_charge_current":
                current = float(payload)
                await self.trydan.set_charge_current(current)
                self.logger.info(f"Set charge current to {current}A")
                
            elif command == "start_charge":
                await self.trydan.start_charge()
                self.logger.info("Started charging")
                
            elif command == "stop_charge":
                await self.trydan.stop_charge()
                self.logger.info("Stopped charging")
                
            elif command == "set_charge_mode":
                mode = payload.strip()
                await self.trydan.set_charge_mode(mode)
                self.logger.info(f"Set charge mode to {mode}")
                
            else:
                self.logger.warning(f"Unknown command: {command}")
                
        except Exception as e:
            self.logger.error(f"Error handling command {command}: {e}")
    
    async def _read_trydan_data(self) -> Optional[Dict[str, Any]]:
        """Read data from Trydan device"""
        try:
            if not self.trydan:
                return None
            
            # Read various data points from the device
            data = {
                'timestamp': datetime.now().isoformat(),
                'status': await self.trydan.get_status(),
                'charging_current': await self.trydan.get_charging_current(),
                'charging_power': await self.trydan.get_charging_power(),
                'energy_delivered': await self.trydan.get_energy_delivered(),
                'temperature': await self.trydan.get_temperature(),
                'voltage': await self.trydan.get_voltage(),
                'frequency': await self.trydan.get_frequency(),
            }
            
            return data
            
        except Exception as e:
            self.logger.error(f"Error reading Trydan data: {e}")
            return None
    
    def _publish_data(self, data: Dict[str, Any]):
        """Publish data to MQTT"""
        try:
            if not self.mqtt_client or not data:
                return
            
            topic_prefix = self.config['mqtt']['topic_prefix']
            
            # Publish individual data points
            for key, value in data.items():
                if key != 'timestamp':
                    topic = f"{topic_prefix}/sensor/{key}"
                    self.mqtt_client.publish(topic, str(value), retain=True)
            
            # Publish complete data as JSON
            json_topic = f"{topic_prefix}/data"
            self.mqtt_client.publish(json_topic, json.dumps(data), retain=True)
            
            self.logger.debug("Published data to MQTT")
            
        except Exception as e:
            self.logger.error(f"Error publishing data to MQTT: {e}")
    
    def _publish_availability(self, available: bool):
        """Publish device availability status"""
        try:
            if not self.mqtt_client:
                return
            
            topic = f"{self.config['mqtt']['topic_prefix']}/availability"
            status = "online" if available else "offline"
            self.mqtt_client.publish(topic, status, retain=True)
            
        except Exception as e:
            self.logger.error(f"Error publishing availability: {e}")
    
    async def run(self):
        """Main application loop"""
        self.logger.info("Starting Trydan to MQTT bridge")
        
        # Connect to devices
        if not await self._connect_trydan():
            self.logger.error("Failed to connect to Trydan device, exiting")
            return
        
        if not self._connect_mqtt():
            self.logger.error("Failed to connect to MQTT broker, exiting")
            return
        
        # Set availability to online
        self._publish_availability(True)
        
        # Main loop
        self.running = True
        poll_interval = self.config['bridge'].get('poll_interval', 30)
        
        self.logger.info(f"Bridge started, polling every {poll_interval} seconds")
        
        try:
            while self.running:
                # Read data from Trydan
                data = await self._read_trydan_data()
                
                if data:
                    # Publish to MQTT
                    self._publish_data(data)
                else:
                    self.logger.warning("No data received from Trydan device")
                
                # Wait for next poll
                await asyncio.sleep(poll_interval)
                
        except Exception as e:
            self.logger.error(f"Error in main loop: {e}")
        finally:
            await self._shutdown()
    
    async def _shutdown(self):
        """Cleanup and shutdown"""
        self.logger.info("Shutting down bridge")
        
        # Set availability to offline
        self._publish_availability(False)
        
        # Disconnect from Trydan
        if self.trydan:
            try:
                await self.trydan.disconnect()
            except Exception as e:
                self.logger.error(f"Error disconnecting from Trydan: {e}")
        
        # Disconnect from MQTT
        if self.mqtt_client:
            try:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
            except Exception as e:
                self.logger.error(f"Error disconnecting from MQTT: {e}")
        
        self.logger.info("Bridge shutdown complete")


async def main():
    """Main entry point"""
    # Support environment variable for config path (Docker-friendly)
    config_path = os.getenv('CONFIG_PATH', sys.argv[1] if len(sys.argv) > 1 else "/etc/trydan2mqtt/config.yaml")
    
    # For Docker deployment, try container-specific paths
    if not Path(config_path).exists():
        container_config = "/app/config/config.yaml"
        if Path(container_config).exists():
            config_path = container_config
    
    try:
        bridge = TrydanMQTTBridge(config_path)
        await bridge.run()
    except Exception as e:
        logging.error(f"Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())