# -*- coding: utf-8 -*-
"""
Kyocera ECOSYS M4125idn - Network & Connection Helper
Автоматическая диагностика и настройка связи с принтером
"""

import sys
import subprocess
import socket
import time

PRINTER_IP = "192.168.0.96"
PRINTER_PORT = 9100
PRINTER_NAME = "Kyocera ECOSYS M4125idn KX"

def check_link():
    print("=" * 60)
    print("1. ПРОВЕРКА ФИЗИЧЕСКИХ СЕТЕВЫХ ПОДКЛЮЧЕНИЙ:")
    print("=" * 60)
    cmd = 'powershell -Command "Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table -AutoSize"'
    res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
    print(res.stdout)

def check_ping(ip):
    print("=" * 60)
    print(f"2. ПРОВЕРКА СВЯЗИ С ПРИНТЕРОМ ({ip}):")
    print("=" * 60)
    cmd = f'powershell -Command "Test-Connection -ComputerName {ip} -Count 2 -Quiet"'
    res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
    is_alive = "True" in res.stdout
    if is_alive:
        print(f"[OK] Принтер {ip} отвечает на пинг!")
    else:
        print(f"[!] Принтер {ip} не отвечает на пинг.")
    return is_alive

def check_port(ip, port=9100):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2.0)
        s.connect((ip, port))
        s.close()
        print(f"[OK] Порт печати {port} (RAW/JetDirect) на {ip} ОТКРЫТ!")
        return True
    except Exception as e:
        print(f"[!] Порт печати {port} на {ip} недоступен ({e}).")
        return False

def configure_ethernet_dual_net():
    print("=" * 60)
    print("3. НАСТРОЙКА ДВОЙНОЙ СЕТИ (ИНТЕРНЕТ ЧЕРЕЗ WI-FI + ПРИНТЕР ЧЕРЕЗ КАБЕЛЬ):")
    print("=" * 60)
    ps_script = '''
    # Назначаем статический IP для Ethernet без шлюза
    netsh interface ipv4 set address name="Ethernet" static 192.168.0.200 255.255.255.0 none
    # Выставляем приоритет для Wi-Fi чтобы интернет всегда шел через хот-спот
    $wifi = Get-NetIPInterface -InterfaceAlias "Беспроводная сеть" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($wifi) {
        Set-NetIPInterface -InterfaceIndex $wifi.InterfaceIndex -InterfaceMetric 10
    }
    $eth = Get-NetIPInterface -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($eth) {
        Set-NetIPInterface -InterfaceIndex $eth.InterfaceIndex -InterfaceMetric 50
    }
    '''
    res = subprocess.run(["powershell", "-Command", ps_script], capture_output=True, text=True)
    print("Команда настройки выполнена.")
    if res.stdout.strip():
        print(res.stdout)
    if res.stderr.strip():
        print("Инфо:", res.stderr)

if __name__ == "__main__":
    check_link()
    ping_ok = check_ping(PRINTER_IP)
    if ping_ok:
        check_port(PRINTER_IP, PRINTER_PORT)
    else:
        print("\nФизическое подключение пока отсутствует.")
        print("Как только воткнете сетевой провод (витую пару) от модема/принтера в ПК,")
        print("запустите этот скрипт снова для мгновенного включения!")
