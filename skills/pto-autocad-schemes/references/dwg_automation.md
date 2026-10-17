# Пакетная обработка DWG через accoreconsole

> [!IMPORTANT]
> Эта страница содержит проверенные шаблоны, готовые к запуску на этой машине.
> Все пути и ограничения проверены в рабочей сессии 14.10.2026.

---

## БЫСТРЫЙ СТАРТ — копируй и запускай

Для задачи **"удалить X из DWG"**:

1. Найти имя файла в `G:\Мой диск\Workspace\`
2. Подставить имя файла в строки `$inputFile` и `$outputFile` ниже
3. Выбрать нужный SCR-блок из раздела "Готовые SCR-шаблоны"
4. Запустить всё одним блоком в PowerShell

```powershell
# === НАСТРОИТЬ: имена файлов ===
$inputFile  = "G:\Мой диск\Workspace\ИМЯ_ФАЙЛА.dwg"
$outputFile = "G:\Мой диск\Workspace\ИМЯ_ФАЙЛА_result.dwg"

# === НЕ МЕНЯТЬ: инфраструктура ===
$accore  = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"
$tempIn  = "C:\Temp\input.dwg"
$tempOut = "C:\Temp\output"
$scrFile = "C:\Temp\script.scr"
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Copy-Item $inputFile $tempIn -Force

# === ВСТАВИТЬ: содержимое SCR (из раздела ниже) ===
$scrContent = @'
ВСТАВИТЬ_SCR_ШАБЛОН_СЮДА
'@
$scrContent | Set-Content $scrFile -Encoding UTF8

# === ЗАПУСК ===
& $accore /i $tempIn /s $scrFile 2>&1 | Out-String | ForEach-Object { $_ -replace [char]0,'' }

# === РЕЗУЛЬТАТ ===
if (Test-Path "$tempOut.dwg") {
    Copy-Item "$tempOut.dwg" $outputFile -Force
    Write-Host "✓ Готово: $outputFile" -ForegroundColor Green
    Write-Host "  Размер: $([math]::Round((Get-Item $outputFile).Length/1KB)) КБ"
} else {
    Write-Warning "Файл не создан. Проверь вывод выше."
}
```

---

| Ограничение | Решение |
|---|---|
| Не читает `.lsp` из внешних путей (блокировка безопасности) | Писать LISP прямо в `.scr` файл (inline) |
| Кириллица в аргументах командной строки искажается | Копировать файлы в `C:\Temp\` перед запуском |
| Вывод в кодировке UTF-16 (нулевые байты между символами) | Фильтровать: `$_ -replace [char]0,''` |
| `/s` ожидает `.scr`, но LISP в нём работает | `(progn ...)` и `(setq ...)` выполняются inline |
| Русская версия AutoCAD требует `_Y` (с подчёркиванием) для подтверждения `_.QUIT` | Всегда писать `_.QUIT` затем `_Y` (без `_` виснет в ожидании ответа) |
| Перезапись DWG при `_.SAVEAS` | **Всегда удалять** выходной файл в `C:\Temp\` перед запуском `accoreconsole` (`Remove-Item "C:\Temp\out.dwg" -Force`). Иначе AutoCAD выдаст запрос «Заменить? <N>» и намертво зависнет |
| Таблицы `ACAD_TABLE` в `accoreconsole` | ActiveX/COM возвращает `nil`. Редактировать ячейки в DXF. При открытии `accoreconsole` **автоматически пересоздаёт блок `*T...`** со всеми MTEXT и координатами |
| Динамические поля `AcDbField` в таблицах | Удалять код `344 \n <handle>` перед `CELL_VALUE`, иначе AutoCAD вычисляет формулу поля и затирает статическое значение |
| Отсутствующие шрифты `CS_Gost2304.shx` / `GOST Common` | Заменять на `isocpeur.ttf` / `ISOCPEUR` в `STYLE` и текстах; очищать теги `\f...;` |
| Генерация DXF через PowerShell | Всегда сохранять без BOM: `[System.Text.UTF8Encoding]::new($false)` |
| Экспорт в DXF через консоль | `_.DXFOUT C:\Temp\file.dxf 16` |

---

## Универсальный PowerShell-скрипт обработки DWG

```powershell
param(
    [string]$InputDWG,   # Полный путь к исходному DWG
    [string]$ScrContent, # Текст SCR-скрипта
    [string]$OutputName  # Имя выходного файла (без расширения, в C:\Temp\)
)

$accore = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"
$tempIn  = "C:\Temp\input_accore.dwg"
$scrFile = "C:\Temp\accore_script.scr"

# 1. Подготовка
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Copy-Item $InputDWG $tempIn -Force

# 2. Записать SCR
$ScrContent | Set-Content $scrFile -Encoding UTF8

# 3. Запуск
& $accore /i $tempIn /s $scrFile 2>&1 | Out-String | ForEach-Object { $_ -replace [char]0,'' }

# 4. Вернуть результат
$result = "C:\Temp\$OutputName.dwg"
if (Test-Path $result) {
    $dest = [System.IO.Path]::ChangeExtension($InputDWG, $null).TrimEnd('.') + "_$OutputName.dwg"
    Copy-Item $result $dest -Force
    Write-Host "OK: $dest"
} else {
    Write-Warning "Выходной файл не найден: $result"
}
```

---

## Готовые SCR-шаблоны (inline LISP)

### Удалить все размеры (DIMENSION + LEADER + MLEADER)

```
(progn (setq ss (ssget "X" '((0 . "DIMENSION")))) (if ss (command "_.ERASE" ss "")))
(progn (setq ss (ssget "X" '((0 . "LEADER")))) (if ss (command "_.ERASE" ss "")))
(progn (setq ss (ssget "X" '((0 . "MLEADER")))) (if ss (command "_.ERASE" ss "")))
_.SAVEAS
2018
C:\Temp\output
_.QUIT
_Y
```

### Удалить размеры полностью (комплекс: DIMENSION + засечки GT_1/Defpoints + надписи L=...)

> [!IMPORTANT]
> На реальных исполнительных и монтажных схемах размеры часто состоят из трёх независимых частей:
> 1) Объекты `DIMENSION`
> 2) Засечки и выносные линии в виде `LWPOLYLINE` на слое `GT_1` или `Defpoints`
> 3) Тексты длин участков `\pxqc;L=...` на слое `0`
> Если удалить только `DIMENSION`, графика засечек и надписи длин останутся! Этот сниппет удаляет всё чисто за 1 проход:

```lisp
(progn
  ; 1. Размеры
  (setq ss1 (ssget "X" '((0 . "DIMENSION"))))
  (if ss1 (command "_.ERASE" ss1 ""))
  ; 2. Засечки и выносные линии
  (setq ss2 (ssget "X" '((0 . "LWPOLYLINE") (8 . "GT_1,Defpoints"))))
  (if ss2 (command "_.ERASE" ss2 ""))
  ; 3. Тексты длин участков L=... на слое 0
  (setq ss3 (ssget "X" '((0 . "MTEXT") (8 . "0"))))
  (if ss3
    (progn
      (setq i 0)
      (while (< i (sslength ss3))
        (setq ent (ssname ss3 i))
        (if (wcmatch (cdr (assoc 1 (entget ent))) "*L=*")
          (entdel ent)
        )
        (setq i (1+ i))
      )
    )
  )
)
_.SAVEAS
2018
C:\Temp\output
_.QUIT
_Y
```

### Удалить все объекты на слое

```
(progn (setq ss (ssget "X" '((8 . "ИМЯ_СЛОЯ")))) (if ss (command "_.ERASE" ss "")))
_.SAVEAS
2018
C:\Temp\output
_.QUIT
_Y
```

### Заморозить/скрыть слой

```
-LAYER
F
ИМЯ_СЛОЯ

_.SAVEAS
2018
C:\Temp\output
_.QUIT
_Y
```

### Удалить весь текст (TEXT + MTEXT)

```
(progn (setq ss (ssget "X" '((0 . "TEXT,MTEXT")))) (if ss (command "_.ERASE" ss "")))
_.SAVEAS
2018
C:\Temp\output
_.QUIT
_Y
```

### Удалить штриховку (HATCH)

```
(progn (setq ss (ssget "X" '((0 . "HATCH")))) (if ss (command "_.ERASE" ss "")))
_.SAVEAS
2018
C:\Temp\output
_.QUIT
_Y
```

### Конвертировать DWG → DXF (через DXFOUT)

```
_.DXFOUT
C:\Temp\output.dxf
16
_.QUIT
_Y
```

### Диагностика: список типов объектов в файле

```
(setq types (list))
(vlax-for e (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq t (vla-get-ObjectName e))
  (if (not (member t types)) (setq types (cons t types))))
(foreach t types (princ (strcat "\n" t)))
_.QUIT
_Y
```

---

## Пакетная замена текста и таблиц спецификаций (DXF-пайплайн)

> [!IMPORTANT]
> Таблицы AutoCAD (`ACAD_TABLE`), ячейки спецификаций, многострочный текст на листах (Layouts) и в блоках надежнее всего менять через DXF.
> **Строгие правила:**
> 1. Сохранять DXF только **БЕЗ UTF-8 BOM**: `[System.Text.UTF8Encoding]::new($false)`.
> 2. Подтверждение выхода `_.QUIT` всегда **`_Y`**.
> 3. Если исходный текст оформлен стилями (например `{\C7;Текст}`), учитывать это при замене или использовать замену чистой подстроки.

### Готовый скрипт пакетной замены строк в DWG:

```powershell
# === 1. Входные параметры ===
$inputFile  = "G:\Мой диск\Workspace\Исходный_файл.dwg"
$outputFile = "G:\Мой диск\Workspace\Результат.dwg"
$oldStr     = "Итого: монтаж трубопровода"
$newStr     = "Итого: монтаж трубопровода+фасонные изделия"

$accore  = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"
$tempDwg = "C:\Temp\batch_in.dwg"
$tempDxf = "C:\Temp\batch_temp.dxf"
$finalDwg= "C:\Temp\batch_out.dwg"

New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Copy-Item $inputFile $tempDwg -Force

# === 2. Экспорт DWG -> DXF ===
@'
_.DXFOUT
C:\Temp\batch_temp.dxf
16
_.QUIT
_Y

'@ | Set-Content "C:\Temp\export_dxf.scr" -Encoding UTF8

& $accore /i $tempDwg /s "C:\Temp\export_dxf.scr" 2>&1 | Out-Null

if (-not (Test-Path $tempDxf)) {
    throw "Ошибка: DXF не был сгенерирован!"
}

# === 3. Замена текста в DXF (PowerShell без BOM) ===
$content = [System.IO.File]::ReadAllText($tempDxf, [System.Text.Encoding]::UTF8)

$matchesCount = ([regex]::Matches($content, [regex]::Escape($oldStr))).Count
Write-Host "Найдено вхождений '$oldStr': $matchesCount"

$content = $content.Replace($oldStr, $newStr)

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($tempDxf, $content, $utf8NoBom)

# === 4. Сборка DXF -> DWG 2018 (без дублирования через DXFIN!) ===
# ВАЖНО: при ключе /i "файл.dxf" AutoCAD уже открыл его, поэтому DXFIN не нужен!
@'
_.SAVEAS
2018
C:\Temp\batch_out
_.QUIT
_Y

'@ | Set-Content "C:\Temp\import_dxf.scr" -Encoding UTF8

& $accore /i $tempDxf /s "C:\Temp\import_dxf.scr" 2>&1 | Out-Null

# === 5. Проверка и возврат ===
if (Test-Path $finalDwg) {
    Copy-Item $finalDwg $outputFile -Force
    $sizeKb = [math]::Round((Get-Item $outputFile).Length / 1KB)
    Write-Host "✓ Успешно сохранено: $outputFile ($sizeKb КБ)" -ForegroundColor Green
} else {
    Write-Error "Ошибка: финальный DWG не создан."
}
```

### Замена связанных/каскадных строк в спецификациях (Итого 1 и Итого 2)

> [!WARNING]
> Если строка 1 должна стать строкой 2, а старая строка 2 — строкой 3 (например:
> `Итого: монтаж трубопровода` $\rightarrow$ `Итого: монтаж трубопровода+фасонные изделия`,
> а `Итого: монтаж трубопровода+фасонные изделия` $\rightarrow$ `Итого: Общая протяженность участка линии`),
> **нельзя** заменять строку 1 первой через обычный `Replace()`, иначе она превратится в строку 2 и затем перезапишется!
> 
> **Правило:** либо заменять строку 2 первой:
> ```powershell
> $content = $content.Replace("{\W1;Итого: монтаж трубопровода+фасонные изделия}", "{\W1;Итого: Общая протяженность участка линии}")
> $content = $content.Replace("{\W1;Итого: монтаж трубопровода}", "{\W1;Итого: монтаж трубопровода+фасонные изделия}")
> ```
> Либо построчно через массив `$lines`:
> ```powershell
> $lines = [System.IO.File]::ReadAllLines($dxfPath, [System.Text.Encoding]::UTF8)
> for ($i = 0; $i -lt $lines.Length; $i++) {
>     if ($lines[$i] -eq "{\W1;Итого: монтаж трубопровода+фасонные изделия}") {
>         $lines[$i] = "{\W1;Итого: Общая протяженность участка линии}"
>     } elseif ($lines[$i] -eq "{\W1;Итого: монтаж трубопровода}") {
>         $lines[$i] = "{\W1;Итого: монтаж трубопровода+фасонные изделия}"
>     }
> }
> ```

---

## Синхронизация схем по аналогии (Т1 → Т2, Т3, ...)

Готовый скрипт «всё-в-одном» для переноса правок со схемы-эталона на новый чертёж:

```powershell
param(
    [string]$TargetDwg = "2547.21-377.4-ТС Т2 (15.10.2026).dwg"
)

$accore = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"
$src = "G:\Мой диск\Workspace\$TargetDwg"

Write-Host "=== Синхронизация схемы $TargetDwg ===" -ForegroundColor Cyan

# 1. Бэкап
Copy-Item $src "G:\Мой диск\Workspace\$($TargetDwg)_orig_backup.dwg" -Force
Copy-Item $src "C:\Temp\pipe_in.dwg" -Force

# 2. Комплексная очистка размеров через AutoLISP в accoreconsole
@'
(progn
  (setq ss (ssget "X" '((0 . "DIMENSION")))) (if ss (command "_.ERASE" ss ""))
  (setq ss (ssget "X" '((0 . "LWPOLYLINE") (8 . "GT_1,Defpoints")))) (if ss (command "_.ERASE" ss ""))
  (setq ss (ssget "X" '((0 . "MTEXT") (8 . "0"))))
  (if ss (progn (setq i 0) (while (< i (sslength ss)) (setq e (ssname ss i)) (if (wcmatch (cdr (assoc 1 (entget e))) "*L=*") (entdel e)) (setq i (1+ i))))))
_.SAVEAS
2018
C:\Temp\pipe_nodims
_.QUIT
_Y

'@ | Set-Content "C:\Temp\purge_dims.scr" -Encoding UTF8

& $accore /i "C:\Temp\pipe_in.dwg" /s "C:\Temp\purge_dims.scr" 2>&1 | Out-Null

# 3. Экспорт в DXF
"_.DXFOUT`nC:\Temp\pipe_temp.dxf`n16`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\exp.scr" -Encoding UTF8
& $accore /i "C:\Temp\pipe_nodims.dwg" /s "C:\Temp\exp.scr" 2>&1 | Out-Null

# 4. Обновление спецификаций
$lines = [System.IO.File]::ReadAllLines("C:\Temp\pipe_temp.dxf", [System.Text.Encoding]::UTF8)
$r1Old = "{\W1;Итого: монтаж трубопровода}"
$r2Old = "{\W1;Итого: монтаж трубопровода+фасонные изделия}"
$r1New = "{\W1;Итого: монтаж трубопровода+фасонные изделия}"
$r2New = "{\W1;Итого: Общая протяженность участка линии}"

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -eq $r2Old) { $lines[$i] = $r2New }
    elseif ($lines[$i] -eq $r1Old) { $lines[$i] = $r1New }
}
$noBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines("C:\Temp\pipe_ready.dxf", $lines, $noBom)

# 5. Сборка DWG через SAVEAS
"_.SAVEAS`n2018`nC:\Temp\pipe_out`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\save.scr" -Encoding UTF8
& $accore /i "C:\Temp\pipe_ready.dxf" /s "C:\Temp\save.scr" 2>&1 | Out-Null

# 6. Проверка и возврат
if (Test-Path "C:\Temp\pipe_out.dwg") {
    Copy-Item "C:\Temp\pipe_out.dwg" $src -Force
    Write-Host "✓ Успешно обновлено: $src" -ForegroundColor Green
} else {
    Write-Error "Ошибка сборки DWG."
}
```

---

## Подсчёт объектов (диагностика перед обработкой)

Запустить перед удалением, чтобы знать что будет удалено:

```powershell
$accore = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"
Copy-Item "G:\Мой диск\Workspace\файл.dwg" "C:\Temp\input.dwg" -Force

@'
(defun count-type (tp / ss) (if (setq ss (ssget "X" (list (cons 0 tp)))) (sslength ss) 0))
(princ (strcat "\nDIMENSION: " (itoa (count-type "DIMENSION"))))
(princ (strcat "\nLEADER:    " (itoa (count-type "LEADER"))))
(princ (strcat "\nMLEADER:   " (itoa (count-type "MLEADER"))))
(princ (strcat "\nTEXT:      " (itoa (count-type "TEXT"))))
(princ (strcat "\nMTEXT:     " (itoa (count-type "MTEXT"))))
_.QUIT
_Y
'@ | Set-Content "C:\Temp\count.scr" -Encoding UTF8

& $accore /i "C:\Temp\input.dwg" /s "C:\Temp\count.scr" 2>&1 |
    Out-String | ForEach-Object { $_ -replace [char]0,'' } |
    Select-String "DIMENSION|LEADER|TEXT|MTEXT"
```

---

## ssget фильтры (шпаргалка)

| Что искать | Фильтр LISP |
|---|---|
| Тип объекта | `(cons 0 "DIMENSION")` |
| Несколько типов | `(cons 0 "DIMENSION,LEADER")` |
| Слой | `(cons 8 "ИМЯ_СЛОЯ")` |
| Цвет | `(cons 62 7)` |
| Тип линии | `(cons 6 "CENTER2")` |
| Тип + слой | `'((0 . "LINE") (8 . "ОСИ"))` |

Пример выборки по типу + слою:
```lisp
(setq ss (ssget "X" '((0 . "LINE") (8 . "РАЗМЕРЫ"))))
```

---

## Пакетный перевод чертежа в белый цвет (монохром / AutoCAD Color 7)

Чертежи, выгруженные из BIM/Revit, смежных разделов или PDF, содержат тысячи жестко заданных цветов объектов, цветных слоёв, TrueColor (RGB) и тегов `\C...;` в текстах.

Готовый скрипт выполняет полный цикл (бэкап + экспорт DXF + очистка цветов слоев/объектов/блоков/текстов + сборка DWG 2018) за ~5–7 секунд:

```powershell
& "C:\Users\User\.gemini\config\skills\pto-autocad-schemes\references\make_drawing_white.ps1" -FilePath "G:\Мой диск\Workspace\ЧЕРТЁЖ.dwg"
```

