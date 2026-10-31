# Bladebound · Spirit Trials

An original anime sword simulator built from your three uploaded scripts. The fourth script, `WorldBuilder`, constructs and loads a complete playable map. The bundled Studio place now includes the full map as editable geometry before Play. No uploaded animation IDs, marketplace models, paid assets, plugins, or HTTP API keys are required.

The UI uses simulator-style currency cards, colorful navigation tiles, sword previews, progression panels and large touch controls, with its own Bladebound identity. The linked Anime Eyes experience could not be inspected here; this is an original interpretation of the requested progression and UI structure, not a verified recreation of its interface.

## Open the complete game

1. Download and extract **`dist/Bladebound-Studio.zip`**. It contains `Bladebound.rbxlx` directly, avoiding browsers displaying XML text. Open that place in Roblox Studio with **File → Open from File**. The full source bundle also contains the place at `dist/Bladebound.rbxlx`.
2. Inspect the map immediately in Explorer → Workspace → AnimeSwordWorld. Press **Play** (F5), rather than Run, to start combat and progression. The server reuses the baked map so ordinary Studio geometry edits survive Play.
3. Swing with the equipped sword, the blue **SWING** button, or gamepad R2. **AUTO** optionally repeats ordinary swings at the normal cooldown. It does not move or clear rooms for you.
4. Walk toward the main gate into Room 1. Approach and face each opponent to hit it; avoid red enemy attack telegraphs. Five guardians lead to a boss. A boss clear grants trophies and a Spirit chest, heals you, and unlocks the next connected room. Use **Rooms** to travel to any unlocked room or replay it.
5. In the hub, stand on a training mat and use its proximity prompt (E, gamepad X, or the touch prompt), then swing. Training ends when you leave its range. Higher tiers require earned trophies.

To install in an existing place instead, replace the old scripts—do not leave duplicate GameServer or GameClient scripts enabled:

| File | Studio object | Location |
| --- | --- | --- |
| `SwordData.lua` | ModuleScript named `SwordData` | ReplicatedStorage |
| `WorldBuilder.lua` | ModuleScript named `WorldBuilder` | ServerScriptService |
| `GameServer.lua` | Script named `GameServer` | ServerScriptService |
| `GameClient.lua` | LocalScript named `GameClient` | StarterPlayer → StarterPlayerScripts |

Keep these names exact. The server generates the `AnimeSwordWorld` folder and its own encounter folder, plus the `GameAction` and `GameSync` RemoteEvents. Existing unrelated map objects are preserved; remove an old baseplate or map manually if it overlaps this map. The compact main lobby spans X ±120 / Z −80 to +128, with layered cliff scenery beyond those edges, and rooms extend down negative Z to approximately −2,504 studs. Floors sit at Y=0. Streaming is enabled in the bundled place for this long map.

## What changed

- **Actual swings:** three procedural combos move the shoulders, torso, and R15 elbow/wrist, with a windup, strike, recovery and timed blade trails. Both R6 and R15 are supported. Other clients play server-confirmed swings. No asset ownership or animation upload step is needed.
- **14 distinct weapon profiles:** curved katana, leaf split-tip, serrated fang, crystal rapier, zigzag lightning blade, shadow twin edge, sun cleaver, blossom katana, crescent reaper, double-ended dragon glaive, open-center seraph blade, phoenix feathers, executioner slab and floating astral segments. Sword shop cards show actual 3D previews.
- **15 connected realms:** dojo, bamboo forest, village, frozen peak, storm plains, crimson temple, shadow valley, sunken ruins, sky citadel, lava caverns, spirit realm, dragon nest, void rift, celestial gate and sword throne. Bridges, torii, lanterns, shrines, trees, monuments, guardian seals and return sigils form a full route.
- **Room progression:** each player has a personal enemy sequence and health bars. Only server-confirmed nearby hits damage it. Minions award Spirit; the boss chest and trophy reward grow with each room. Cleared rooms remain unlocked and can be replayed deliberately. Enemy damage, deaths, run cancellation and respawns are handled.
- **Bright, original festival hub:** a broad lavender promenade, four fenced training pens, a four-tier sword amphitheatre, two egg pavilions, an aura garden, Sakura trees, lantern garlands and a monumental dragon-flanked sky-sword gate. Physical sword prompts buy/equip the displayed weapon; egg prompts hatch the displayed egg using existing server checks.
- **Lighting:** sunny early-afternoon daylight, stronger ambient fill, thin blue atmosphere, warm saturation, subtle bloom and restrained sun rays. No blur or depth-of-field obscures gameplay.
- **Modeled training court:** bamboo dummy, engraved stone, suspended storm core and solar ascension shrine. Each station has a visible tier/requirement sign, a training platform and a proximity interaction.
- **Persistent mastery:** normal swings give 1 XP; station swings give 2/4/8/16 XP. Each mastery level raises the global sword multiplier by 8%, up to level 100. This carries across sword equips and rebirths. Training also increases Spirit per swing by 1.5×/3×/8×/20× while in range; it never multiplies combat damage directly.
- **Original responsive HUD:** landscape and portrait layouts, currency cards, seven menus, room rewards, boss health, mastery XP, training status, autoswing, codes, visible save warnings and a two-click rebirth confirmation. Pets, auras, group bonus, offline earnings and existing codes are retained.

## Progression tuning

`SwordData.lua` contains all balance values and weapon geometry. The server computes rewards from these definitions; clients cannot supply currency, damage or unlock values.

- Room chest Spirit: `floor(200 × 2.5^(room − 1))`.
- Room trophies: `floor(5 × 1.65^(room − 1))`.
- Each minion additionally drops 8% of that room's Spirit chest.
- Enemy health: `floor(30 × 1.9^(room − 1))`; bosses have 6× the unrounded base health.
- Mastery XP to next level: `floor(35 × 1.18^level)`.
- Base gain/damage multiplier: sword × mastery × best-three-pet bonus × aura × rebirth × trophy bonus × optional group bonus.
- Spirit per swing: `floor(base multiplier × active training multiplier)`, minimum 1.
- Damage: `floor(base multiplier × 4)`, with a 1.35× third-combo finisher. Only an enemy in front and within melee range is hit.

| Training model | Trophies required | Spirit per swing | Mastery XP per swing |
| --- | ---: | ---: | ---: |
| Bamboo Fundamentals | 0 | 1.5× | 2 |
| Stone Resolve | 25 | 3× | 4 |
| Storm Meditation | 250 | 8× | 8 |
| Solar Ascension | 2,000 | 20× | 16 |

## Saving

The original `AnimeSwordSim_v1` DataStore and `p_<UserId>` keys are retained. Existing fields are validated and new mastery fields default safely. Use a separate test experience when checking live saves: Studio API access can otherwise touch your production experience's saved data.

For persistence testing, publish your test place and enable **Game Settings → Security → Enable Studio Access to API Services**. No secret belongs in these scripts. Without API access, the game still runs as a clearly labeled practice session and does not overwrite unreadable saves.

Saves use an atomic session lease, 60-second autosaves, departure/shutdown saving, and protection against overwriting another server's session. After a crashed server, the old lease may take up to three minutes to expire. Rejoin after that time if the UI reports a practice session because another server owns the save. Saves that fail remain visibly flagged; do not assume unsaved practice progress will persist.

## Validation and remaining playtest

All four scripts compile using the official Luau 0.699 compiler. The data suite tests progression invariants, while the expanded construction suite executes the actual sword and map builders with full rigid-transform doubles. It checks dimensions, sword/egg/training interactions, supported walking paths, stair rises, ordered encounters, baked-world reuse and lighting configuration. Persistence tests exercise the actual save/load functions against store doubles.

The Studio package contains actual baked geometry, interaction metadata and named lighting effects. Its property types and enum values are checked against a cached Roblox API schema; all instance references and embedded sources are checked on each build. These checks do not establish actual Roblox rendering, physics, networking, or live DataStore behavior.

`tools/render_map.py` creates an optional isometric preview from the exported geometry. It is explicitly a geometry preview, not a Roblox Studio screenshot: engine lighting, particles and text may differ. Preview-only development dependencies are NumPy and Pillow; neither is needed to play.

This cloud machine cannot run Roblox Studio. Before publishing to players, playtest:

1. R6 and R15 swings, first-person/third-person camera, touch and gamepad controls, and both screen orientations.
2. First-room completion, increasing trophy/chest rewards, locked-room enforcement, training in/out of range and mastery level-ups.
3. Two Studio clients: separate enemy ownership, observed swing animations and independent progression.
4. Save/rejoin, failed-save warning, offline rewards, rebirth confirmation, pets, auras and code redemption in a separate published test experience.
5. Low-end device frame rate and streaming across all rooms. Geometry is intentionally primitive-based; tune detail and lighting after device testing.

Development commands (run from this checkout; use the existing checkout, no worktree needed):

```sh
# Luau tools are external development tools, not game dependencies.
python3 tests/check_data.py /workspace/tools/luau/luau
python3 tests/check_world.py /workspace/tools/luau/luau
python3 tests/check_server.py /workspace/tools/luau/luau
# Compile each .lua with /workspace/tools/luau/luau-compile (redirect bytecode output).
python3 tools/package.py --luau /workspace/tools/luau/luau
python3 tests/check_package.py
# Optional geometry preview, then repackage to include it:
python3 tools/render_map.py
python3 tools/package.py --luau /workspace/tools/luau/luau
```

The current environment has official Luau 0.699 built outside the repository at `/workspace/tools/luau` (commit `994b6416f1a2d16ac06c52b4e574bad5d8749053`). On another machine, obtain the official Luau CLI to run these optional development checks. Baking the map needs Python 3 and the Luau CLI. A minimal property schema is saved in `tools/roblox_schema.json`, so rebuilding needs no Roblox API credentials or API network calls. `tools/package.py` creates the Studio XML place and ZIP, verifies that all four embedded sources match the originals, and checks ZIP integrity. Download bundles are distributed on the `codex/bladebound-download` branch of the connected GitHub repository. They have not been published to Roblox.


## Editing the baked map

The place includes `AnimeSwordWorld` with `BakedWorldVersion` set to `3`. `WorldBuilder.load` reconstructs gameplay references from the saved room/training attributes and hidden encounter markers. You can move/resize/color decorative parts in Studio normally; save or publish your place after editing. Keep the metadata-bearing room models, prompt anchors and encounter markers intact. If you move an arena or station, update its stored center/spawn attributes and markers as well; room progression currently expects the documented negative-Z route. If metadata is invalid or from another version, the server preserves that folder under `ServerStorage → BladeboundWorldBackups` and builds a valid replacement, with an Output warning. Standalone script installation still generates the map on the first Play.


## Compact courtyard revision

The hub footprint is reduced by 36%, with a 17.6-stud main promenade, linked garden courts, overhead district gateways, privacy screens, Sakura rest areas and a moon tea garden. The spawn is now `(0, 3.2, 100)` and training centers are `(±35.2, 0, 64)` and `(±35.2, 0, 20)`, with 9.6-stud training radii. Geometry, interaction anchors and saved metadata scale together, while the combat rooms retain their original coordinates. Every room now has planted encounter borders with side openings. Download the revised full place to see the new baked map; replacing just the script preserves/backups older baked geometry and creates the new layout on Play.
