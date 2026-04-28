import os
import sys
import subprocess
import shutil
import tempfile
from pathlib import Path

import requests

REPO = "generallyy/platformer-brackeys-2"
GAME_EXE = "lucasywin.exe"
VERSION_FILE = "version.txt"
API_URL = f"https://api.github.com/repos/{REPO}/releases/latest"


def get_launcher_dir():
    # When compiled with PyInstaller, use the exe's directory, not the temp extract dir
    if getattr(sys, "frozen", False):
        return Path(sys.executable).parent
    return Path(__file__).parent


def get_local_version(base_dir):
    path = base_dir / VERSION_FILE
    if path.exists():
        return path.read_text().strip()
    return None


def get_latest_release():
    print("Checking for updates...")
    try:
        resp = requests.get(API_URL, timeout=10)
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"Could not reach GitHub: {e}")
        return None, None
    data = resp.json()
    return data["tag_name"], data["assets"]


def find_exe_asset(assets):
    for asset in assets:
        if asset["name"].lower().endswith(".exe"):
            return asset
    return None


def download(url, dest, label):
    print(f"Downloading {label}...")
    with requests.get(url, stream=True, timeout=60) as resp:
        resp.raise_for_status()
        total = int(resp.headers.get("content-length", 0))
        downloaded = 0
        with open(dest, "wb") as f:
            for chunk in resp.iter_content(chunk_size=65536):
                f.write(chunk)
                downloaded += len(chunk)
                if total:
                    pct = downloaded * 100 // total
                    print(f"\r  {pct}%", end="", flush=True)
    print()


def main():
    base_dir = get_launcher_dir()
    game_path = base_dir / GAME_EXE

    local_version = get_local_version(base_dir)
    latest_tag, assets = get_latest_release()

    if latest_tag is None:
        # No internet — launch whatever we have
        if game_path.exists():
            print("Offline — launching existing version.")
        else:
            input("No internet and no game found. Press Enter to exit.")
            return
    elif local_version == latest_tag:
        print(f"Already up to date ({latest_tag}).")
    else:
        exe_asset = find_exe_asset(assets)
        if exe_asset is None:
            print("No .exe found in latest release. Launching existing version.")
        else:
            tmp = Path(tempfile.mktemp(suffix=".exe"))
            try:
                download(exe_asset["browser_download_url"], tmp, latest_tag)
                shutil.move(str(tmp), str(game_path))
                (base_dir / VERSION_FILE).write_text(latest_tag)
                print(f"Updated to {latest_tag}.")
            except Exception as e:
                print(f"Download failed: {e}")
                tmp.unlink(missing_ok=True)
                if not game_path.exists():
                    input("No game to launch. Press Enter to exit.")
                    return

    if not game_path.exists():
        input(f"{GAME_EXE} not found. Press Enter to exit.")
        return

    print(f"Launching {GAME_EXE}...")
    subprocess.Popen([str(game_path)], cwd=str(base_dir))


if __name__ == "__main__":
    main()
