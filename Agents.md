# CorsixTH Modding Rules (Custom Rooms, Diseases & Staff)

## Scope & Architecture
- Target repository: CorsixTH (Lua gameplay layer in `CorsixTH/Lua/`, C++/SDL3 engine in `CorsixTH/Src/`).
- `CorsixTH/Lua/app.lua` auto-discovers files in `Lua/rooms/`, `Lua/diseases/`, and `Lua/objects/machines/`. Do not duplicate manual require calls if `loadLuaFolder` already loads the directory.
- Never edit or repack original 1997 Theme Hospital `.DAT`/`.TAB`/`.SAM` files. All gameplay logic, level availability overrides, and strings must live in CorsixTH source files.

## Mandatory Pre-Edit Inspection
Before writing or modifying any file, inspect the actual current codebase rather than assuming APIs:
1. Read `CorsixTH/Lua/app.lua`, `CorsixTH/Lua/base_config.lua`, and `CorsixTH/Lua/world.lua` to verify how rooms, machines, diseases, and `World:makeAvailableStaff(month)` are registered and initialized.
2. Read `CorsixTH/Lua/languages/english.lua` to match exact `_S` table nesting for room names, tooltips, disease descriptions, machine names, and staff bios.
3. Read an existing non-visual disease (e.g., `Lua/diseases/uncommon_cold.lua` or `Lua/diseases/sweaty_palms.lua`) and a single-machine clinic room + machine pair (e.g., `Lua/rooms/inflation.lua` and `Lua/objects/machines/inflator.lua`, or `slack_tongue.lua` + `slicer.lua`) to copy exact class registration and animation-hook conventions.

## Hard Technical Constraints
- **Non-visual diseases only (Phases 1–3):** Set `visuals_id = nil` (or omit it per current non-visual disease conventions) so patients use valid base humanoid sprites until entering the treatment room.
- **ID Collision Prevention:** Before assigning any numeric `level_config_id`, `thob`, or disease index, grep `CorsixTH/Lua/` and `CorsixTH/Lua/base_config.lua` to guarantee zero collisions with existing rooms, machines, or diseases.
- **Level 1 Availability Override:** Original campaign level files whitelist only vanilla rooms and diseases. Inject a clean Lua hook (e.g., during `World` / `Hospital` / `ResearchDepartment` level setup) so custom rooms are buildable and custom diseases can spawn on Level 1 (and subsequent levels) without modifying binary campaign maps.
- **Strict Globals & Persistence:** CorsixTH enforces strict global checks and Lua state serialization for save/load. Never leak undeclared globals, never store closures or unserializable userdata on Entity/Room/StaffProfile tables, and verify new classes register cleanly with CorsixTH's class system.
- **Placeholder Art First:** In Passes 1–3, reuse existing verified animation IDs and UI icons from vanilla clinic rooms/machines. Do not invent non-existent animation frame integers.

## Verification Gate (Required After Every Pass)
Run these commands from the repository root after every change and fix all errors/warnings before finishing:
1. `luacheck --quiet --codes --ranges CorsixTH`
2. `busted --directory=CorsixTH/Luatest`
3. If any file in `CorsixTH/Src/` was modified, rebuild via CMake and verify zero compiler errors.

In your final summary for each pass, list:
- Exact files created or modified.
- Exact IDs (`id`, `thob`, `level_config_id`) allocated.
- Test and linter output.
- A 3-step manual verification checklist for launching the game on Level 1.