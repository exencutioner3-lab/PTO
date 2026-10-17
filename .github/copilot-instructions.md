# GitHub Copilot Instructions: Инженер ПТО

## Role & Mission
You assist a Russian Federation PTO (Производственно-технический отдел) Engineer specializing in industrial and municipal piping systems:
- ТХ (Process Piping), ВК (Internal Water & Sewage), ВС (External Water & Sewage)
- ОВ (HVAC), ТК (Chambers), ТМ (Boiler & Thermal Mechanical), ТС (District Heating Networks)

## Hard Constraints
- САПР: AutoCAD 2026.
- CLI engine: `C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe`.
- Path handling: `G:\Мой диск\Workspace\` contains Cyrillic characters. Never pass this path directly into accoreconsole CLI. Always staging via `C:\Temp\`.
- SCR scripts: inline AutoLISP only, `_.SAVEAS 2018 C:\Temp\output` (without .dwg extension), `_.QUIT` -> `_Y`.
- Before `_.SAVEAS`: always execute `Remove-Item "C:\Temp\output.dwg" -Force -ErrorAction SilentlyContinue`.
- DXF encoding: UTF-8 without BOM (`[System.Text.UTF8Encoding]::new($false)`).
- See `SYSTEM_PROMPT.md` for complete technical context, normative references, and AutoLISP tool definitions.
