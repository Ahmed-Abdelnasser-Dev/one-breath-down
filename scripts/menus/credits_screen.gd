extends Control
## Reads CREDITS.md at runtime so the in-game credits can't drift out of
## sync with the repo's single source of truth.

signal closed

const CREDITS_PATH := "res://CREDITS.md"

@onready var credits_label: RichTextLabel = $Panel/Margin/VBox/Scroll/CreditsLabel
@onready var back_button: Button = $Panel/Margin/VBox/BackButton


func _ready() -> void:
	credits_label.text = _load_credits_text()
	back_button.pressed.connect(func() -> void: closed.emit())


func focus_default() -> void:
	back_button.grab_focus()


func _load_credits_text() -> String:
	if not FileAccess.file_exists(CREDITS_PATH):
		return "Missing CREDITS.md"
	var file := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	var raw := file.get_as_text()
	file.close()
	return _markdown_to_bbcode(raw)


## Light markdown -> bbcode pass: just enough to make CREDITS.md readable in
## a RichTextLabel without pulling in a full markdown parser.
func _markdown_to_bbcode(raw: String) -> String:
	var out: PackedStringArray = []
	for line in raw.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("> "):
			continue   # skip the maintainer note; not for players
		elif trimmed.begins_with("## "):
			out.append("[b]" + trimmed.substr(3) + "[/b]")
		elif trimmed.begins_with("# "):
			continue   # title already shown by this screen's own header
		elif trimmed.begins_with("- "):
			out.append("  • " + trimmed.substr(2))
		elif trimmed != "":
			out.append(trimmed)
	return "\n".join(out)
