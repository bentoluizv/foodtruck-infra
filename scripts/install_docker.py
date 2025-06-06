#!/usr/bin/env python3

import os
import subprocess
import sys


def run_command(command: str) -> str:
    """Run a shell command and return its output."""
    try:
        result = subprocess.run(
            command,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {command}")
        print(f"Error: {e.stderr}")
        sys.exit(1)


def is_docker_installed() -> bool:
    """Check if Docker is installed on the system."""
    try:
        # Check if docker command exists
        subprocess.run(
            ["which", "docker"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def is_docker_running() -> bool:
    """Check if Docker daemon is running."""
    try:
        subprocess.run(
            ["docker", "info"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def setup_docker_repository() -> None:
    """Set up Docker's official repository."""
    print("Setting up Docker repository...")

    print("Updating package index...")
    run_command("apt-get update")

    # Install required packages
    print("Installing required packages...")
    run_command("apt-get install ca-certificates curl")

    # Add Docker's official GPG key
    print("Adding Docker's GPG key...")
    run_command("install -m 0755 -d /etc/apt/keyrings")
    run_command(
        "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
    )
    run_command("chmod a+r /etc/apt/keyrings/docker.asc")

    # Add Docker repository
    print("Adding Docker repository...")
    run_command(
        'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] '
        'https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | '
        "tee /etc/apt/sources.list.d/docker.list > /dev/null"
    )

    print("Updating package index...")
    run_command("apt-get update")


def install_docker_packages() -> None:
    """Install Docker Engine and related packages."""
    print("Installing Docker Engine...")
    run_command(
        "apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    )


def verify_docker_installation() -> None:
    """Verify Docker installation and start the service."""
    print("Verifying Docker installation...")
    docker_version = run_command("docker --version")
    print(f"Docker installed successfully: {docker_version.strip()}")

    print("Starting Docker service...")
    run_command("systemctl start docker")
    run_command("systemctl enable docker")


def install_docker() -> None:
    """Install Docker on Ubuntu/Debian system."""
    # Check if Docker is already installed
    if is_docker_installed():
        print("Docker is already installed.")

        # Check if Docker is running
        if is_docker_running():
            print("Docker daemon is running.")
            return
        else:
            print("Docker is installed but not running. Starting Docker service...")
            run_command("systemctl start docker")
            run_command("systemctl enable docker")
            return

    print("Starting Docker installation...")

    # Update package index
    print("Updating package index...")
    run_command("apt-get update")

    # Setup repository and install
    setup_docker_repository()

    # Update package index with new repository
    print("Updating package index with Docker repository...")
    run_command("apt-get update")

    # Install Docker
    install_docker_packages()

    # Verify installation
    verify_docker_installation()

    print("Docker installation completed successfully!")


def check_root() -> None:
    """Check if the script is running with root privileges."""
    if os.geteuid() != 0:
        print("This script must be run as root (sudo)")
        sys.exit(1)


def main() -> None:
    """Main function to install Docker."""
    check_root()
    install_docker()


if __name__ == "__main__":
    main()
