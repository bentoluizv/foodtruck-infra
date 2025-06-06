#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (sudo)"
    exit 1
fi

# Constants
REPO_URL="https://github.com/bentoluizv/foodtruck.git"
REPO_PATH="/foodtruck"
TERRAFORM_USER="terraform"

# Function to run commands with error handling
run_command() {
    if ! eval "$1"; then
        echo "Error executing command: $1"
        exit 1
    fi
}

# Function to check if user exists
user_exists() {
    id "$1" >/dev/null 2>&1
}

# Function to set permissions
set_permissions() {
    run_command "chmod $1 $2"
    run_command "chown $3:$4 $2"
}

# Function to clone repository
clone_repository() {
    # Check if repository already exists
    if [ -d "$REPO_PATH" ]; then
        echo "Repository already exists at $REPO_PATH"
        return
    fi

    echo "Cloning repository from $REPO_URL..."

    # Create directory and clone repository
    run_command "mkdir -p $REPO_PATH"
    run_command "git clone $REPO_URL $REPO_PATH"

    # Get terraform user and group IDs
    if user_exists "$TERRAFORM_USER"; then
        local uid
        local gid
        uid=$(id -u "$TERRAFORM_USER")
        gid=$(id -g "$TERRAFORM_USER")

        # Set ownership to terraform user
        echo "Setting ownership to $TERRAFORM_USER..."
        run_command "chown -R $TERRAFORM_USER:$TERRAFORM_USER $REPO_PATH"

        # Set permissions (rwxr-xr-x)
        echo "Setting directory permissions..."
        set_permissions 755 "$REPO_PATH" "$uid" "$gid"

        # Set permissions for all files and subdirectories
        find "$REPO_PATH" -type d -exec chmod 755 {} \;
        find "$REPO_PATH" -type f -exec chmod 644 {} \;
        find "$REPO_PATH" -exec chown "$uid:$gid" {} \;

        echo "Repository cloned and permissions set successfully!"
    else
        echo "Error: User $TERRAFORM_USER does not exist!"
        exit 1
    fi
}

# Run the clone function
clone_repository