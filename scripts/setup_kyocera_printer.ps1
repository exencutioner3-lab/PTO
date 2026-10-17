# ==============================================================================
# Скрипт подключения и настройки Kyocera ECOSYS M4125idn (IP 192.168.0.96)
# Позволяет печатать по проводу Ethernet БЕЗ потери интернета с Wi-Fi хот-спота!
# ==============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " НАСТРОЙКА И ДИАГНОСТИКА СВЯЗИ С KYOCERA ECOSYS M4125idn" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Проверка физического подключения кабеля
$adapter = Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue
if (-not $adapter) {
    Write-Host "[ОШИБКА] Сетевой адаптер Ethernet не найден!" -ForegroundColor Red
    Pause
    exit
}

if ($adapter.Status -ne "Up") {
    Write-Host "`n[!] ВНИМАНИЕ: Сетевой кабель Ethernet сейчас НЕ ПОДКЛЮЧЁН к ПК." -ForegroundColor Yellow
    Write-Host "    Статус порта: $($adapter.Status)" -ForegroundColor Yellow
    Write-Host "`n--> Пожалуйста, вставьте сетевой провод (патч-корд) от модема/принтера" -ForegroundColor White
    Write-Host "    в сетевую розетку сзади компьютера и повторите запуск." -ForegroundColor White
} else {
    Write-Host "[OK] Сетевой кабель подключен (Линк: $($adapter.LinkSpeed))" -ForegroundColor Green
}

# 2. Настройка IP-адреса на Ethernet адаптере (без шлюза, чтобы интернет шел с Wi-Fi)
Write-Host "`n[+] Настройка адресации подсети принтера 192.168.0.x..." -ForegroundColor Cyan
try {
    netsh interface ipv4 set address name="Ethernet" static 192.168.0.200 255.255.255.0 none | Out-Null
    
    # Приоритет маршрутов: Wi-Fi для интернета (метрика 10), Ethernet для принтера (метрика 50)
    $wifi = Get-NetIPInterface -InterfaceAlias "Беспроводная сеть" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($wifi) {
        Set-NetIPInterface -InterfaceIndex $wifi.InterfaceIndex -InterfaceMetric 10 -ErrorAction SilentlyContinue
    }
    Set-NetIPInterface -InterfaceIndex $adapter.InterfaceIndex -InterfaceMetric 50 -ErrorAction SilentlyContinue
    Write-Host "[OK] Сетевая карта настроена: IP 192.168.0.200 (интернет через Wi-Fi сохранён)" -ForegroundColor Green
} catch {
    Write-Host "[!] Предупреждение: для смены IP требуются права администратора." -ForegroundColor Yellow
}

# 3. Проверка пинга до принтера
Write-Host "`n[+] Проверка связи с принтером (192.168.0.96)..." -ForegroundColor Cyan
$ping = Test-Connection -ComputerName "192.168.0.96" -Count 2 -Quiet
if ($ping) {
    Write-Host "[OK] ПРИНТЕР 192.168.0.96 УСПЕШНО ОТВЕЧАЕТ НА ПИНГ!" -ForegroundColor Green
    
    # 4. Проверка порта печати 9100
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("192.168.0.96", 9100)
        $tcp.Close()
        Write-Host "[OK] Порт печати 9100 (RAW) открыт и готов к приёму заданий." -ForegroundColor Green
        
        Write-Host "`n>>> ПРИНТЕР ПОЛНОСТЬЮ ГОТОВ К ПЕЧАТИ ИЗ AUTOCAD И WINDOWS! <<<" -ForegroundColor Green
    } catch {
        Write-Host "[!] Пинг есть, но порт 9100 не отвечает. Убедитесь, что принтер включен." -ForegroundColor Yellow
    }
} else {
    Write-Host "[!] Принтер 192.168.0.96 пока не отвечает (кабель не воткнут или модем выключен)." -ForegroundColor Yellow
}

Write-Host "`nТекущий статус принтера в Windows:" -ForegroundColor Cyan
Get-Printer -Name "*Kyocera*" | Select-Object Name, PortName, PrinterStatus | Format-Table -AutoSize
