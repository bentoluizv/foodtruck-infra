#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (sudo)"
    exit 1
fi

# Constants
USERNAME="terraform"
PRIMARY_GROUP="$USERNAME"
HOME_DIR="/home/$USERNAME"
DEFAULT_SHELL="/bin/bash"
DOCKER_GROUP="docker"
ROOT_AUTH_KEYS_PATH="/root/.ssh/authorized_keys"

# Function to run commands with error handling
run_command() {
    if ! eval "$1"; then
        echo "Error executing command: $1"
        exit 1
    fi
}

# Function to check if group exists
group_exists() {
    getent group "$1" >/dev/null 2>&1
}

# Function to check if user exists
user_exists() {
    id "$1" >/dev/null 2>&1
}

# Function to create group
create_group() {
    echo "Creating group '$1'..."
    run_command "groupadd $1"
}

# Function to create user
create_user() {
    echo "Creating user '$1'..."
    run_command "useradd -m -d $2 -s $3 -g $4 $1"
}

# Function to set permissions
set_permissions() {
    run_command "chmod $1 $2"
    run_command "chown $3:$4 $2"
}

# Function to ensure home directory permissions
ensure_home_permissions() {
    local uid
    local gid
    uid=$(id -u "$1")
    gid=$(id -g "$1")
    set_permissions 700 "$2" "$uid" "$gid"
}

# Function to add user to group
add_user_to_group() {
    echo "Adding user '$1' to group '$2'..."
    run_command "usermod -aG $2 $1"
}

# Function to copy root authorized keys to user
copy_root_authorized_keys_to_user() {
    local ssh_dir="$2/.ssh"
    local authorized_keys_path="$ssh_dir/authorized_keys"
    local uid
    local gid

    uid=$(id -u "$1")
    gid=$(id -g "$1")

    echo "Setting up SSH access for '$1' by copying root keys..."

    run_command "mkdir -p $ssh_dir"
    set_permissions 700 "$ssh_dir" "$uid" "$gid"

    if [ ! -f "$ROOT_AUTH_KEYS_PATH" ]; then
        echo "Error: file '$ROOT_AUTH_KEYS_PATH' not found."
        exit 1
    fi

    run_command "cp $ROOT_AUTH_KEYS_PATH $authorized_keys_path"
    set_permissions 600 "$authorized_keys_path" "$uid" "$gid"
}

# Function to print user info
print_user_info() {
    echo -e "\nUser information:"
    id "$1"
}

# Main function
main() {
    if ! group_exists "$PRIMARY_GROUP"; then
        create_group "$PRIMARY_GROUP"
    else
        echo "Group '$PRIMARY_GROUP' already exists."
    fi

    if ! user_exists "$USERNAME"; then
        create_user "$USERNAME" "$HOME_DIR" "$DEFAULT_SHELL" "$PRIMARY_GROUP"
    else
        echo "User '$USERNAME' already exists."
    fi

    ensure_home_permissions "$USERNAME" "$HOME_DIR"

    if group_exists "$DOCKER_GROUP"; then
        add_user_to_group "$USERNAME" "$DOCKER_GROUP"
    else
        echo "Group 'docker' not found. Install Docker before proceeding."
        exit 1
    fi

    copy_root_authorized_keys_to_user "$USERNAME" "$HOME_DIR"

    echo "Setup completed successfully!"
    print_user_info "$USERNAME"
}

# Run the main function
main