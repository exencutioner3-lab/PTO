"""
remove_dimensions.py
Удаляет все размерные объекты (DIMENSION) из DWG-файла.
Сохраняет результат с суффиксом _no_dims.dwg
"""

import sys
import shutil
from pathlib import Path
import ezdxf

# ─── Настройки ────────────────────────────────────────────────────────────────
INPUT_FILE = Path(r"G:\Мой диск\Workspace\2547.21-377.4-ТС Т1 (10.10.2026).dwg")
OUTPUT_FILE = INPUT_FILE.with_stem(INPUT_FILE.stem + "_no_dims")

# Типы объектов, которые нужно удалить:
# DIMENSION       — линейные, угловые, радиусные, диаметральные размеры
# LEADER / MLEADER — выноски с размерными текстами
# ACAD_TABLE      — таблицы (опционально, раскомментировать если нужно)
DIM_TYPES = {"DIMENSION", "LEADER", "MLEADER"}

# ─── Основная логика ──────────────────────────────────────────────────────────

def remove_dims(input_path: Path, output_path: Path) -> int:
    print(f"Открываю: {input_path}")
    
    try:
        doc = ezdxf.readfile(str(input_path))
    except ezdxf.DXFStructureError as e:
        print(f"Ошибка чтения DWG: {e}")
        sys.exit(1)

    removed = 0

    # Обрабатываем все пространства: модельное + все листы
    spaces = [doc.modelspace()]
    for layout in doc.layouts:
        if layout.name != "Model":
            spaces.append(layout)

    for space in spaces:
        to_delete = [
            entity
            for entity in space
            if entity.dxftype() in DIM_TYPES
        ]
        for entity in to_delete:
            space.delete_entity(entity)
            removed += 1
        
        if to_delete:
            print(f"  Пространство '{space.name}': удалено {len(to_delete)} объектов")

    print(f"\nВсего удалено: {removed} размерных объектов")
    print(f"Сохраняю в: {output_path}")
    doc.saveas(str(output_path))
    print("Готово!")
    return removed


if __name__ == "__main__":
    # Проверка входного файла
    if not INPUT_FILE.exists():
        print(f"Файл не найден: {INPUT_FILE}")
        sys.exit(1)

    if OUTPUT_FILE.exists():
        print(f"Выходной файл уже существует, перезаписываю: {OUTPUT_FILE}")

    removed_count = remove_dims(INPUT_FILE, OUTPUT_FILE)
    
    if removed_count == 0:
        print("\nРазмерных объектов не найдено. Проверьте тип объектов в чертеже.")
        print("Запускаю диагностику — список всех типов объектов в файле...")
        
        doc = ezdxf.readfile(str(INPUT_FILE))
        types = {}
        for space in [doc.modelspace()] + list(doc.layouts):
            for e in space:
                t = e.dxftype()
                types[t] = types.get(t, 0) + 1
        
        print("\nТипы объектов в файле:")
        for t, cnt in sorted(types.items(), key=lambda x: -x[1]):
            print(f"  {t:30s} {cnt:>5} шт.")
