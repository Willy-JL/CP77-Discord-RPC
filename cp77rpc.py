import os
import wmi
import time
import json
import psutil
import discord_rpc
import win32process
import pygetwindow as gw
from win32api import GetFileVersionInfo, LOWORD, HIWORD


def get_window_executable(hwnd):
    exe = None
    try:
        _, pid = win32process.GetWindowThreadProcessId(hwnd)
        for p in c.query('SELECT Name FROM Win32_Process WHERE ProcessId = %s' % str(pid)):
            exe = p.Name
            break
    except:
        return None
    else:
        return exe


def process_exists(name="Cyberpunk2077.exe"):
    for proc in psutil.process_iter():
        try:
            if proc.name() == name:
                if name == "Cyberpunk2077.exe":
                    global version
                    global start
                    if not version:
                        info = GetFileVersionInfo(proc.exe(), "\\")
                        ms = info['ProductVersionMS']
                        ls = info['ProductVersionLS']
                        version_tuple = (HIWORD(ms), LOWORD(ms), HIWORD(ls), LOWORD(ls))
                        version = ".".join([str (i) for i in version_tuple])
                    if not start:
                        start = proc.create_time()
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return False


version = None
start = None
path = os.getcwd()
root = "bin/x64/plugins/cyber_engine_tweaks/mods/CP77 Discord RPC/"
if path[-3:] == "bin":
    root = "x64/plugins/cyber_engine_tweaks/mods/CP77 Discord RPC/"
if path[-3:] == "x64":
    root = "plugins/cyber_engine_tweaks/mods/CP77 Discord RPC/"
if path[-7:] == "plugins":
    root = "cyber_engine_tweaks/mods/CP77 Discord RPC/"
if path[-19:] == "cyber_engine_tweaks":
    root = "mods/CP77 Discord RPC/"
if path[-4:] == "mods":
    root = "CP77 Discord RPC/"
if path[-16:] == "CP77 Discord RPC":
    root = ""
middleman_path = root + "middleman.json"
c = wmi.WMI()
if __name__ == '__main__':

    for window in list(gw.getWindowsWithTitle('cyberpunk')):
        if get_window_executable(window._hWnd) == "Cyberpunk2077.exe":
            window.activate()
            break

    with open(root + "config.json", 'r') as json_file:
        delay = json.load(json_file)["delay"]

      # Start RPC
    discord_rpc.initialize('798867051820351539', callbacks={}, log=False)

    while process_exists():

        with open(middleman_path, 'r', encoding='utf-8') as json_file:
            try:
                data = json.load(json_file)
            except:
                data = {
                    'level': 0,
                    'street_cred': 0,
                    'quest_name': 'N/A',
                    'lifepath': ''
                }
        
        presence = {
            'state': data["quest_name"],
            'large_image_text': version,
            'large_image_key': 'keyart',
            'start_timestamp': start
        }
        
        if data["lvl_stcred"] != '':
            presence["details"] = data["lvl_stcred"]

        if data["lifepath"] == 'Nomad':
            presence["small_image_key"] = 'nomad'
            presence["small_image_text"] = 'Nomad'
        
        if data["lifepath"] == 'StreetKid':
            presence["small_image_key"] = 'stkid'
            presence["small_image_text"] = 'Street Kid'
        
        if data["lifepath"] == 'Corporate':
            presence["small_image_key"] = 'corpo'
            presence["small_image_text"] = 'Corpo'



        discord_rpc.update_presence(**presence)

        discord_rpc.update_connection()
        time.sleep(delay)
        discord_rpc.run_callbacks()

    discord_rpc.shutdown()
