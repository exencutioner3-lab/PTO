# AutoLISP сниппеты для ПТО

## 1. Создание слоёв трубопроводных разделов одной командой

```lisp
(defun c:СЛОИ-ПТО ( / )
  ;; Создаёт стандартные слои для чертежей ТХ/ВК/ВС/ОВ/ТК/ТМ/ТС
  (defun make-layer (name color ltype lweight)
    (entmake
      (list '(0 . "LAYER")
            '(100 . "AcDbSymbolTableRecord")
            '(100 . "AcDbLayerTableRecord")
            (cons 2 name)
            '(70 . 0)
            (cons 62 color)
            (cons 6 ltype)
            (cons 370 lweight))))
  
  ;; Загрузка типов линий
  (command "_.LINETYPE" "_L" "CENTER2" "" "")
  (command "_.LINETYPE" "_L" "DASHED2" "" "")
  (command "_.LINETYPE" "_L" "HIDDEN2" "" "")
  
  ;; Служебные слои
  (make-layer "ОСИ"          1   "CENTER2"    18)
  (make-layer "РАЗМЕРЫ"      3   "Continuous" 18)
  (make-layer "ТЕКСТ"        2   "Continuous" 18)
  (make-layer "ОБОРУДОВАНИЕ" 4   "Continuous" 35)
  (make-layer "АРМАТУРА"     6   "Continuous" 25)
  (make-layer "ИЗОЛЯЦИЯ"     8   "DASHED2"    18)
  (make-layer "ОПОРЫ"        9   "Continuous" 25)
  (make-layer "РАМКА"        7   "Continuous" 70)
  ;; Тепловые сети ТС
  (make-layer "ТС-Т1"        1   "Continuous" 50)
  (make-layer "ТС-Т2"        2   "DASHED2"    50)
  (make-layer "ТС-ПОДЗ"      30  "HIDDEN2"    35)
  ;; Тепломеханика ТМ
  (make-layer "ТМ-Т1"        1   "Continuous" 50)
  (make-layer "ТМ-Т2"        2   "DASHED2"    50)
  ;; Тепловые камеры ТК
  (make-layer "ТК-Т1"        1   "Continuous" 35)
  (make-layer "ТК-Т2"        2   "DASHED2"    35)
  ;; Отопление ОВ
  (make-layer "ОВ-ПОД"       30  "Continuous" 35)
  (make-layer "ОВ-ОБР"       10  "DASHED2"    35)
  ;; Водопровод и канализация ВК
  (make-layer "ВК-ВОД"       5   "Continuous" 35)
  (make-layer "ВК-КАН"       3   "Continuous" 35)
  ;; Водоснабжение ВС
  (make-layer "ВС-Х"         140 "Continuous" 35)
  (make-layer "ВС-ГВС"       30  "Continuous" 35)
  ;; Технология ТХ
  (make-layer "ТХ-ПР"        6   "Continuous" 50)
  (make-layer "ТХ-ВОЗ"       4   "DASHED2"    50)
  
  (princ "\nСлои трубопроводных разделов созданы успешно.")
  (princ)
)
```

## 2. Автонумерация позиций (марок)

```lisp
(defun c:НУМЕРАЦИЯ ( / pt num str)
  ;; Последовательно расставляет числовые марки
  ;; Запрос начального номера
  (setq num (getint "\nНачальный номер <1>: "))
  (if (null num) (setq num 1))
  
  (while (setq pt (getpoint "\nТочка вставки марки (Enter — завершить): "))
    (setq str (itoa num))
    (entmake
      (list '(0 . "TEXT")
            '(100 . "AcDbEntity")
            (cons 8 "ТЕКСТ")        ; слой
            '(100 . "AcDbText")
            (cons 10 pt)            ; точка вставки
            '(40 . 3.5)            ; высота текста
            (cons 1 str)            ; строка
            '(72 . 1)              ; выравнивание по центру
            '(11 . (0 0 0))))      ; вторая точка (центр)
    (setq num (1+ num))
  )
  (princ)
)
```

## 3. Подсчёт длины полилиний на слое

```lisp
(defun c:ДЛИНА-СЛОЯ ( / layer-name ss total len ename edata)
  (setq layer-name (getstring "\nИмя слоя: "))
  (setq ss (ssget "X" (list (cons 8 layer-name)
                             '(0 . "LWPOLYLINE,LINE"))))
  (setq total 0.0)
  
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename (ssname ss i))
        (setq edata (entget ename))
        (if (= (cdr (assoc 0 edata)) "LWPOLYLINE")
          (setq len (vla-get-Length
                      (vlax-ename->vla-object ename)))
          ;; LINE
          (setq len (distance
                      (cdr (assoc 10 edata))
                      (cdr (assoc 11 edata))))
        )
        (setq total (+ total len))
        (setq i (1+ i))
      )
      (alert (strcat "Суммарная длина на слое " layer-name
                     ":\n" (rtos total 2 2) " ед.чертежа"))
    )
    (alert (strcat "Объекты на слое " layer-name " не найдены."))
  )
  (princ)
)
```

## 4. Вставка марки оборудования (блок с атрибутом)

```lisp
(defun c:МАРКА ( / pt pos-num)
  ;; Вставляет кружок с номером позиции (лидерный выноска)
  (setq pos-num (getstring "\nНомер позиции: "))
  (setq pt (getpoint "\nТочка вставки: "))
  
  ;; Рисуем кружок Ø10
  (command "_.CIRCLE" pt 5.0)
  
  ;; Текст в центре
  (command "_.TEXT" "_J" "_MC" pt 3.5 0 pos-num)
  (princ)
)
```

## 5. Копирование свойств слоя на выбранные объекты

```lisp
(defun c:НА-СЛОЙ ( / layer-name ss i ename edata new-data)
  (setq layer-name (getstring "\nПеренести на слой: "))
  (setq ss (ssget "\nВыберите объекты: "))
  
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename (ssname ss i))
        (setq edata (entget ename))
        (setq new-data (subst (cons 8 layer-name)
                               (assoc 8 edata)
                               edata))
        (entmod new-data)
        (setq i (1+ i))
      )
      (princ (strcat "\nОбъекты перенесены на слой: " layer-name))
    )
  )
  (princ)
)
```

## 6. Быстрое создание рамки формата

```lisp
(defun c:РАМКА-А1 ( / )
  ;; Рамка А1 (841x594) с отступами по ГОСТ
  ;; Левое поле 20, остальные 5
  (setvar "CLAYER" "РАМКА")
  (command "_.RECTANGLE" "0,0" "841,594")          ; внешний контур
  (command "_.RECTANGLE" "20,5" "836,589")         ; рамка чертежа
  (princ "\nРамка А1 создана. Добавьте штамп вручную.")
  (princ)
)

(defun c:РАМКА-А2 ( / )
  (setvar "CLAYER" "РАМКА")
  (command "_.RECTANGLE" "0,0" "594,420")
  (command "_.RECTANGLE" "20,5" "589,415")
  (princ "\nРамка А2 создана.")
  (princ)
)

(defun c:РАМКА-А3 ( / )
  (setvar "CLAYER" "РАМКА")
  (command "_.RECTANGLE" "0,0" "420,297")
  (command "_.RECTANGLE" "20,5" "415,292")
  (princ "\nРамка А3 создана.")
  (princ)
)
```

## 7. Сопряжение труб радиусным отводом (дугой по R = 1.5 Dy)

```lisp
(defun c:ОТВОД-ДУГА ( / dy r)
  ;; Сопрягает две пересекающиеся или смежные линии труб дугой отвода
  (setq dy (getreal "\nВведите условный диаметр трубы Ду, мм (напр. 150): "))
  (if (and dy (> dy 0))
    (progn
      ;; Радиус крутоизогнутого отвода ГОСТ 17375 R = 1.5 * Dy
      (setq r (* 1.5 dy))
      (setvar "FILLETRAD" r)
      (princ (strcat "\nРадиус сопряжения установлен: " (rtos r 2 1) " мм."))
      (command "_.FILLET")
    )
    (princ "\nНекорректный диаметр.")
  )
  (princ)
)
```

## 8. Поиск и вывод содержимого ячеек таблиц (ACAD_TABLE)

```lisp
(defun c:ИНСПЕКТОР-ТАБЛИЦ ( / doc ss i ent row col nrows ncols celltxt)
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq ss (ssget "X" '((0 . "ACAD_TABLE"))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent (vlax-ename->vla-object (ssname ss i)))
        (setq nrows (vla-get-Rows ent))
        (setq ncols (vla-get-Columns ent))
        (princ (strcat "\nТаблица #" (itoa (1+ i)) " (Строк: " (itoa nrows) ", Колонок: " (itoa ncols) "):"))
        (setq row 0)
        (while (< row nrows)
          (setq col 0)
          (while (< col ncols)
            (setq celltxt (vla-GetText ent row col))
            (if (/= celltxt "")
              (princ (strcat "\n  [" (itoa row) "," (itoa col) "]: " celltxt))
            )
            (setq col (1+ col))
          )
          (setq row (1+ row))
        )
        (setq i (1+ i))
      )
    )
    (princ "\nТаблицы ACAD_TABLE в чертеже не найдены.")
  )
  (princ)
)
```

## 9. Комплексная очистка чертежа от размеров (DIMENSION + засечки + длины L=...)

```lisp
(defun c:ОЧИСТКА-РАЗМЕРОВ ( / ss1 ss2 ss3 i ent txt )
  ;; 1. Удаление объектов DIMENSION
  (setq ss1 (ssget "X" '((0 . "DIMENSION"))))
  (if ss1 (command "_.ERASE" ss1 ""))

  ;; 2. Удаление засечек и выносных линий (LWPOLYLINE на GT_1 и Defpoints)
  (setq ss2 (ssget "X" '((0 . "LWPOLYLINE") (8 . "GT_1,Defpoints"))))
  (if ss2 (command "_.ERASE" ss2 ""))

  ;; 3. Удаление размерных надписей длин L=... на слое 0
  (setq ss3 (ssget "X" '((0 . "MTEXT") (8 . "0"))))
  (if ss3
    (progn
      (setq i 0)
      (while (< i (sslength ss3))
        (setq ent (ssname ss3 i))
        (setq txt (cdr (assoc 1 (entget ent))))
        (if (wcmatch txt "*L=*")
          (entdel ent)
        )
        (setq i (1+ i))
      )
    )
  )
  (princ "\nКомплексная очистка размеров завершена.")
  (princ)
)
```

## Загрузка файла LISP в AutoCAD

```
В командной строке AutoCAD:
(load "C:/путь/к/файлу.lsp")

Или через меню:
Сервис → Загрузить приложение → выбрать .lsp файл
```
