import grp
import os
import pwd
import subprocess
import sys

USERNAME = "terraform"
PRIMARY_GROUP = USERNAME
HOME_DIR = f"/home/{USERNAME}"
DEFAULT_SHELL = "/bin/bash"
DOCKER_GROUP = "docker"
ROOT_AUTH_KEYS_PATH = "/root/.ssh/authorized_keys"


def check_root():
    if os.geteuid() != 0:
        print("Este script precisa ser executado como root (use sudo).")
        sys.exit(1)


def group_exists(groupname):
    try:
        grp.getgrnam(groupname)
        return True
    except KeyError:
        return False


def user_exists(username):
    try:
        pwd.getpwnam(username)
        return True
    except KeyError:
        return False


def create_group(groupname):
    print(f"Criando grupo '{groupname}'...")
    subprocess.run(["groupadd", groupname], check=True)


def create_user(username, groupname, home_dir, shell_path):
    print(f"Criando usuário '{username}'...")
    subprocess.run(
        ["useradd", "-m", "-d", home_dir, "-s", shell_path, "-g", groupname, username],
        check=True,
    )


def set_permissions(path, mode, uid, gid):
    os.chmod(path, mode)
    os.chown(path, uid, gid)


def ensure_home_permissions(username, home_dir):
    uid = pwd.getpwnam(username).pw_uid
    gid = pwd.getpwnam(username).pw_gid
    set_permissions(home_dir, 0o700, uid, gid)


def add_user_to_group(username, groupname):
    print(f"Adicionando usuário '{username}' ao grupo '{groupname}'...")
    subprocess.run(["usermod", "-aG", groupname, username], check=True)


def copy_root_authorized_keys_to_user(username, home_dir):
    ssh_dir = os.path.join(home_dir, ".ssh")
    authorized_keys_path = os.path.join(ssh_dir, "authorized_keys")

    uid = pwd.getpwnam(username).pw_uid
    gid = pwd.getpwnam(username).pw_gid

    print(f"Configurando acesso SSH para '{username}' copiando chaves do root...")

    os.makedirs(ssh_dir, mode=0o700, exist_ok=True)
    set_permissions(ssh_dir, 0o700, uid, gid)

    try:
        with open(ROOT_AUTH_KEYS_PATH, "r") as root_keys_file:
            root_authorized_keys = root_keys_file.read()
    except FileNotFoundError:
        print(f"Erro: arquivo '{ROOT_AUTH_KEYS_PATH}' não encontrado.")
        sys.exit(1)

    with open(authorized_keys_path, "w") as user_keys_file:
        user_keys_file.write(root_authorized_keys)

    set_permissions(authorized_keys_path, 0o600, uid, gid)


def print_user_info(username):
    print("\nInformações do usuário:")
    subprocess.run(["id", username])


def main():
    check_root()

    if not group_exists(PRIMARY_GROUP):
        create_group(PRIMARY_GROUP)
    else:
        print(f"Grupo '{PRIMARY_GROUP}' já existe.")

    if not user_exists(USERNAME):
        create_user(USERNAME, PRIMARY_GROUP, HOME_DIR, DEFAULT_SHELL)
    else:
        print(f"Usuário '{USERNAME}' já existe.")

    ensure_home_permissions(USERNAME, HOME_DIR)

    if group_exists(DOCKER_GROUP):
        add_user_to_group(USERNAME, DOCKER_GROUP)
    else:
        print("Grupo 'docker' não encontrado. Instale o Docker antes de prosseguir.")
        sys.exit(1)

    copy_root_authorized_keys_to_user(USERNAME, HOME_DIR)

    print("Configuração concluída com sucesso!")
    print_user_info(USERNAME)


if __name__ == "__main__":
    main()
