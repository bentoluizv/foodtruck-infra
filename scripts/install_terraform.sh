#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (sudo)"
    exit 1
fi

# Function to run commands with error handling
run_command() {
    if ! eval "$1"; then
        echo "Error executing command: $1"
        exit 1
    fi
}

# Function to get latest Terraform version
get_latest_terraform_version() {
    local version
    version=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')
    if [ -z "$version" ]; then
        echo "Error fetching Terraform version"
        exit 1
    fi
    echo "$version"
}

# Function to verify checksum
verify_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local actual_checksum

    actual_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
    if [ "$actual_checksum" != "$expected_checksum" ]; then
        echo "Error: Checksum verification failed!"
        exit 1
    fi
}

# Function to install required dependencies
install_required_dependencies() {
    echo "Installing required dependencies..."
    run_command "apt-get update && apt-get install -y unzip curl jq"
}

# Function to download and install Terraform
install_terraform() {
    echo "Starting Terraform installation..."

    # Get latest version
    local version
    version=$(get_latest_terraform_version)
    echo "Latest Terraform version: $version"

    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT

    echo "Downloading Terraform files..."

    # Download Terraform binary
    local download_url="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip"
    local terraform_zip="${temp_dir}/terraform.zip"
    run_command "curl -L ${download_url} -o ${terraform_zip}"

    # Download and process checksum file
    local checksum_url="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_SHA256SUMS"
    local checksum_file="${temp_dir}/terraform_SHA256SUMS"
    run_command "curl -L ${checksum_url} -o ${checksum_file}"

    # Extract the checksum for the zip file
    local expected_checksum
    expected_checksum=$(grep terraform_linux_amd64.zip "$checksum_file" | cut -d' ' -f1)

    # Verify checksum
    verify_checksum "$terraform_zip" "$expected_checksum"

    # Install dependencies
    install_required_dependencies

    # Extract and install
    echo "Extracting and installing Terraform..."
    run_command "unzip ${terraform_zip} -d ${temp_dir}"
    run_command "mv ${temp_dir}/terraform /usr/local/bin/"

    # Verify installation
    echo "Verifying installation..."
    local terraform_version
    terraform_version=$(terraform --version)
    echo "Terraform installed successfully: $terraform_version"

    echo "Terraform installation completed successfully!"
}

# Run the installation
install_terraform