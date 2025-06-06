#!/usr/bin/env python3

import hashlib
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Tuple

import requests


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


def get_latest_terraform_version() -> str:
    """Get the latest stable version of Terraform."""
    try:
        response = requests.get(
            "https://checkpoint-api.hashicorp.com/v1/check/terraform", timeout=10
        )
        response.raise_for_status()
        return response.json()["current_version"]
    except requests.RequestException as e:
        print(f"Error fetching Terraform version: {e}")
        sys.exit(1)


def verify_checksum(file_path: str, expected_checksum: str) -> bool:
    """Verify the SHA256 checksum of the downloaded file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest() == expected_checksum


def download_terraform_files(version: str, temp_dir: Path) -> Tuple[Path, str]:
    """Download Terraform binary and its checksum file."""
    print("Downloading Terraform files...")

    # Download Terraform binary
    download_url = f"https://releases.hashicorp.com/terraform/{version}/terraform_{version}_linux_amd64.zip"
    terraform_zip = temp_dir / "terraform.zip"
    run_command(f"curl -L {download_url} -o {terraform_zip}")

    # Download and process checksum file
    checksum_url = f"https://releases.hashicorp.com/terraform/{version}/terraform_{version}_SHA256SUMS"
    checksum_file = temp_dir / "terraform_SHA256SUMS"
    run_command(f"curl -L {checksum_url} -o {checksum_file}")

    # Extract the checksum for the zip file
    checksum_output = run_command(f"grep terraform_linux_amd64.zip {checksum_file}")
    expected_checksum = checksum_output.split()[0]

    return terraform_zip, expected_checksum


def install_required_dependencies() -> None:
    """Install required system dependencies."""
    print("Installing required dependencies...")
    run_command("apt-get update && apt-get install -y unzip")


def extract_and_install_terraform(temp_dir: Path) -> None:
    """Extract and install Terraform binary."""
    print("Extracting and installing Terraform...")

    # Extract Terraform
    run_command(f"unzip {temp_dir}/terraform.zip -d {temp_dir}")

    # Move to /usr/local/bin
    run_command(f"mv {temp_dir}/terraform /usr/local/bin/")


def verify_installation() -> None:
    """Verify Terraform installation."""
    print("Verifying installation...")
    terraform_version = run_command("terraform --version")
    print(f"Terraform installed successfully: {terraform_version.strip()}")


def install_terraform() -> None:
    """Install Terraform on Ubuntu/Debian system."""
    print("Starting Terraform installation...")

    # Get latest version
    version = get_latest_terraform_version()
    print(f"Latest Terraform version: {version}")

    # Create temporary directory
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        # Download files
        terraform_zip, expected_checksum = download_terraform_files(version, temp_path)

        # Verify checksum
        if not verify_checksum(str(terraform_zip), expected_checksum):
            print("Error: Checksum verification failed!")
            sys.exit(1)

        # Install dependencies
        install_required_dependencies()

        # Extract and install
        extract_and_install_terraform(temp_path)

        # Verify installation
        verify_installation()

    print("Terraform installation completed successfully!")


def check_root() -> None:
    """Check if the script is running with root privileges."""
    if os.geteuid() != 0:
        print("This script must be run as root (sudo)")
        sys.exit(1)


def main() -> None:
    """Main function to install Terraform."""
    check_root()
    install_terraform()


if __name__ == "__main__":
    main()
