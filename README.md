# Raise Brady Goo

A funny Roblox meme / tycoon-style game. You get a small house and a goofy baby
called **Brady Goo**, modelled (with his permission) on the real Brady Goo. Feed him, clean him, play with him and put him to bed to
earn **Goo Coins** and **Age XP**. As he ages from *Baby Brady* (1) to
*Legendary Brady Goo* (25) he changes body shape, hair, face, walk and idle
animations, unlocks clothing categories, moves into a bigger house and gifts
you wearable pieces for your own avatar. The long-term chase is fashion:
Common → Uncommon → Rare → Epic → Legendary → **Archive** → **Grail**.

![The ten stages](docs/preview-stages.png)

### Based on the real Brady Goo

Brady starts goofy (baby curl, bowl cut, gel spikes) and grows into the real
Brady's look: fair skin, a big chestnut curly mop and his signature dark
shades. His outfits from reference photos are in the game as pieces you
unlock along the way:

| Piece | How you get it |
| --- | --- |
| Clean White Low-Tops | age 3 reward |
| Plaid Flannel Overshirt | age 8 reward |
| Statement Belt | age 10 reward |
| Signature Dark Shades | age 13 reward |
| **The Malibu Fit**: grey crewneck, olive chinos, white low-tops, dark shades | age 16 reward |
| **The Varsity Fit**: vintage red crewneck, washed black jeans, chrome sneakers, belt, shades | age 21 reward |
| **The Flannel Fit**: plaid over a white tee, faded denim, striped high-tops, clear specs | shop, age 16 |
| Malibu Crewneck, Olive Chinos, Washed Black Jeans, Faded Grunge Denim, Striped Court High-Tops, Vintage Varsity Crewneck, Clear Frame Specs | shop, separately |
| Chrome Sneakers | crates (Legendary) |

His curls grow bigger every stage from age 8 (First Curls → Fluffy Curls →
Shades-On Curls → The Brady Flow → Archive Curls → Vintage Shag Curls →
Legendary Curls with gold tips). Three poses come from his photos: **Collar
Pop** (age 13), **Wall Lean** (age 16) and **The Brady**, hand behind the head
(age 18).

No real logos are copied: the crewneck texts are "MALIBU" and "GOO HIGH
HORNETS", the high-top stripe is goo green, and the belt buckle is plain.

> The preview images in `docs/` are drawn by a small offline renderer from the
> exact geometry the game builds (`tools/`). They are **not** Roblox
> screenshots: no lighting, materials, particles or text. They show shapes,
> proportions, colours and layout.

---

## Play it in 5 minutes

1. Download **`RaiseBradyGoo.rbxlx`** from this repository and open it in
   Roblox Studio.
2. **File → Publish to Roblox** (saving needs a published place).
3. **Game Settings → Security → Enable Studio Access to API Services** so
   progress saves while testing in Studio. Without it the game still runs, on
   temporary data, and prints a warning.
4. **Game Settings → Places → Max Players**: 12 or fewer is recommended (there
   are 12 house plots; more players get extra plots further down the street).
5. Press **Play**.

The Workspace looks almost empty in Edit mode. That is expected: the map,
houses and Bradys are built by the server the moment the game starts.

Developers who prefer a sync workflow can use [Rojo](https://rojo.space):
`rojo serve` and connect the Studio plugin, or
`rojo build default.project.json -o RaiseBradyGoo.rbxlx`.

---

## Read this first: what was and was not tested

This project was written without access to Roblox Studio. I could not press
Play. What I did instead:

* **`tests/`** contains a fake Roblox engine that runs under
  [Lune](https://lune-org.github.io/docs). It uses the *real* Roblox class and
  property database, so a wrong property name or type fails just like in
  Studio, and runs the game's actual scripts on a virtual clock.
* **69 automated scenarios pass**: every shared module, every clothing /
  furniture / gift / house recipe, a full server boot, joining, all care
  actions, all six mini-games, shop, crates (hundreds of rolls), ageing 1 → 25,
  rebirth, every random event, a complete fashion show with voting, daily
  rewards across a simulated week, hidden items, multiplayer visiting, saving /
  rejoining, session locks, DataStore outages, corrupt saves, exploit-style bad
  remote arguments, a two hour soak, the day/night cycle, roof fading, and all
  18 client scripts driven through
  their real buttons including ~400 random button presses.

That gives good confidence in the **logic**. It gives **no** confidence in
anything that needs a real client. Expect to tune these in Studio:

| Not verified | Why it matters |
| --- | --- |
| How it actually looks (lighting, materials, emoji icons, text fit) | The renderer in `tools/` only checks shapes |
| Animation feel | All animation is maths in `BradyAnimator`; angles were reasoned, not watched |
| UI on a real phone | Layout scales by formula; touch ergonomics are untested |
| Camera in mirror mode, prompt distances, map scale, obby difficulty | Need hands-on play |
| Physics | The fake engine has none: collisions, jumping and the obby route are unplayed |
| The built-in sound file names | They are standard Roblox client sounds, but a missing one just plays nothing |
| Real DataStore behaviour and network latency | Tested against a fake DataStore only |
| Game balance | Numbers are a reasoned first pass (see `Config.luau`) |

If something errors on first Play, the Output window will name the script and
line. The most likely first-run issues are visual, not logical.

---

## Graphics

Roblox does not allow custom shaders. These are the graphics levers it does
offer, and the game uses all of them:

| Feature | Where |
| --- | --- |
| **Future lighting** (real per-light shadows, specular highlights) and the **2022 PBR materials** | `default.project.json` (both can only be set in the place file) |
| Sky with sun, moon and stars; dynamic **clouds**; **atmosphere** haze and glare | `World/Environment` |
| Post-processing: bloom, sun rays, colour grade, gentle far depth-of-field | `World/Environment` |
| **Terrain**: animated grass blades, hills around the world, **Goo Beach** with an ocean, a real water pond, rock around the secret cave | `World/Environment` |
| **Day / night cycle** (15 min): golden hour at sunrise and sunset; at night street lamps, porch lights and string lights switch on, windows glow warm, fireflies come out | `Modules/TimeOfDay`, `LightingClient` |
| Materials everywhere: cobblestone plaza and paths, asphalt street with sidewalks, plaster, brick, roof shingles and clay tiles, carpet, ceramic tiles, leather, fabric clothing, rubber soles | builders |
| Detailed houses: pitched roofs (shingle or clay tile) or flat modern roofs, framed windows with sills and flower boxes, an open front door, porch light, plaster interiors with baseboards and crown moulding, chimneys, a paved walkway, hedged yards | `World/HouseBuilder` |
| Detailed map: round cartoon trees, palms, bushes, flower beds, slatted benches, street lamps, store front with display windows, mannequins and a striped awning, string lights over the food court, glowing cave crystals | `World/MapBuilder` |
| Brady: cartoon eyes (whites, irises, pupils, highlights), fabric / leather / rubber materials | `Builders/BradyBuilder` |
| UI: drop shadows behind windows, top-lit gradients and gloss on buttons and panels, rarity-tinted item cards | `Client/UI` |

**Settings → Low graphics** turns off depth of field, sun rays and clouds and
animates fewer Bradys. **Settings → Day & night** off keeps it a sunny
afternoon.

What I could **not** check, because I can't run Roblox: how all of this looks
in the real renderer, how much the grass decoration and Future lighting cost
on low-end phones (Roblox scales both down automatically on weak devices), and
whether the colour grade and night palette are to your taste. All of those
are a few numbers in `Modules/TimeOfDay.luau` and `World/Environment.luau`.
The previews in `docs/` show shapes, colours and layout only.

![House styles](docs/preview-house-styles.png)

---

## What is in the game

| System | Where | Notes |
| --- | --- | --- |
| 10 life stages, ages 1–25, XP curve | `Modules/AgeSystem` | each stage: proportions, hair, face, idle, walk, unlocks |
| 137 clothing items in 9 categories, 7 rarities | `Modules/ClothingSystem` | data-driven: add a row, no modelling |
| Brady model + every clothing piece built from parts | `Modules/Builders/BradyBuilder` | no meshes or image assets |
| Procedural animation: 7 idles, 8 walks, 17 poses, 13 actions | `Client/BradyAnimator` | no uploaded animation assets |
| Care: feed, shower, brush, shoes, sleep, toys, follow | `Services/CareServer` | four meters, mood changes XP |
| Mini-games: catch, target, reaction, soccer, dance, obby | `StarterGui/MinigameUI`, `Services/MinigameServer` | |
| Goo Coins, shop, 4 crates with visible odds | `Services/ShopServer`, `Modules/ShopSystem` | coins cannot be bought |
| House that grows every stage, 10 stations, grid furniture | `World/HouseBuilder`, `Services/HouseServer`, `StarterGui/RoomUI` | 37 furniture pieces |
| Mirror mode: poses, close camera, screenshot | `StarterGui/MirrorUI` | |
| 7 random events | `Services/EventServer` | |
| Fashion show: sign-up, runway, voting, titles, bots | `Services/FashionServer` | works with one player |
| Collection book, 29 achievements, daily reward + tasks | `Services/CollectionServer`, `DailyServer`, `AchievementServer` | |
| 24 hidden goo blobs, 6 secret items, secret cave | `Services/CollectionServer`, `World/MapBuilder` | |
| Gifts for the player's own avatar | `Modules/GiftSystem`, `Services/GiftServer` | |
| Rebirth | `Services/AgeServer` | permanent +25% per rebirth |
| Multiplayer: visit, inspect, hype | `Services/SocialServer` | read-only: no trading, no stealing |
| Saving with session locks | `Services/DataServer`, `Modules/DataManager` | |
| Tutorial | `StarterGui/TutorialUI` | |

![Outfits](docs/preview-outfits.png)

---

## Project layout

```
default.project.json           Rojo project
RaiseBradyGoo.rbxlx            ready-to-open place file (built from src/)
src/
  ReplicatedStorage/
    Modules/                   shared data + rules (AgeSystem, ClothingSystem,
      Builders/                InventorySystem, CurrencySystem, DataManager,
                               EventSystem, FashionSystem, CollectionSystem ...)
    Client/                    ClientState, UI kit, BradyAnimator, Preview
  ServerScriptService/
    Main.server.luau           the only Script: boots everything in order
    Services/                  DataServer, AgeServer, CurrencyServer,
                               ClothingServer, EventServer, FashionServer ...
    World/                     MapBuilder, HouseBuilder
  StarterGui/                  MainUI, AgeUI, InventoryUI, WardrobeUI, ShopUI,
                               CollectionUI, RoomUI, FashionUI, BradyUI ...
  StarterPlayer/StarterPlayerScripts/   BradyClient, WorldClient
tests/                         fake engine + test suite (developer tool)
tools/                         preview renderer (developer tool)
```

### Where this differs from the structure you suggested, and why

* **Server systems are ModuleScripts loaded by one `Main` Script**, not
  separate Scripts. Separate Scripts all start at once with no guaranteed
  order, which causes "X is not ready yet" bugs. One entry point decides the
  order. The names you asked for (`DataServer`, `AgeServer`, `CurrencyServer`,
  `ClothingServer`, `EventServer`, `FashionServer`) are all there.
* **`DataManager` in ReplicatedStorage is only the save-data schema.** The code
  that talks to DataStores is `Services/DataServer`, which clients cannot
  reach. DataStore code in ReplicatedStorage would be readable by exploiters.
* **The map and houses are built by code at server start** instead of being
  hand-placed. That keeps the project plain text and keeps gameplay positions
  in sync with scenery. The trade-off: you cannot drag things around in Edit
  mode. `World/MapBuilder.luau` explains how to switch to a hand-edited map.

---

## Security model

The client is never trusted with anything that matters.

* Coins, XP, items, furniture, daily rewards and titles only change on the
  server. The client's copy (`ClientState`) is display-only.
* Every remote validates its arguments and is rate limited (`Services/Net`).
* One-time rewards write their "claimed" flag **before** paying out.
* Mini-game scores are the one thing the client reports. The server issues a
  one-use token, charges energy up front, clamps the score, rejects rounds
  that finish impossibly fast and applies a cooldown. A cheater can at best
  earn the same as a perfect player, limited by energy.
* Saves use `UpdateAsync` with a session lock, are repaired by
  `DataManager.reconcile` on load, and a failed load kicks the player instead
  of handing out a blank profile that would overwrite the real one.

---

## Things you need to fill in

| What | Where | Default |
| --- | --- | --- |
| Gamepass IDs | `Modules/Monetization.luau` | all `0` = nothing for sale |
| Background music | `Modules/Sounds.luau` → `Sounds.Music` | none |
| Your own sound effects | `Modules/Sounds.luau` | built-in Roblox client sounds |
| Balance | `Modules/Config.luau`, `AgeSystem.xpToNext` | first pass |

Monetization is optional and cosmetic / convenience only. There is no way to
buy Goo Coins, XP or clothing with Robux, so crates are never a paid random
item. Their odds are shown in the shop anyway.

---

## Known limitations

* The mirror is a camera close-up, not a real reflection (Roblox has no
  real-time mirrors).
* Brady walks in straight lines without pathfinding and can clip through
  furniture.
* Faces and shirt graphics are SurfaceGuis, which ViewportFrames cannot draw,
  so the wardrobe preview uses a simplified face.
* The session lock is a compact implementation. For a large live game,
  consider a battle-tested library such as ProfileStore.
* Screenshots use `CaptureService`, which is not available on every platform;
  the game falls back to a message.
* Rebirth shrinks the house again, so some furniture returns to storage.

---

## Running the tests

```
cargo install rojo lune          # once
rojo build default.project.json -o build/test.rbxl
lune run tests/run.luau          # about 4 minutes
```

Preview images:

```
lune run tools/export_scenes.luau && python3 tools/render_scenes.py
```
