#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (sudo)"
    exit 1
fi

# Function to check if Docker is installed
is_docker_installed() {
    command -v docker >/dev/null 2>&1
}

# Function to check if Docker is running
is_docker_running() {
    docker info >/dev/null 2>&1
}

# Function to run commands with error handling
run_command() {
    if ! eval "$1"; then
        echo "Error executing command: $1"
        exit 1
    fi
}

# Setup Docker repository
setup_docker_repository() {
    echo "Setting up Docker repository..."

    echo "Updating package index..."
    run_command "apt-get update"

    echo "Installing required packages..."
    run_command "apt-get install -y ca-certificates curl"

    echo "Adding Docker's GPG key..."
    run_command "install -m 0755 -d /etc/apt/keyrings"
    run_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
    run_command "chmod a+r /etc/apt/keyrings/docker.asc"

    echo "Adding Docker repository..."
    run_command 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null'

    echo "Updating package index..."
    run_command "apt-get update"
}

# Install Docker packages
install_docker_packages() {
    echo "Installing Docker Engine..."
    run_command "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
}

# Verify Docker installation
verify_docker_installation() {
    echo "Verifying Docker installation..."
    docker_version=$(docker --version)
    echo "Docker installed successfully: $docker_version"

    echo "Starting Docker service..."
    run_command "systemctl start docker"
    run_command "systemctl enable docker"
}

# Main installation function
install_docker() {
    # Check if Docker is already installed
    if is_docker_installed; then
        echo "Docker is already installed."

        # Check if Docker is running
        if is_docker_running; then
            echo "Docker daemon is running."
            return
        else
            echo "Docker is installed but not running. Starting Docker service..."
            run_command "systemctl start docker"
            run_command "systemctl enable docker"
            return
        fi
    fi

    echo "Starting Docker installation..."

    # Update package index
    echo "Updating package index..."
    run_command "apt-get update"

    # Setup repository and install
    setup_docker_repository

    # Update package index with new repository
    echo "Updating package index with Docker repository..."
    run_command "apt-get update"

    # Install Docker
    install_docker_packages

    # Verify installation
    verify_docker_installation

    echo "Docker installation completed successfully!"
}

# Run the installation
install_docker