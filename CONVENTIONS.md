# Engineering Conventions: Инженер ПТО (Piping & AutoCAD Automation)

## Project Overview
This repository contains the complete engineering and automation knowledge base for a Production Technical Department (ПТО) Engineer in the Russian Federation.
Disciplines: ТХ, ВК, ВС, ОВ, ТК, ТМ, ТС.

## Key Operating Directives
- **AutoCAD Automation**: CLI automation is handled via `accoreconsole.exe`. Always stage DWG files to `C:\Temp\input.dwg` because paths containing Cyrillic characters break the CLI parser.
- **AutoLISP Execution**: `accoreconsole` prevents `(load ...)` calls under default security. Scripts must provide inline AutoLISP code directly inside `.scr` script files.
- **Script Exits**: When terminating AutoCAD CLI, always issue `_.QUIT` followed by `_Y`.
- **Target Cleanup**: Before any `_.SAVEAS` call, clean up the destination file in `C:\Temp\` to avoid interactive overwrite confirmation prompts that cause console deadlock.
- **Table Editing**: `ACAD_TABLE` entities cannot be managed through COM in `accoreconsole`. Modify tables via the DXF text replacement pipeline (`scripts/update_acad_tables.ps1`).
- **Encodings**:
  - DXF files: UTF-8 without BOM (`[System.Text.UTF8Encoding]::new($false)`).
  - CLI Output: UTF-16 with null byte stripping (`$_ -replace [char]0,''`).
- **Font Normalization**: Convert missing `CS_Gost2304.shx` and `Russia-GOST_Topo.shx` styles to standard `isocpeur.ttf` (`ISOCPEUR`).
- **Wording Standard**:
  - Row 1: `Итого: монтаж трубопровода+фасонные изделия`
  - Row 2: `Итого: Общая протяженность участка линии`
