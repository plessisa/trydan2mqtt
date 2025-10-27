from setuptools import setup, find_packages

setup(
    name="trydan2mqtt",
    version="1.1.0",
    description="Trydan to MQTT Bridge - Connect Trydan EV chargers to MQTT brokers",
    author="Your Name",
    author_email="your.email@example.com",
    packages=find_packages(),
    package_dir={"": "src"},
    py_modules=["trydan2mqtt"],
    entry_points={
        "console_scripts": [
            "trydan2mqtt=trydan2mqtt:cli_main",
        ],
    },
    install_requires=[
        "paho-mqtt>=1.6.0",
        "PyYAML>=6.0",
        "pytrydan>=0.8.0",
    ],
    python_requires=">=3.7",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
)