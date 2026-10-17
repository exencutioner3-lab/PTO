---
name: pto-autocad-schemes
description: >-
  Скилл для инженера ПТО трубопроводных разделов: генерация AutoCAD-команд,
  скриптов и шаблонов для отрисовки схем ТХ, ВК, ВС, ОВ, ТК, ТМ, ТС.
  Активировать при запросах: «нарисуй схему», «напиши скрипт AutoCAD»,
  «сделай шаблон», «слои для чертежа», «оформление по ГОСТ», «штамп»,
  «исполнительная схема», «монтажная схема», «схема трубопровода»,
  «аксонометрия», «план трубопроводов», «разрез», «узел обвязки»,
  «убери размеры», «удали объекты», «обработай DWG», «скрипт на чертёж»,
  «убери размеры с линий», «удали выноски», «очисти чертёж», «уберу текст»,
  «сохрани без», «конвертируй DWG», «запусти AutoCAD», «accoreconsole»,
  «что-то в чертеже», «схема приложена», «приложил схему», «смотри DWG»,
  «поправь формулировку», «замени текст», «поправь в спецификациях»,
  «обнови таблицы», «замена строк», «отводы по дуге», «по дуге»,
  «текст в таблицах», «итого монтаж», «общая протяженность»,
  «по аналогии», «аналогия», «синхронизируй схемы», «перенеси правки»,
  «дозаполни спецификации», «интервалы между стыковыми соединениями»,
  «сделай нормальные шрифты», «дозаполни пустые строки»,
  «размеры отводов», «размеры переходов», «размеры тройников»,
  «ACAD_TABLE», «битые шрифты», «CS_Gost2304», «GOST Common», «ISOCPEUR»,
  «все цвета белые», «белый цвет», «белого света», «белого цвета»,
  «сделай белым», «монохром», «обесцветить чертеж», «перекрась в белый».
---

# ПТО — Схемы трубопроводных разделов (ТХ / ВК / ВС / ОВ / ТК / ТМ / ТС)

Скилл для инженера ПТО, работающего исключительно с трубопроводными системами.

---

## 0. Локальная среда (не требует поиска)

> [!IMPORTANT]
> Эти факты установлены при работе — использовать немедленно.

| Инструмент | Путь | Примечания |
|---|---|---|
| **Python 3.15** | `D:\Python\python.exe` | pip: `D:\Python\python.exe -m pip` (диск D может быть недоступен, PS всегда работает) |
| **AutoCAD 2026** | `C:\Program Files\Autodesk\AutoCAD 2026\acad.exe` | |
| **accoreconsole** | `C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe` | CLI без GUI |
| **Рабочая папка** | `G:\Мой диск\Workspace\` | кириллица в пути — см. ниже |
| **Временная папка** | `C:\Temp\` | только ASCII-путь, для скриптов |
| **ezdxf** | установлен в Python | только DXF, **не** DWG |

### Правила работы с DWG

1. **`ezdxf` не читает `.dwg`** → для DWG использовать `accoreconsole`
2. **Кириллица в путях ломает accoreconsole** → копировать в `C:\Temp\`
3. **`(load "файл.lsp")` заблокирован** → писать LISP прямо в `.scr` (inline)
4. **Вывод accoreconsole — UTF-16** → при парсинге: `$_ -replace [char]0,''`
5. **Русская версия AutoCAD требует `_Y`** для подтверждения выхода (`_.QUIT` -> `_Y`). Голый `Y` отвергается русской локалью и приводит к зависанию.
6. **DXF-файлы только БЕЗ UTF-8 BOM**: писать через `[System.Text.UTF8Encoding]::new($false)`.
7. **Для редактирования текста и таблиц спецификаций**: надёжнее и быстрее всего пайплайн `DWG -> DXF (accoreconsole) -> замена строк (PowerShell) -> DWG (accoreconsole)`. Работает по всем листам, блокам и объектам таблиц разом.
8. **Перед сохранением DWG через `_.SAVEAS` всегда удалять целевой файл в `C:\Temp`**: `Remove-Item "C:\Temp\output.dwg" -Force -ErrorAction SilentlyContinue`. Если файл уже существует, AutoCAD запрашивает подтверждение перезаписи («Файл с этим именем уже существует. Заменить? <N>») и намертво зависает в консоли!
9. **Таблицы `ACAD_TABLE` нельзя модифицировать через AutoLISP в accoreconsole** (`(vlax-get-acad-object)` возвращает `nil`). Единственный надёжный путь — точечная правка DXF (Ветка E). При последующем открытии DXF `accoreconsole` **автоматически пересчитывает таблицу и пересоздаёт внутренний анонимный блок `*T...`** со всеми объектами MTEXT, координатами и стилями ячеек!
10. **Шрифты ГОСТ (исправление и чистка)**: `CS_Gost2304.shx` и `Russia-GOST_Topo.shx` отсутствуют в Windows, вызывая сброс в `simplex.shx`. Решение — замена в `STYLE` и текстах на `isocpeur.ttf` (`ISOCPEUR`). При наличии фрагментированных тегов `\f...;` очищать их регулярным выражением `-replace '\\[fFWwCkK][^;]*;', '' -replace '[\{\}]', ''`.
11. **Поля в ячейках таблиц (`AcDbField`, код 344)**: если ячейка привязана к динамическому полю (например, формула `Sum`), строку `344 \n <handle>` перед `CELL_VALUE` нужно удалить, иначе AutoCAD при открытии пересчитает поле и затрёт статическое значение.
12. **Пакетный перевод чертежа в белый цвет (монохром)**: дизайнеры и смежники часто выдают чертежи с сотнями переопределений TrueColor (RGB), жесткими цветами линий и блоков (251, 150, 18, 5 и др.), цветными слоями и внутренними тегами в MTEXT (`\C...;`). Быстрее и надёжнее всего использовать **Ветку F**: экспорт в DXF, пакетная замена цветов слоёв и объектов на 7 (White) с полным удалением TrueColor (коды 420/430) и очисткой `\C`-тегов в текстах через один проход PowerShell (~5 сек), затем сборка в DWG через `accoreconsole`. Готовый скрипт: `references/make_drawing_white.ps1`.

### Шаблон PowerShell для обработки DWG

```powershell
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Copy-Item "G:\Мой диск\Workspace\ФАЙЛ.dwg" "C:\Temp\input.dwg" -Force

@'
; === LISP INLINE ===
_.SAVEAS
2018
C:\Temp\output
_.QUIT
_Y

'@ | Set-Content "C:\Temp\script.scr" -Encoding UTF8

$accore = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"
& $accore /i "C:\Temp\input.dwg" /s "C:\Temp\script.scr" 2>&1 |
    Out-String | ForEach-Object { $_ -replace [char]0,'' }

Copy-Item "C:\Temp\output.dwg" "G:\Мой диск\Workspace\РЕЗУЛЬТАТ.dwg" -Force
```

---

## 1. Стандарт слоёв для трубопроводных разделов

### 1.1 Слои по разделам (ГОСТ 21.205-2021 / СПДС)

| Раздел | Слой подачи | Слой обратки/стока | Цвет | Вес (мм) |
|---|---|---|---|---|
| **ТС** (Тепловые сети) | `ТС-Т1` | `ТС-Т2` | 1 / 2 | 0.5 |
| **ТМ** (Тепломеханика) | `ТМ-Т1` | `ТМ-Т2` | 1 / 2 | 0.5 |
| **ТК** (Тепловые камеры) | `ТК-Т1` | `ТК-Т2` | 1 / 2 | 0.35 |
| **ОВ** (Отопление) | `ОВ-ПОД` | `ОВ-ОБР` | 30 / 10 | 0.35 |
| **ВК** (Вод-д + кан-я) | `ВК-ВОД` | `ВК-КАН` | 5 / 3 | 0.35 |
| **ВС** (Водоснабжение) | `ВС-Х` | `ВС-ГВС` | 140 / 30 | 0.35 |
| **ТХ** (Технология) | `ТХ-ПР` | `ТХ-ВОЗ` | 6 / 4 | 0.5 |

### 1.2 Служебные слои (общие для всех разделов)

| Назначение | Слой | Цвет | Тип линии | Вес |
|---|---|---|---|---|
| Оси разбивочные | `ОСИ` | 1 (красный) | CENTER2 | 0.18 |
| Размеры | `РАЗМЕРЫ` | 3 (зелёный) | Continuous | 0.18 |
| Текст / аннотации | `ТЕКСТ` | 2 (жёлтый) | Continuous | 0.18 |
| Оборудование (насосы, теплообм.) | `ОБОРУДОВАНИЕ` | 4 (голубой) | Continuous | 0.35 |
| Арматура трубопроводная | `АРМАТУРА` | 6 (пурпурный) | Continuous | 0.25 |
| Изоляция | `ИЗОЛЯЦИЯ` | 8 (серый) | Dashed2 | 0.18 |
| Подземные трубопроводы | `ПОДЗ` | 30 (оранжев.) | Hidden2 | 0.35 |
| Опоры, подвески | `ОПОРЫ` | 9 | Continuous | 0.25 |
| Рамка / штамп | `РАМКА` | 7 (белый) | Continuous | 0.7 |

### 1.3 Текстовые стили и размеры

- **ГОСТ** — `ISOCPEUR.shx`, высота 0, наклон 15°
- **ШТАМП** — `ISOCPEUR.shx`, высота 3.5 мм, наклон 0°
- Размерный стиль `ГОСТ_25`: засечки, текст над линией

---

## 2. Типы схем трубопроводных разделов

### 2.1 План трубопроводов (вид сверху)

**Применение:** ВК, ВС, ОВ, ТС, ТХ — разводка по этажу/территории

**Обязательные элементы:**
- Оси здания / координатная сетка
- Трубопроводы с указанием Ду (диаметра) и уклона
- Арматура: задвижки, краны, клапаны (ГОСТ 21.205)
- Отметки пола / лотка / верха трубы
- Нумерация узлов (тип «У-1», «У-2»...)
- Направление потока (стрелки)
- Спецификация (экспликация) оборудования

**Слои:** `раздел-ПОД`, `раздел-ОБР`, `ОБОРУДОВАНИЕ`, `АРМАТУРА`, `ОСИ`, `РАЗМЕРЫ`, `ТЕКСТ`

### 2.2 Аксонометрическая схема

**Применение:** ОВ, ВК, ВС — обязательна для внутренних систем

**Особенности:**
- Угол проецирования 45° (стандарт для СП-схем)
- Однолинейное отображение труб
- Полное указание диаметров на каждом участке
- Уклоны самотёчных участков (канализация: i = 0.02–0.04)
- Отметки этажей, перекрытий
- Нумерация стояков (Ст.1, Ст.2...)
- Балансировочные и запорные клапаны

**Масштаб:** без масштаба (условно), либо 1:100

### 2.3 Разрез / узел обвязки

**Применение:** ТМ, ТК, ТС — узлы ИТП, тепловые камеры

**Обязательные элементы:**
- Привязка к осям и отметкам
- Все фланцы, сварные швы, переходы
- Арматура с позициями
- Спецификация к узлу
- Марки трубопроводов (по P-ID)

### 2.4 Схема P&ID (принципиальная технологическая)

**Применение:** ТХ, ТМ — принципиальные схемы

**Стандарт обозначений:** ГОСТ 21.208, ISO 10628
- Аппараты — прямоугольники с наименованием
- Трубопроводы — линии с маркировкой
- Арматура — по ГОСТ 21.205
- КИПиА — кружки с буквенными обозначениями

### 2.5 Исполнительная схема (ИД)

**Для всех разделов ТХ/ВК/ВС/ОВ/ТК/ТМ/ТС**

**Обязательные элементы:**
- Угловой штамп по ГОСТ 21.101
- Фактические отметки (подчёркнутые или в рамке)
- Привязки к реперам / осям
- Фактические диаметры и длины
- Подпись геодезиста (для наружных сетей)
- Дата освидетельствования

### 2.6 Отводы трубопроводов по дуге (ГОСТ 17375-2001 / ГОСТ 30753-2001)

В исполнительных и монтажных схемах ТС, ТМ, ТХ, ВК повороты трассы отрисовываются радиусными отводами:
- **Радиус крутоизогнутого отвода**: $R \approx 1.5 D_y$ (ГОСТ 17375 тип 3D) или $R \approx 1.0 D_y$ (ГОСТ 30753 тип 2D).
- **Команды AutoCAD**:
  - `_.FILLET` с параметром `_R <значение>` для скругления прямых участков труб в дугу.
  - Полилиния `_.PLINE`: при построении поворот задаётся дуговым сегментом `_A` (Arc) с радиусом `_R`.
  - Дуга `_.ARC` по центру и конечным точкам (`_C` - Center).

---

## 3. Условные обозначения трубопроводной арматуры (ГОСТ 21.205)

> Обозначения соответствуют реальным чертежам (обновлено 15.10.2026 по чертежу пользователя).

### 3.1 Арматура — вид на чертеже

| Наименование | Вид на чертеже | Описание формы | Применение |
|---|---|---|---|
| **Кран шаровой** | `─▷◁─` | два треугольника вершинами навстречу (бабочка) | ВК, ВС, ОВ, ТХ |
| **Задвижка** | `─┤├─` | два вертикальных штриха со скобками | ТС, ТМ, ВК |
| **Вентиль запорный** | `─▽─` | треугольник вершиной вниз | ОВ, ВС, ТХ |
| **Клапан обратный** | `─▷‖─` | треугольник + вертикаль | ВК, ВС, ТС |
| **Клапан предохр.** | `─▽↑─` | треугольник + выпуск вверх | ТМ, ТС, ТХ |
| **Клапан регулир.** | `─▷◁M─` | бабочка + кружок с буквой привода | ОВ, ТС (ИТП) |
| **Балансировочный** | `─▷◁∅─` | бабочка + метка настройки | ОВ |
| **Фильтр (грязевик)** | `─┤Y├─` | треугольник в корпусе | ВК, ТС, ОВ |
| **Расходомер** | `─⊙─` | кружок с точкой | ТС, ТХ, ВС |
| **Манометр** | выноска в `○` | наклонная линия → кружок с буквой M | ТС, ТМ, ТХ |
| **Термометр** | выноска в `○` | наклонная линия → кружок с буквой T | ТС, ТМ |
| **Воздухоотводчик** | `↑` на трубе | стрелка вверх от точки трубы | ОВ, ТС |
| **Дренаж** | `↓` на трубе | стрелка вниз от точки трубы | ОВ, ТС, ТМ |
| **Фланец** | `─║─` | двойная вертикальная черта | все |
| **Заглушка фланц.** | `─║●` | вертикаль + закрашенный круг | все |

### 3.2 Маркеры на трубопроводах (из чертежа пользователя)

| Элемент | Вид | Описание |
|---|---|---|
| **Номер стыка** | `●─ ст.1` | закрашенный кружок Ø3–4 мм с полкой и текстом `ст.N` |
| **Позиция по спецификации** | `/─[45]` | диагональная полка + прямоугольник с номером позиции |
| **Опора неподвижная** | `─✳─` | звезда / перекрещённые диагонали поперёк трубы |
| **Опора скользящая** | `═══` | двойная параллельная линия поперёк трубы |
| **Направление потока** | `──►──` | стрелка на линии трубопровода |

### 3.3 Правила нанесения маркеров

```
Номер стыка:
  ● ─── ст.1     закрашенный кружок в точке стыка → горизонтальная полка → текст

Позиция по спецификации (выноска):
  / ─── [45]     наклонная линия от объекта → горизонтальная полка → прямоугольник с номером

Опора неподвижная:
  ──✳──          рисуется поперёк трубы; фиксирует трубу от смещения вдоль оси

Опора скользящая:
  ──═══──        двойная линия поперёк; труба может скользить вдоль оси
```

### 3.4 Маркировка трубопроводов (линейная марка)

```
Ду150 / Т1 / 1.1 / →
│       │    │      └─ направление потока
│       │    └──────── номер линии
│       └───────────── среда (Т1=подача, Т2=обратка, Х=хол.вода, Г=горячая)
└───────────────────── диаметр условный
```

---

## 4. Нормативные документы по разделам

| Раздел | СП / ГОСТ | Название |
|---|---|---|
| **ВК** | СП 30.13330.2020 | Внутренний водопровод и канализация |
| **ВС** | СП 31.13330.2021 | Водоснабжение. Наружные сети и сооружения |
| **ОВ** | СП 60.13330.2020 | Отопление, вентиляция, кондиционирование |
| **ТС** | СП 74.13330.2011 | Тепловые сети |
| **ТМ** | СП 89.13330.2016 | Котельные установки |
| **ТК** | СП 124.13330.2012 | Тепловые сети (камеры) |
| **ТХ** | ГОСТ 21.208-2013 | Схемы технологических трубопроводов |
| Все | ГОСТ 21.205-2021 | Условные обозначения трубопроводов |
| Все | ГОСТ 21.101-97 | Требования к проектной документации |
| Все | ГОСТ 21.110-2013 | Спецификация оборудования |

---

## 5. Масштабы

| Тип схемы | Масштабы |
|---|---|
| Планы трубопроводов | 1:50, 1:100, 1:200 |
| Узлы, детали | 1:5, 1:10, 1:20 |
| Исполнительные схемы | 1:50, 1:100, 1:200 |
| Аксонометрия | без масштаба |
| P&ID | без масштаба |
| Тепловые камеры (план) | 1:20, 1:50 |
| Наружные сети (трасса) | 1:500, 1:1000 |

---

## 6. Дерево решений для агента

```
Запрос пользователя
│
├── Связан с DWG-файлом? (удалить/изменить/обработать)
│   ├── Удалить объекты (размеры, выноски, текст) → Ветка A (LISP inline)
│   ├── Заменить/обновить текст, формулировки таблиц → Ветка C (DXF пайплайн)
│   ├── Синхронизировать схемы по аналогии (Т1 → Т2...) → Ветка D
│   ├── Дозаполнить спецификации / интервалы стыков / исправить шрифты → Ветка E (ACAD_TABLE DXF)
│   └── Все цвета в белый / монохром / обесцветить → Ветка F (Пакетное обесцвечивание)
│
├── Нужен скрипт / команды AutoCAD?
│   └── → Ветка B: Скрипты (раздел 0 + references/lisp_snippets.md)
│
├── Нужна схема трубопроводов?
│   ├── план разводки → раздел 2.1
│   ├── аксонометрия → раздел 2.2
│   ├── узел/разрез → раздел 2.3
│   ├── P&ID → раздел 2.4
│   ├── отводы по дуге → раздел 2.6
│   └── исполнительная → раздел 2.5 + references/executive_doc.md
│
├── Нужны слои / условные обозначения?
│   └── → раздел 1 + раздел 3 + references/layers_script.md
│
└── Нормы, допуски, ГОСТ? → скилл pto-normative-base
    Объёмы, спецификация труб? → скилл pto-quantity-takeoff
```

### Ветка A: Удаление объектов в DWG (обязательная последовательность)

```
1. New-Item "C:\Temp" -ItemType Directory -Force | Out-Null
2. Copy-Item "G:\Мой диск\Workspace\файл.dwg" "C:\Temp\input.dwg" -Force
3. Создать C:\Temp\script.scr (inline LISP, выход _.QUIT -> _Y)
4. & "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe" /i "C:\Temp\input.dwg" /s "C:\Temp\script.scr"
5. Test-Path "C:\Temp\output.dwg"
6. Copy-Item "C:\Temp\output.dwg" "G:\Мой диск\Workspace\результат.dwg" -Force
```

| Что удалить | LISP-строка в SCR |
|---|---|
| Размеры (только DIMENSION) | `(progn (setq ss (ssget "X" '((0 . "DIMENSION")))) (if ss (command "_.ERASE" ss "")))` |
| **Размеры полностью (комплекс)**<br>(DIMENSION + засечки GT_1/Defpoints + длины `L=...`) | `(progn (setq ss (ssget "X" '((0 . "DIMENSION")))) (if ss (command "_.ERASE" ss "")) (setq ss (ssget "X" '((0 . "LWPOLYLINE") (8 . "GT_1,Defpoints")))) (if ss (command "_.ERASE" ss "")) (setq ss (ssget "X" '((0 . "MTEXT") (8 . "0")))) (if ss (progn (setq i 0) (while (< i (sslength ss)) (setq e (ssname ss i)) (if (wcmatch (cdr (assoc 1 (entget e))) "*L=*") (entdel e)) (setq i (1+ i))))))` |
| Выноски | `(progn (setq ss (ssget "X" '((0 . "LEADER,MLEADER")))) (if ss (command "_.ERASE" ss "")))` |
| Текст | `(progn (setq ss (ssget "X" '((0 . "TEXT,MTEXT")))) (if ss (command "_.ERASE" ss "")))` |
| Штриховку | `(progn (setq ss (ssget "X" '((0 . "HATCH")))) (if ss (command "_.ERASE" ss "")))` |
| Всё на слое | `(progn (setq ss (ssget "X" '((8 . "ИМЯ_СЛОЯ")))) (if ss (command "_.ERASE" ss "")))` |

### Ветка C: Пакетная замена текста и таблиц спецификаций (DXF-пайплайн)

> [!TIP]
> Таблицы AutoCAD (`ACAD_TABLE`), блоки и выноски на разных листах надёжнее и быстрее всего обновлять через экспорт в DXF, строковую замену в PowerShell и обратную сборку в DWG.
> **Критически важно:** при открытии файла через `/i "файл.dxf"` AutoCAD *уже* загружает его. Команда `_.DXFIN` в SCR **не требуется**, иначе все объекты чертежа продублируются!

```powershell
$accore = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"
Copy-Item "G:\Мой диск\Workspace\файл.dwg" "C:\Temp\input_text.dwg" -Force

# 1. Экспорт в DXF
"_.DXFOUT`nC:\Temp\input_text.dxf`n16`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\export_dxf.scr" -Encoding UTF8
& $accore /i "C:\Temp\input_text.dwg" /s "C:\Temp\export_dxf.scr" 2>&1 | Out-Null

# 2. Замена текста (строго UTF-8 БЕЗ BOM)
# При замене цепочек строк (например, Итого монтаж -> Итого монтаж+фасонка, а Итого монтаж+фасонка -> Общая длина):
# Всегда заменять строку 2 первой, либо делать точечную замену по строгому равенству!
$txt = [System.IO.File]::ReadAllText("C:\Temp\input_text.dxf", [System.Text.Encoding]::UTF8)
$txt = $txt.Replace("СТАРАЯ_СТРОКА_2", "НОВАЯ_СТРОКА_2")
$txt = $txt.Replace("СТАРАЯ_СТРОКА_1", "НОВАЯ_СТРОКА_1")
$noBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText("C:\Temp\output_text.dxf", $txt, $noBom)

# 3. Конвертация DXF -> DWG 2018 (без дублирования через DXFIN!)
"_.SAVEAS`n2018`nC:\Temp\output_text_final`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\save_dwg.scr" -Encoding UTF8
& $accore /i "C:\Temp\output_text.dxf" /s "C:\Temp\save_dwg.scr" 2>&1 | Out-Null

# 4. Возврат результата
Copy-Item "C:\Temp\output_text_final.dwg" "G:\Мой диск\Workspace\файл.dwg" -Force
```

### Ветка D: Синхронизация схем по аналогии (Т1 → Т2, Т3, ...)

> Используется при запросах: «по её аналогии наложи корректировки на схему...».
> Выполняет полный цикл за 1 запуск (~15 сек): очистка размеров + обновление спецификаций + сохранение и верификация.

```powershell
$targetName = "2547.21-377.4-ТС Т2 (15.10.2026).dwg"
$sourcePath = "G:\Мой диск\Workspace\$targetName"
$accore = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"

# 1. Подготовка и бэкап
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Copy-Item $sourcePath "G:\Мой диск\Workspace\${targetName}_backup.dwg" -Force
Copy-Item $sourcePath "C:\Temp\target_in.dwg" -Force

# 2. Комплексная очистка размеров через AutoLISP в accoreconsole
@'
(progn
  (setq ss (ssget "X" '((0 . "DIMENSION")))) (if ss (command "_.ERASE" ss ""))
  (setq ss (ssget "X" '((0 . "LWPOLYLINE") (8 . "GT_1,Defpoints")))) (if ss (command "_.ERASE" ss ""))
  (setq ss (ssget "X" '((0 . "MTEXT") (8 . "0"))))
  (if ss (progn (setq i 0) (while (< i (sslength ss)) (setq e (ssname ss i)) (if (wcmatch (cdr (assoc 1 (entget e))) "*L=*") (entdel e)) (setq i (1+ i))))))
_.SAVEAS
2018
C:\Temp\target_nodims
_.QUIT
_Y

'@ | Set-Content "C:\Temp\clean_dims.scr" -Encoding UTF8
& $accore /i "C:\Temp\target_in.dwg" /s "C:\Temp\clean_dims.scr" 2>&1 | Out-Null

# 3. Экспорт в DXF для правок спецификаций
"_.DXFOUT`nC:\Temp\target.dxf`n16`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\exp_dxf.scr" -Encoding UTF8
& $accore /i "C:\Temp\target_nodims.dwg" /s "C:\Temp\exp_dxf.scr" 2>&1 | Out-Null

# 4. Обновление формулировок спецификаций (строгий порядок: строка 2 -> строка 1)
$lines = [System.IO.File]::ReadAllLines("C:\Temp\target.dxf", [System.Text.Encoding]::UTF8)
$row1Old = "{\W1;Итого: монтаж трубопровода}"
$row2Old = "{\W1;Итого: монтаж трубопровода+фасонные изделия}"
$row1New = "{\W1;Итого: монтаж трубопровода+фасонные изделия}"
$row2New = "{\W1;Итого: Общая протяженность участка линии}"

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -eq $row2Old) { $lines[$i] = $row2New }
    elseif ($lines[$i] -eq $row1Old) { $lines[$i] = $row1New }
}
$noBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines("C:\Temp\target_clean.dxf", $lines, $noBom)

# 5. Сборка финального DWG 2018 (через SAVEAS, без дублирования DXFIN)
"_.SAVEAS`n2018`nC:\Temp\target_final`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\save_final.scr" -Encoding UTF8
& $accore /i "C:\Temp\target_clean.dxf" /s "C:\Temp\save_final.scr" 2>&1 | Out-Null

# 6. Перенос результата
Copy-Item "C:\Temp\target_final.dwg" $sourcePath -Force
```

### Ветка E: Дозаполнение таблиц ACAD_TABLE (спецификации, интервалы стыков) и исправление шрифтов

> [!IMPORTANT]
> **Архитектурный факт:** `accoreconsole` не имеет COM-сервера, вызовы AutoLISP `(vlax-ename->vla-object)` возвращают `nil`.
> **Прямое и надёжное решение:** редактирование структуры ячеек `ACAD_TABLE` в DXF через PowerShell. При открытии модифицированного DXF `accoreconsole` **автоматически пересчитывает таблицу и пересоздаёт внутренний анонимный блок `*T...`** со всеми MTEXT и координатами!

```powershell
$targetDwg = "G:\Мой диск\Workspace\ЧЕРТЁЖ.dwg"
$accore    = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"

# 1. Подготовка и бэкап
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Copy-Item $targetDwg "G:\Мой диск\Workspace\ЧЕРТЁЖ_backup.dwg" -Force
Copy-Item $targetDwg "C:\Temp\pipe_in.dwg" -Force

# 2. Экспорт DWG -> DXF 2018
"_.DXFOUT`nC:\Temp\pipe_in.dxf`n16`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\exp.scr" -Encoding UTF8
& $accore /i "C:\Temp\pipe_in.dwg" /s "C:\Temp\exp.scr" 2>&1 | Out-Null

# 3. Обработка DXF (шрифты + ячейки таблиц)
$lines = [System.IO.File]::ReadAllLines("C:\Temp\pipe_in.dxf", [System.Text.Encoding]::UTF8)

# 3.1 Глобальная замена шрифтов на стандартный ГОСТ ISOCPEUR
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Contains("CS_Gost2304.shx")) { $lines[$i] = $lines[$i].Replace("CS_Gost2304.shx", "isocpeur.ttf") }
    if ($lines[$i].Contains("Russia-GOST_Topo.shx")) { $lines[$i] = $lines[$i].Replace("Russia-GOST_Topo.shx", "isocpeur.ttf") }
    if ($lines[$i].Contains("GOST Common")) { $lines[$i] = $lines[$i].Replace("GOST Common", "ISOCPEUR") }
}

# 3.2 Словарь обновлений таблиц: Handle таблицы -> @{ ИндексЯчейки = "НовоеЗначение" }
# Каждая ячейка в таблице нумеруется от 0 (Row 0 Col 0, Row 0 Col 1, ...)
$tableUpdates = @{
    # Пример таблицы спецификации (6 колонок: поз, наим, п.м, шт, вес_шт, общ_вес)
    # "8C468" = @{ 22 = "0,67"; 23 = "5,36" }
    # Пример таблицы интервалов стыков (стык -> строительная длина из Размеры.xlsx)
    # "8D74F" = @{ 3 = "38"; 9 = "38"; 29 = "2870"; 31 = "3000" }
}

$newLines = New-Object System.Collections.Generic.List[string]($lines.Length + 5000)
$inEntities = $false
$i = 0

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
        
        $map = $tableUpdates[$tHandle]
        if ($map -ne $null) {
            $cellIdx = 0
            $k = $i
            while ($k -le $tEnd) {
                # Пропускаем динамические ссылки на поля (344), мешающие записи статического значения
                if ($lines[$k].Trim() -eq "344") { $k += 2; continue }

                if ($lines[$k].Trim() -eq "301" -and $lines[$k+1].Trim() -eq "CELL_VALUE") {
                    $cStart = $k
                    $cEnd = $tEnd
                    for ($m = $k + 2; $m -le $tEnd; $m += 2) {
                        if ($lines[$m].Trim() -eq "304" -and $lines[$m+1].Trim() -eq "ACVALUE_END") { $cEnd = $m + 1; break }
                    }
                    
                    $hasCode1 = $false
                    $cellText = ""
                    for ($m = $cStart; $m -le $cEnd; $m += 2) {
                        if ($lines[$m].Trim() -eq "1") { $hasCode1 = $true; $cellText = $lines[$m+1] }
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
                            # Пустая ячейка: формируем стандартный текстовый блок ячейки
                            $newLines.Add("301"); $newLines.Add("CELL_VALUE")
                            $newLines.Add(" 93"); $newLines.Add("        6")
                            $newLines.Add(" 90"); $newLines.Add("        4")
                            $newLines.Add("  1"); $newLines.Add($targetVal)
                            $newLines.Add(" 94"); $newLines.Add("        0")
                            $newLines.Add("300"); $newLines.Add("")
                            $newLines.Add("302"); $newLines.Add($targetVal)
                            $newLines.Add("304"); $newLines.Add("ACVALUE_END")
                        }
                    } else {
                        # Если ячейка не обновляется, но содержит битые теги шрифта \f... - очищаем
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

# Запись DXF строго без BOM
$noBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines("C:\Temp\pipe_mod.dxf", $newLines, $noBom)

# 4. Сборка DWG 2018 (ОБЯЗАТЕЛЬНО удалять старый файл перед SAVEAS во избежание зависания!)
Remove-Item "C:\Temp\pipe_final.dwg" -Force -ErrorAction SilentlyContinue
"_.SAVEAS`n2018`nC:\Temp\pipe_final`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\save.scr" -Encoding UTF8
& $accore /i "C:\Temp\pipe_mod.dxf" /s "C:\Temp\save.scr" 2>&1 | Out-Null

# 5. Возврат в Workspace
Copy-Item "C:\Temp\pipe_final.dwg" $targetDwg -Force
```

### Ветка F: Пакетный перевод чертежа в белый цвет (AutoCAD Color 7 / White)

> Используется при запросах: «все цвета белые», «белый цвет», «белого света», «сделай все белым», «монохром», «обесцветить чертеж», «перекрась в белый».
> Полный цикл за 1 запуск (~5–7 секунд):
> 1. Все слои чертежа переводятся в цвет 7 (White).
> 2. Удаляются все переопределения TrueColor (коды 420) и ColorName (коды 430).
> 3. Все жестко заданные цвета объектов (код 62) переводятся в цвет 7.
> 4. Очищаются внутренние теги цвета MTEXT (`\C...;` и `\c...;`).
> 5. Исправляются битые шрифты ГОСТ (`CS_Gost2304.shx` -> `isocpeur.ttf`, `GOST Common` -> `ISOCPEUR`).
> 6. Геометрия внутри всех блоков (арматура, штамп, оборудование, таблицы) становится белой.

**Быстрый запуск готовым скриптом (1 строка):**
```powershell
& "C:\Users\User\.gemini\config\skills\pto-autocad-schemes\references\make_drawing_white.ps1" -FilePath "G:\Мой диск\Workspace\ЧЕРТЁЖ.dwg"
```

**Либо inline-шаблон PowerShell:**
```powershell
$targetDwg = "G:\Мой диск\Workspace\ЧЕРТЁЖ.dwg"
$accore    = "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe"

# 1. Подготовка и бэкап
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
$dir = [System.IO.Path]::GetDirectoryName($targetDwg)
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($targetDwg)
$backupPath = Join-Path $dir "${baseName}_backup.dwg"
if (-not (Test-Path $backupPath)) { Copy-Item $targetDwg $backupPath -Force }
Copy-Item $targetDwg "C:\Temp\white_in.dwg" -Force

# 2. Экспорт DWG -> DXF 2018
Remove-Item "C:\Temp\white_in.dxf" -Force -ErrorAction SilentlyContinue
"_.DXFOUT`nC:\Temp\white_in.dxf`n16`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\exp_white.scr" -Encoding UTF8
& $accore /i "C:\Temp\white_in.dwg" /s "C:\Temp\exp_white.scr" 2>&1 | Out-Null

# 3. Пакетная очистка цветов (слои 7, объекты 7, удаление 420/430, теги MTEXT)
$lines = [System.IO.File]::ReadAllLines("C:\Temp\white_in.dxf", [System.Text.Encoding]::UTF8)
$newLines = New-Object System.Collections.Generic.List[string]($lines.Length)
$inLayers = $false

$i = 0
while ($i -lt $lines.Length - 1) {
    $c = $lines[$i].Trim(); $v = $lines[$i+1]; $vTrim = $v.Trim()

    if ($c -eq "2" -and $vTrim -eq "LAYER") { $inLayers = $true }
    if ($inLayers -and $c -eq "0" -and $vTrim -eq "ENDTAB") { $inLayers = $false }

    # Удаление TrueColor (420) и ColorName (430)
    if ($c -in @("420", "430")) { $i += 2; continue }

    # Все цвета 62 -> 7 (Белый)
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

    # Чистка тегов цвета в тексте
    if ($c -in @("1", "3", "300", "302") -and ($v.Contains("\C") -or $v.Contains("\c"))) {
        $cleanV = [regex]::Replace($v, '\\C\d+;', '\C7;')
        $cleanV = [regex]::Replace($cleanV, '\\c\d+;', '\C7;')
        $newLines.Add($lines[$i]); $newLines.Add($cleanV)
        $i += 2
        continue
    }

    # Шрифты ГОСТ
    if ($v.Contains("CS_Gost2304.shx")) { $v = $v.Replace("CS_Gost2304.shx", "isocpeur.ttf") }
    if ($v.Contains("Russia-GOST_Topo.shx")) { $v = $v.Replace("Russia-GOST_Topo.shx", "isocpeur.ttf") }
    if ($v.Contains("GOST Common")) { $v = $v.Replace("GOST Common", "ISOCPEUR") }

    $newLines.Add($lines[$i]); $newLines.Add($v)
    $i += 2
}
if ($i -lt $lines.Length) { $newLines.Add($lines[$i]) }

$noBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines("C:\Temp\white_out.dxf", $newLines, $noBom)

# 4. Сборка DWG 2018 (обязательно удалять целевой файл перед SAVEAS)
Remove-Item "C:\Temp\white_final.dwg" -Force -ErrorAction SilentlyContinue
"_.SAVEAS`n2018`nC:\Temp\white_final`n_.QUIT`n_Y`n" | Set-Content "C:\Temp\save_white.scr" -Encoding UTF8
& $accore /i "C:\Temp\white_out.dxf" /s "C:\Temp\save_white.scr" 2>&1 | Out-Null

# 5. Возврат в Workspace
Copy-Item "C:\Temp\white_final.dwg" $targetDwg -Force
```

---

## 7. Ссылки

- [references/make_drawing_white.ps1](./references/make_drawing_white.ps1) — скрипт 100% перевода чертежа в белый цвет
- [references/autocad_commands.md](./references/autocad_commands.md) — шпаргалка команд AutoCAD
- [references/lisp_snippets.md](./references/lisp_snippets.md) — AutoLISP сниппеты
- [references/layers_script.md](./references/layers_script.md) — SCR-скрипт создания слоёв
- [references/executive_doc.md](./references/executive_doc.md) — Исполнительная документация
- [references/dwg_automation.md](./references/dwg_automation.md) — Пакетная обработка DWG
- [references/update_acad_tables.ps1](./references/update_acad_tables.ps1) — обновление таблиц ACAD_TABLE
