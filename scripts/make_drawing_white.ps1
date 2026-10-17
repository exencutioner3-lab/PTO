<#
.SYNOPSIS
    Пакетный перевод чертежа DWG в белый цвет (AutoCAD Color 7 / White).
    Обесцвечивает все слои, объекты, блоки, штриховки, выноски, тексты и таблицы.
.PARAMETER FilePath
    Полный путь к целевому DWG-файлу в G:\Мой диск\Workspace\
.EXAMPLE
    & "C:\Users\User\.gemini\config\skills\pto-autocad-schemes\references\make_drawing_white.ps1" -FilePath "G:\Мой диск\Workspace\В1-377 (10.10.2026).dwg"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $FilePath)) {
    Write-Error "Файл не найден: $FilePath"
    exit 1
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$accore = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"

# 1. Подготовка папок и резервной копии
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
$dir = [System.IO.Path]::GetDirectoryName($FilePath)
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
$backupPath = Join-Path $dir "${baseName}_backup.dwg"

if (-not (Test-Path $backupPath)) {
    Copy-Item $FilePath $backupPath -Force
    Write-Host "Создан бэкап: $backupPath" -ForegroundColor Cyan
}

Copy-Item $FilePath "C:\Temp\white_in.dwg" -Force

# 2. Экспорт в DXF 2018 через accoreconsole
Remove-Item "C:\Temp\white_in.dxf" -Force -ErrorAction SilentlyContinue
@'
_.DXFOUT
C:\Temp\white_in.dxf
16
_.QUIT
_Y

'@ | Set-Content "C:\Temp\exp_white.scr" -Encoding UTF8

Write-Host "Экспорт DWG -> DXF..."
& $accore /i "C:\Temp\white_in.dwg" /s "C:\Temp\exp_white.scr" 2>&1 | Out-Null

if (-not (Test-Path "C:\Temp\white_in.dxf")) {
    Write-Error "Не удалось экспортировать DXF в C:\Temp\white_in.dxf"
    exit 1
}

# 3. Однопроходная обработка DXF (все цвета -> 7, удаление TrueColor, чистка MTEXT)
Write-Host "Пакетная обработка цветов и слоёв..."
$lines = [System.IO.File]::ReadAllLines("C:\Temp\white_in.dxf", [System.Text.Encoding]::UTF8)
$newLines = New-Object System.Collections.Generic.List[string]($lines.Length)
$inLayers = $false

$i = 0
while ($i -lt $lines.Length - 1) {
    $c = $lines[$i].Trim()
    $v = $lines[$i+1]
    $vTrim = $v.Trim()

    # Отслеживание таблицы слоёв
    if ($c -eq "2" -and $vTrim -eq "LAYER") { $inLayers = $true }
    if ($inLayers -and $c -eq "0" -and $vTrim -eq "ENDTAB") { $inLayers = $false }

    # Удаление всех переопределений TrueColor (код 420) и ColorName (код 430)
    if ($c -in @("420", "430")) {
        $i += 2
        continue
    }

    # Принудительный перевод цветов в 7 (Белый / White)
    if ($c -eq "62") {
        if ($inLayers) {
            $colVal = [int]$vTrim
            $newCol = if ($colVal -lt 0) { "-7" } else { "7" }
            $newLines.Add($lines[$i]); $newLines.Add("        $newCol")
        } else {
            $newLines.Add($lines[$i]); $newLines.Add("        7")
        }
        $i += 2
        continue
    }

    # Очистка встроенных цветовых тегов в MTEXT/TEXT (\C...; и \c...;)
    if ($c -in @("1", "3", "300", "302") -and ($v.Contains("\C") -or $v.Contains("\c"))) {
        $cleanV = [regex]::Replace($v, '\\C\d+;', '\C7;')
        $cleanV = [regex]::Replace($cleanV, '\\c\d+;', '\C7;')
        $newLines.Add($lines[$i]); $newLines.Add($cleanV)
        $i += 2
        continue
    }

    # Нормализация ГОСТ-шрифтов на стандартные
    if ($v.Contains("CS_Gost2304.shx")) { $v = $v.Replace("CS_Gost2304.shx", "isocpeur.ttf") }
    if ($v.Contains("Russia-GOST_Topo.shx")) { $v = $v.Replace("Russia-GOST_Topo.shx", "isocpeur.ttf") }
    if ($v.Contains("GOST Common")) { $v = $v.Replace("GOST Common", "ISOCPEUR") }

    $newLines.Add($lines[$i]); $newLines.Add($v)
    $i += 2
}
if ($i -lt $lines.Length) { $newLines.Add($lines[$i]) }

# Запись DXF строго без BOM
$noBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines("C:\Temp\white_out.dxf", $newLines, $noBom)

# 4. Сборка DWG 2018 (обязательно удалять целевой файл перед SAVEAS во избежание зависания)
Remove-Item "C:\Temp\white_final.dwg" -Force -ErrorAction SilentlyContinue
@'
_.SAVEAS
2018
C:\Temp\white_final
_.QUIT
_Y

'@ | Set-Content "C:\Temp\save_white.scr" -Encoding UTF8

Write-Host "Сборка финального DWG 2018..."
& $accore /i "C:\Temp\white_out.dxf" /s "C:\Temp\save_white.scr" 2>&1 | Out-Null

if (-not (Test-Path "C:\Temp\white_final.dwg")) {
    Write-Error "Не удалось собрать DWG в C:\Temp\white_final.dwg"
    exit 1
}

# 5. Возврат в Workspace
Copy-Item "C:\Temp\white_final.dwg" $FilePath -Force
$sw.Stop()

Write-Host "Успешно завершено за $($sw.ElapsedMilliseconds) мс!" -ForegroundColor Green
Write-Host "Обновлён файл: $FilePath" -ForegroundColor Green
Get-Item $FilePath | Select-Object Name, Length, LastWriteTime
