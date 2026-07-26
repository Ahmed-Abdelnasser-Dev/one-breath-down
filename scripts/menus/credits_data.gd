extends RefCounted
class_name CreditsData
## Parser for CREDITS.md, which is the single source of truth for attribution.
## Includes an embedded fallback so credits always render in export builds.

const PATH := "res://CREDITS.md"

enum Kind { SECTION, SUB, ENTRY, PARA }

const FALLBACK_CREDITS := """## Made By

- Design, code, world building, audio and art integration | FakeMC (Ahmed Abdelnasser)

### Find FakeMC

- GitHub | Ahmed-Abdelnasser-Dev | https://github.com/Ahmed-Abdelnasser-Dev
- YouTube | @ItsFakeMC | https://www.youtube.com/@ItsFakeMC
- TikTok | @itsfakemc | https://tiktok.com/@itsfakemc
- Instagram | @itsfakemc | https://instagram.com/itsfakemc
- Linktree | every link in one place | https://linktr.ee/ahmedabdelnasser.dev

## Art

### Backgrounds and Environment

- Warped Ocean View | ansimuz | https://ansimuz.itch.io/warped-ocean-view
- Underwater Fantasy Pixel Art Environment | ansimuz | https://ansimuz.itch.io/underwater-fantasy-pixel-art-environment | CC BY 4.0
- Underwater Fantasy Addon | ansimuz | https://ansimuz.itch.io/underwater-fantasy-addon
- Pixel Art Ocean Parallax Background | AshenThrone | https://ashenthrone.itch.io/pixel-art-ocean-parallax-background

### Diver and Swimmers

- Underwater Diving | ansimuz | https://ansimuz.itch.io/underwater-diving | CC0 1.0
- Free Swimming Characters Animation | Free Game Assets | https://free-game-assets.itch.io/free-swimming-characters-animation-pixel-art

### Creatures

- Octopus, Jellyfish, Shark and Turtle Pixel Art | Free Game Assets | https://free-game-assets.itch.io/octopus-jellyfish-shark-and-turtle-free-sprite-pixel-art
- Free Shark Enemy Pack | MutterPixel Studio | https://mutterpixel-studio.itch.io/free-shark-enemy-pack-animated-pixel-art
- Deep-sea Creatures | PixelCampGames | https://pixelcampgames.itch.io/deep-sea-creatures | CC BY-SA 4.0, credit required
- Bird Sprites with Animations | carysaurus | https://carysaurus.itch.io/bird-sprites | credit required

### Surface, Fishing and Boats

- Free Fishing Pixel Art Pack | Free Game Assets | https://free-game-assets.itch.io/free-fishing-pixel-art-pack
- Fishing Icon Pack 16x16 | Hollow Dolphin | https://hollowdolphin.itch.io/fishing-icon-pack
- Free Fishing Boats Pack | MutterPixel Studio | https://mutterpixel-studio.itch.io/free-fishing-boats-pack-animated-pixel-art-assets

### UI and Icons

- 8000+ Raven Fantasy Icons | Clockwork Raven | https://clockworkraven.itch.io/raven-fantasy-icons | pearl, money and weight icons
- Hydration UI Pixel Pack | Ghost Sector Studios, art by Ascendancy Arcade | https://ghostsectorstudiosllc.itch.io/hydration-ui-pixel-pack | breath meter
- Free Inventory for Farming RPG | ELV Games | https://elvgames.itch.io/free-inventory-for-rpg-or-farming-games
- Woods Journey UI Asset Pack | Lost Soup | https://lost-soup.itch.io/woods-journey-ui-asset-pack | menu buttons and panels, credit required

### Effects

- Slash FX | jasontomlee | https://jasontomlee.itch.io/slashfx | CC BY 4.0, credit required
- Pixel Art Animated Water VFX | SoggySocks | https://soggysocksstudio.itch.io/pixel-art-animated-water-vfx
- Visual Effects v01 | ApyrYoun | | slashes, impacts, smoke

## Audio

### Music

- Ocean Music | JHawk | https://jhawk-studios.itch.io/ocean-music-free-music | CC BY 4.0, credit required as "JHawk"

### Sound Effects

- Pixel Game Essentials SFX Pack | JDSherbert | https://jdsherbert.itch.io/pixel-game-essentials-sfx-pack
- Underwater set (bubbles, heartbeat, ambience) | FakeMC | | generated for this game

## Type and Engine

- Pixellari | Zacchary Dempsey-Plante | https://www.dafont.com/pixellari.font
- Godot Engine 4 | Juan Linietsky, Ariel Manzur and contributors | https://godotengine.org | MIT

## Made For

- GMTK Game Jam 2026 | Theme: Countdown | https://itch.io/jam/gmtk-2026
"""


## Parsed blocks in file order. Each is a Dictionary with a "kind" key:
##   SECTION / SUB / PARA -> "text"
##   ENTRY                -> "name", "author", "url", "note" (all but name may be "")
static func blocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var in_comment := false
	for raw_line in _read().split("\n"):
		var line := raw_line.strip_edges()

		if in_comment:
			if line.contains("-->"):
				in_comment = false
			continue
		if line.begins_with("<!--"):
			in_comment = not line.contains("-->")
			continue

		if line.is_empty():
			continue
		elif line.begins_with("### "):
			out.append({"kind": Kind.SUB, "text": line.substr(4)})
		elif line.begins_with("## "):
			out.append({"kind": Kind.SECTION, "text": line.substr(3)})
		elif line.begins_with("# "):
			continue   # the document title; each screen prints its own header
		elif line.begins_with("- "):
			out.append(_parse_entry(line.substr(2)))
		else:
			out.append({"kind": Kind.PARA, "text": line})
	return out


## Every entry that carries a url, in file order.
static func links_in(heading: String) -> Array[Dictionary]:
	var wanted := heading.to_lower()
	var collecting := false
	var out: Array[Dictionary] = []
	for block in blocks():
		var kind := int(block["kind"])
		if kind == Kind.SECTION or kind == Kind.SUB:
			if collecting and kind == Kind.SECTION:
				break
			collecting = String(block["text"]).to_lower() == wanted
		elif kind == Kind.ENTRY and collecting and not String(block["url"]).is_empty():
			out.append(block)
	return out


static func _parse_entry(body: String) -> Dictionary:
	var fields := body.split("|")
	var get_field := func(i: int) -> String:
		return fields[i].strip_edges() if i < fields.size() else ""
	return {
		"kind": Kind.ENTRY,
		"name": get_field.call(0),
		"author": get_field.call(1),
		"url": get_field.call(2),
		"note": get_field.call(3),
	}


static func _read() -> String:
	if FileAccess.file_exists(PATH):
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var raw := file.get_as_text()
			file.close()
			if not raw.is_empty():
				return raw
	return FALLBACK_CREDITS
