# Bladebound · Spirit Trials

An original anime sword simulator built from your three uploaded scripts. The fourth script, `WorldBuilder`, constructs a complete playable map on the server. No uploaded animation IDs, marketplace models, paid assets, plugins, or HTTP API keys are required.

The UI uses simulator-style currency cards, colorful navigation tiles, sword previews, progression panels and large touch controls, with its own Bladebound identity. The linked Anime Eyes experience could not be inspected here; this is an original interpretation of the requested progression and UI structure, not a verified recreation of its interface.

## Open the complete game

1. Open `dist/Bladebound.rbxlx` in Roblox Studio with **File → Open from File**.
2. Press **Play** (F5), rather than Run. The map is generated when the server starts; the edit-time workspace initially looks empty.
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

Keep these names exact. The server generates the `AnimeSwordWorld` folder and its own encounter folder, plus the `GameAction` and `GameSync` RemoteEvents. Existing unrelated map objects are preserved; remove an old baseplate or map manually if it overlaps this map. The lobby spans X ±71 / Z ±80, and rooms extend down negative Z to approximately −2,504 studs. Floors sit at Y=0. Streaming is enabled in the bundled place for this long map.

## What changed

- **Actual swings:** three procedural combos move the shoulders, torso, and R15 elbow/wrist, with a windup, strike, recovery and timed blade trails. Both R6 and R15 are supported. Other clients play server-confirmed swings. No asset ownership or animation upload step is needed.
- **14 distinct weapon profiles:** curved katana, leaf split-tip, serrated fang, crystal rapier, zigzag lightning blade, shadow twin edge, sun cleaver, blossom katana, crescent reaper, double-ended dragon glaive, open-center seraph blade, phoenix feathers, executioner slab and floating astral segments. Sword shop cards show actual 3D previews.
- **15 connected realms:** dojo, bamboo forest, village, frozen peak, storm plains, crimson temple, shadow valley, sunken ruins, sky citadel, lava caverns, spirit realm, dragon nest, void rift, celestial gate and sword throne. Bridges, torii, lanterns, shrines, trees, monuments, guardian seals and return sigils form a full route.
- **Room progression:** each player has a personal enemy sequence and health bars. Only server-confirmed nearby hits damage it. Minions award Spirit; the boss chest and trophy reward grow with each room. Cleared rooms remain unlocked and can be replayed deliberately. Enemy damage, deaths, run cancellation and respawns are handled.
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

All four scripts compile using the official Luau 0.699 compiler. The data suite passes 549 assertions; the construction suite passes 6,269 assertions and builds 2,119 static map parts including the sword displays; the persistence regression suite passes 20 assertions (6,838 total). `tests/check_data.py` executes actual SwordData progression logic with minimal data constructors; it checks increasing rewards, unique designs, training unlocks, mastery requirements and pet pools. Geometry tests use a limited Roblox stub to check world contracts, dimensions, route and prompt placement. Persistence tests execute the actual save/load functions against store doubles to check malformed data, lease ownership, retry recovery and failed-read protection. These checks do not establish actual Roblox rendering, physics, networking, or live DataStore behavior.

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
python3 tools/package.py
```

The current environment has official Luau 0.699 built outside the repository at `/workspace/tools/luau` (commit `994b6416f1a2d16ac06c52b4e574bad5d8749053`). On another machine, obtain the official Luau CLI to run these optional development checks. Packaging needs only Python 3. `tools/package.py` creates the Studio XML place and ZIP, verifies that all four embedded sources match the originals, and checks ZIP integrity. The bundle is a local build artifact; it has not been uploaded or published to Roblox.
