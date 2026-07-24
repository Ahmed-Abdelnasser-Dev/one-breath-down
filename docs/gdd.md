# One Breath Down — Pearl Diver
### GMTK Game Jam 2026 — Theme: Countdown

**Engine:** Godot (C#) | **Team:** Solo | **Duration:** ~96 hours

---

## 1. Concept

A 2D side-view breath-holding dive game inspired by the Egyptian film *The Diver* and the Gulf's historical pearl-diving economy (the region's livelihood before oil). The player free-dives as deep as possible to collect increasingly valuable pearls, then must survive the swim back to the surface before their held breath — the countdown — runs out. Pearls banked on a successful surface can be spent between runs on equipment that lets the player dive deeper, faster, and safer on the next attempt.

**One-line pitch:** Dive deep, grab the pearls, and make it back before you run out of breath.

**Why it fits the theme:** the countdown isn't a UI timer bolted onto unrelated gameplay — it's the literal breath the character is holding. Every decision (how deep to go, how many pearls to grab, when to turn back) is made against that countdown, not alongside it.

---

## 2. Core Loop

1. **Dive** — player descends from the surface, oxygen/breath countdown starts immediately on submersion.
2. **Collect** — pearls of increasing rarity/value appear at increasing depth. Player chooses which to grab.
3. **Decide** — at any point, the player can turn back. The deeper/greedier they went, the longer and more dangerous the return trip.
4. **Ascend** — swim back up through the same hazard field, now more dangerous (low air, carrying cargo, hazards may have reacted to the outbound pass).
5. **Surface** — if reached before the countdown hits zero, all pearls carried are banked. If not (or if killed by a hazard), the run's pearls are lost.
6. **Shop** — between runs, spend banked pearls on equipment upgrades.
7. **Repeat** — dive again, deeper and better equipped.

---

## 3. Key Mechanics

### Breath / Countdown
- Starts the moment the player submerges.
- Depletes over time; depletion rate may increase with exertion (fast swimming) and decrease while gliding/resting.
- Visually and audibly prominent — the central "theme" element of the game (large on-screen counter, tightening vignette, rising heartbeat SFX as it nears zero).

### Depth & Pearl Value
- Value scales with depth. Rough draft curve:

| Pearl Type | Depth Band | Value | Special Trait |
|---|---|---|---|
| Seed pearl | Shallow (0-20m) | Low | Common, safe "sure thing" pickup |
| Rose pearl | Mid (20-50m) | Medium | Adds slight weight, minor speed penalty while carried |
| Black pearl | Deep (50m+) | High | Rare, often guarded (near hazards / tight spaces) |
| Golden pearl | Very deep, rare spawn | Very high | Requires upgraded gear to reasonably reach |

### Carrying Weight
- Each pearl carried adds a small cumulative penalty (swim speed and/or oxygen drain).
- Creates a running risk/reward tension: grab more vs. get back faster. This is the core "greed vs. countdown" decision point, repeated continuously through a run.

### Hazards (encountered both descending and ascending)

**Static / environmental (low build cost):**
- Mines — stationary, high punishment
- Coral / rock formations — pure navigation obstacles
- Fishing nets — tangle and cost time rather than kill outright (fits the "time is your health bar" theme)
- Currents — push the player off path, especially punishing on ascent

**Active / reactive (higher build cost, higher impact):**
- Jellyfish — slow, telegraphed drifting hazard, good for shallow zones
- Sharks — apex threat in deep zones; patrol or chase behavior
- Eels — ambush hazard, good for guarding black pearl pockets

**Stretch goal:** hazards encountered on the way down (e.g. a shark that noticed the player) become more active/aggressive on the way back up, making the ascent escalate rather than repeat.

### Depth Zones (visual/behavioral progression, low art cost)

| Zone | Depth | Look | Behavior |
|---|---|---|---|
| Sunlit | 0-50m | Bright blue-green | Gentle intro hazards, teaches controls |
| Twilight | 50-150m | Desaturating, closing vignette | Currents introduced, more hazard density |
| Midnight | 150m+ | Near-black, small light radius | Fastest oxygen drain, ambush hazards, hardest hazards |

### Equipment / Upgrades (spent between runs)

| Item | Effect |
|---|---|
| Bigger lungs | Increases base breath/countdown duration |
| Fins | Faster swim speed, less oxygen spent per meter |
| Knife | Escape nets instantly instead of losing time |
| Weighted belt (toggle) | Sink faster, harder to control ascent, risk-based item |
| Lantern | Visibility in deep zones, helps avoid ambush hazards |
| Bigger pearl bag / rope basket | Raises the weight threshold before speed penalty kicks in |

Keep shop small (5-6 items) for balance and scope sanity.

---

## 4. Fail States
- **Ran out of breath** before reaching the surface, run's pearls lost.
- **Killed by a hazard** (shark, mine, etc.), run's pearls lost.
- Both should feel like "the countdown won," reinforcing the theme even in failure.

---

## 5. Art & Audio Direction (to be developed)
- **Superseded:** the Gulf pearl-diving heritage framing below has been dropped in favor of a full
  mystical sunken-ruins direction (statues, broken columns, coral-reclaimed stonework). See
  `docs/visual-bible.md` for the current single source of truth on palette, composition, and
  effects rules — check there before making any new visual decision, not this section.
- ~~Cultural framing: Gulf pearl-diving heritage, rope-and-basket aesthetic, dhow boats at the surface, traditional pearl-diving song influence for ambient audio.~~
- Suggested style: simple flat/vector shapes or light pixel art, needs to be scoped against solo 4-day art budget. **Decided:** 16-bit pixel art, confirmed in `docs/visual-bible.md`.
- Key "juice" priorities: breath countdown tick/flash, heartbeat audio intensifying near zero, bubble trail particles, screen vignette tightening under low oxygen.

---

## 6. Open Questions / To Decide Next
- [ ] Exact oxygen depletion curve (base rate, exertion multiplier, per-pearl penalty)
- [ ] Exact depth-to-value curve for pearls, and spawn density per zone
- [ ] Whether ascent hazards are simply mirrored or reactively escalate (scope-dependent)
- [ ] Shop/hub scene presentation (between-run screen? boat deck?)
- [x] Final art style decision — 16-bit pixel art, mystical sunken-ruins direction; see `docs/visual-bible.md`
- [ ] Godot project architecture (autoloads, scene structure, obstacle/pearl base classes)
- [ ] Day-by-day build plan and cut list (what gets dropped first if behind schedule)

---

## 7. Scope Discipline Notes
- This is a solo, 96-hour build. The core loop (dive, collect, decide, ascend, bank/lose) must be fully playable end-to-end as early as possible (target: by end of Day 1/early Day 2), before adding content variety.
- Zones, pearl types, and hazard types are all "add more of the same pattern" content, safe to cut down in number if time runs short, without breaking the core loop.
- Shop/upgrade system is valuable but should be the first thing simplified or cut if the core loop and hazard tuning eat into build time, since a single tight dive-and-return experience is still a complete, submittable game without it.