#!/usr/bin/env python3

import os
import errno
import shutil
import requests


def check_and_create_directory(directory: str) -> None:
    """Creates a directory if it doesn't exist."""
    if not os.path.isdir(directory):
        print(f"WARNING: {directory} does not exist. Creating...")
        os.makedirs(directory)


def get_config_path() -> str:
    """Build absolute path for sublime-text configuration."""
    user_home_directory = os.path.expanduser('~')
    return f"{user_home_directory}/.config/sublime-text"


def install_package_control(config_path: str) -> None:
    """Install package control"""
    path = f"{config_path}/Installed Packages/Package Control.sublime-package"
    url = "https://packagecontrol.io/Package%20Control.sublime-package"
    response = requests.get(url)
    with open(path, "wb") as f:
        f.write(response.content)


def copy_user_configs(src_directory: str, dst_directory: str,
                      symlinks: bool = False) -> None:
    """Copy user configs from Packages/User."""
    for item in os.listdir(src_directory):
        src = os.path.join(src_directory, item)
        dst = os.path.join(dst_directory, item)
        if os.path.isdir(src):
            try:
                shutil.copytree(src, dst, symlinks)
            except OSError as exception:
                if exception.errno != errno.EEXIST:
                    raise
        else:
            shutil.copy2(src, dst)


if __name__ == "__main__":
    print(f"[*] Getting SublimeText configuration root path...")
    st_config_root_path = get_config_path()
    print(f"[+] Got SublimeText configuration root path: {st_config_root_path}")
    
    packages_path = f"{st_config_root_path}/Installed Packages"
    settings_path = f"{st_config_root_path}/Packages/User"

    print(f"[*] Checking and creating required directory structure... \
    ({packages_path}, {settings_path}")
    check_and_create_directory(packages_path)
    check_and_create_directory(settings_path)
    print(f"[+] Done")

    print("[*] Installing package control...")
    install_package_control(st_config_root_path)
    print("[+] Done")

    print("[*] Copying user configurations")
    copy_user_configs("DATA/cfg/sublime-text/Packages/User",
                      settings_path)
    print("[+] Done")
