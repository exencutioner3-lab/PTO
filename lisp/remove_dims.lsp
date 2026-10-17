; AutoLISP скрипт: удаление всех размеров (DIMENSION, LEADER, MLEADER)
; Запуск: accoreconsole.exe /i "чертёж.dwg" /s "remove_dims.lsp"

(defun remove-type (dxftype space / ss i)
  (setq ss (ssget "X" (list (cons 0 dxftype))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (entdel (ssname ss i))
        (setq i (1+ i)))
      (sslength ss))
    0))

(defun c:REMOVE-DIMS ( / total)
  (setq total 0)
  
  ; Удаляем все типы размерных объектов
  (setq total (+ total (remove-type "DIMENSION" nil)))
  (setq total (+ total (remove-type "LEADER" nil)))
  (setq total (+ total (remove-type "MLEADER" nil)))
  
  (princ (strcat "\nУдалено объектов: " (itoa total) "\n"))
  total)

; Выполнить немедленно при загрузке
(REMOVE-DIMS)

; Сохранить как новый файл
(command "_.SAVEAS" "2018"
  "G:\\Мой диск\\Workspace\\2547.21-377.4-ТС Т1 (10.10.2026)_no_dims")

(princ "\nФайл сохранён: _no_dims.dwg\n")
(quit)
