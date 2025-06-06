#!/usr/bin/env python3

import os
import pwd
import subprocess
import sys
from pathlib import Path

REPO_URL = "https://github.com/bentoluizv/foodtruck.git"
REPO_PATH = "/foodtruck"
TERRAFORM_USER = "terraform"


def check_root() -> None:
    """Check if the script is running with root privileges."""
    if os.geteuid() != 0:
        print("This script must be run as root (sudo)")
        sys.exit(1)


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


def user_exists(username: str) -> bool:
    """Check if a user exists."""
    try:
        pwd.getpwnam(username)
        return True
    except KeyError:
        return False


def set_permissions(path: str, mode: int, uid: int, gid: int) -> None:
    """Set permissions for a path."""
    os.chmod(path, mode)
    os.chown(path, uid, gid)


def clone_repository() -> None:
    """Clone the repository if it doesn't exist and set proper permissions."""
    repo_path = Path(REPO_PATH)

    # Check if repository already exists
    if repo_path.exists():
        print(f"Repository already exists at {REPO_PATH}")
        return

    print(f"Cloning repository from {REPO_URL}...")

    # Create directory and clone repository
    run_command(f"mkdir -p {REPO_PATH}")
    run_command(f"git clone {REPO_URL} {REPO_PATH}")

    # Get terraform user and group IDs
    if user_exists(TERRAFORM_USER):
        terraform_uid = pwd.getpwnam(TERRAFORM_USER).pw_uid
        terraform_gid = pwd.getpwnam(TERRAFORM_USER).pw_gid

        # Set ownership to terraform user
        print(f"Setting ownership to {TERRAFORM_USER}...")
        run_command(f"chown -R {TERRAFORM_USER}:{TERRAFORM_USER} {REPO_PATH}")

        # Set permissions (rwxr-xr-x)
        print("Setting directory permissions...")
        set_permissions(REPO_PATH, 0o755, terraform_uid, terraform_gid)

        # Set permissions for all files and subdirectories
        for root, dirs, files in os.walk(REPO_PATH):
            for d in dirs:
                set_permissions(
                    os.path.join(root, d), 0o755, terraform_uid, terraform_gid
                )
            for f in files:
                set_permissions(
                    os.path.join(root, f), 0o644, terraform_uid, terraform_gid
                )

        print("Repository cloned and permissions set successfully!")
    else:
        print(f"Error: User {TERRAFORM_USER} does not exist!")
        sys.exit(1)


def main() -> None:
    """Main function to clone repository."""
    check_root()
    clone_repository()


if __name__ == "__main__":
    main()
