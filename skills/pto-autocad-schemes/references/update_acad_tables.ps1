<#
.SYNOPSIS
    Пакетное обновление ячеек таблиц ACAD_TABLE и исправление шрифтов в AutoCAD DXF.

.DESCRIPTION
    1. Глобально заменяет отсутствующие шрифты (CS_Gost2304.shx, GOST Common) на ГОСТ ISOCPEUR.
    2. Очищает ячейки от повреждённых/фрагментированных тегов форматирования \f...;.
    3. Заполняет ячейки таблиц ACAD_TABLE по их индексам (Row 0 Col 0 = 0, Row 0 Col 1 = 1, ...).
    4. Удаляет динамические ссылки на поля (344), мешающие записи статических итоговых значений.
    5. Сохраняет DXF строго без UTF-8 BOM для безупречной загрузки в accoreconsole.

.EXAMPLE
    $updates = @{
        "8C468" = @{ 22 = "0,67"; 23 = "5,36" }
        "8D74F" = @{ 3 = "38"; 9 = "38"; 29 = "2870"; 31 = "3000" }
    }
    .\update_acad_tables.ps1 -InputDxf "C:\Temp\in.dxf" -OutputDxf "C:\Temp\out.dxf" -TableUpdates $updates
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputDxf,

    [Parameter(Mandatory=$true)]
    [string]$OutputDxf,

    [Parameter(Mandatory=$true)]
    [hashtable]$TableUpdates,

    [switch]$SkipFontFixes
)

Write-Host "Reading $InputDxf..."
$lines = [System.IO.File]::ReadAllLines($InputDxf, [System.Text.Encoding]::UTF8)
Write-Host "Read $($lines.Length) lines."

# 1. Замена шрифтов
if (-not $SkipFontFixes) {
    Write-Host "Applying global font fixes to ISOCPEUR..."
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Contains("CS_Gost2304.shx")) {
            $lines[$i] = $lines[$i].Replace("CS_Gost2304.shx", "isocpeur.ttf")
        }
        if ($lines[$i].Contains("Russia-GOST_Topo.shx")) {
            $lines[$i] = $lines[$i].Replace("Russia-GOST_Topo.shx", "isocpeur.ttf")
        }
        if ($lines[$i].Contains("GOST Common")) {
            $lines[$i] = $lines[$i].Replace("GOST Common", "ISOCPEUR")
        }
    }
}

# 2. Обновление таблиц
$newLines = New-Object System.Collections.Generic.List[string]($lines.Length + 5000)
$inEntities = $false
$i = 0
$updatedCount = 0

while ($i -lt $lines.Length) {
    $c = $lines[$i].Trim(); $v = $lines[$i+1].Trim()
    if ($c -eq "2" -and $v -eq "ENTITIES") { $inEntities = $true }
    if ($c -eq "0" -and $v -eq "ENDSEC" -and $inEntities) { $inEntities = $false }

    if ($inEntities -and $c -eq "0" -and $v -eq "ACAD_TABLE") {
        # Определяем handle таблицы
        $tHandle = ""
        $tEnd = $lines.Length - 1
        for ($j = $i + 2; $j -lt $lines.Length; $j += 2) {
            if ($lines[$j].Trim() -eq "5" -and $tHandle -eq "") { $tHandle = $lines[$j+1].Trim() }
            if ($lines[$j].Trim() -eq "0") { $tEnd = $j - 1; break }
        }

        $map = $TableUpdates[$tHandle]
        if ($map -ne $null) {
            Write-Host "Updating Table [Handle $tHandle]..."
            $cellIdx = 0
            $k = $i

            while ($k -le $tEnd) {
                # Исключаем ссылки на dynamic fields (344)
                if ($lines[$k].Trim() -eq "344") { $k += 2; continue }

                if ($lines[$k].Trim() -eq "301" -and $lines[$k+1].Trim() -eq "CELL_VALUE") {
                    $cStart = $k
                    $cEnd = $tEnd
                    for ($m = $k + 2; $m -le $tEnd; $m += 2) {
                        if ($lines[$m].Trim() -eq "304" -and $lines[$m+1].Trim() -eq "ACVALUE_END") {
                            $cEnd = $m + 1
                            break
                        }
                    }

                    $hasCode1 = $false
                    $cellText = ""
                    for ($m = $cStart; $m -le $cEnd; $m += 2) {
                        if ($lines[$m].Trim() -eq "1") {
                            $hasCode1 = $true
                            $cellText = $lines[$m+1]
                        }
                    }

                    $targetVal = if ($map.ContainsKey($cellIdx)) { $map[$cellIdx] } else { $null }

                    if ($targetVal -ne $null) {
                        if ($hasCode1) {
                            for ($m = $cStart; $m -le $cEnd; $m += 2) {
                                if ($lines[$m].Trim() -in @("1", "302")) {
                                    $newLines.Add($lines[$m]); $newLines.Add($targetVal)
                                } else {
                                    $newLines.Add($lines[$m]); $newLines.Add($lines[$m+1])
                                }
                            }
                        } else {
                            $newLines.Add("301"); $newLines.Add("CELL_VALUE")
                            $newLines.Add(" 93"); $newLines.Add("        6")
                            $newLines.Add(" 90"); $newLines.Add("        4")
                            $newLines.Add("  1"); $newLines.Add($targetVal)
                            $newLines.Add(" 94"); $newLines.Add("        0")
                            $newLines.Add("300"); $newLines.Add("")
                            $newLines.Add("302"); $newLines.Add($targetVal)
                            $newLines.Add("304"); $newLines.Add("ACVALUE_END")
                        }
                        $updatedCount++
                    } else {
                        # Очистка фрагментированных тегов шрифтов \f...
                        for ($m = $cStart; $m -le $cEnd; $m += 2) {
                            if ($lines[$m].Trim() -in @("1", "302")) {
                                $clean = $lines[$m+1] -replace '\\[fFWwCkK][^;]*;', '' -replace '[\{\}]', ''
                                $newLines.Add($lines[$m]); $newLines.Add($clean.Trim())
                            } else {
                                $newLines.Add($lines[$m]); $newLines.Add($lines[$m+1])
                            }
                        }
                    }

                    $cellIdx++
                    $k = $cEnd + 1
                    continue
                }

                $newLines.Add($lines[$k]); $newLines.Add($lines[$k+1])
                $k += 2
            }

            $i = $tEnd + 1
            continue
        }
    }

    $newLines.Add($lines[$i]); $newLines.Add($lines[$i+1])
    $i += 2
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($OutputDxf, $newLines, $utf8NoBom)
Write-Host "Updated $updatedCount cells. Saved to $OutputDxf successfully."
