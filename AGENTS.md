# Spiritwright project guidance

Spiritwright is a 2D, browser-playable Godot game: a PvE, collection-focused auto-battler in which persistent spirits inhabit modular golem vessels. Work only inside this project unless the user explicitly broadens the task. Preserve any user changes.

Read before working:

- `Spiritwright_Game_Design.md`: the game design document. Respect its pillars; it is the source of truth for intent.
- `README.md`: how to run, check and publish, and the prototype decisions taken for the GDD's open questions.

## Verification and checks

- The only automated checks live in `tools/sim_checks.gd`, a headless runner for the data, growth, progression and simulation (`--headless --path . --script res://tools/sim_checks.gd`). It prints PASS/FAIL and exits non-zero on failure. Add a check when a simulation or progression rule lands. Do not create a `tests/` directory or other test frameworks. Keep `tools/` out of the exported game.
- `-- --report` on the same command prints a balance report: the win rate of random legal builds for each stage in campaign order. Use it when retuning data.
- `tools/capture.gd` drives the real game through every screen and saves PNGs (needs a window, not `--headless`). Verify anything visual by running the game or capturing and looking at it. Say plainly what was and was not checked.
- Run the checks and a parse/import check (`--headless --editor --quit`) before every commit that touches scripts or data.

## Product invariants

- The spirit is the character; the body is replaceable. Any spirit may use any unlocked frame, arms, legs and sigil. Temperament preferences only ever add bonuses; never lock out or penalise a build.
- Element is identity, not class. Do not tie an element to a combat role.
- The rules engine decides battles. `scripts/sim/battle_sim.gd` is deterministic: the same teams and seed give the same event log. It never touches the scene tree, `Time`, `OS` or the global `randi()`/`randf()`; all randomness comes from its own `rng`.
- The battle view only replays the event log. It never changes the outcome.
- No mid-battle player control. Preparation is the gameplay; playback speed, pause and skip are the only battle controls.
- Every outcome must be explainable: each meaningful sim step writes an event with readable text, and the result screen shows what each golem did.
- Defeat never destroys spirits or progress; it still awards XP.
- Keep the part, sigil, trait and status catalogs bounded to implemented effects. Do not add entries whose effects the simulation does not support.

## Engineering

- Godot **4.2.2** GDScript with the **Compatibility** renderer (required for the Web export). Do not install or upgrade tools without approval.
- Exports and headless tooling use the standard (non-mono) editor at `..\small_following\exports\tooling\Godot_v4.2.2-stable_win64_console.exe`, or `GODOT_EXE`.
- Base resolution 1280x720 with `canvas_items` stretch and `expand` aspect. Layouts must work with mouse and touch; do not rely on hover alone for anything essential.
- UI text is ASCII only: the web build's default font lacks arrows, bullets and similar glyphs.
- Static typing where practical; load dependencies with `const X = preload("res://...")`. Tabs, LF, UTF-8 (`.editorconfig`). Keep scripts under ~400 lines; split by responsibility before they grow past that.
- Data lives in `data/` (`spirits.json`, `parts.json`, `campaign.json`, `balance.json`) with stable ids and `schema_version`, validated at startup by `scripts/core/catalog.gd`. Missing or mistyped data fails fast; no silent defaults in code.
- Combat effects are data-driven (`{"on": "hit", "do": "status", ...}`) rather than bespoke code per spirit.
- `scripts/core/progression.gd` is the single owner of persistent state and validates every change. Saves go to `user://spiritwright_save.json` with schema validation, staged writes and a backup.
- Do not overwrite original art.

## Commits

Commit after every complete, working step. Message style: one present-tense line describing what changed as it is felt in the game, then a short plain tag in parentheses, e.g. `Neris raises a ward whenever she is struck (spirit trait)`.

## Publishing

Publishing (`publish.ps1`, `publish-itch.ps1`) requires separate authorisation. `.\publish.ps1 -BuildOnly` (export only, no deploy) is fine for verification.
