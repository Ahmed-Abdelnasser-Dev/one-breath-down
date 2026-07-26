extends Control
## Credits. Renders CREDITS.md through CreditsData so the screen can never drift
## out of sync with the repo's single source of truth.
##
## Every attribution link is a real hyperlink: highlighted, underlined, and it
## opens the player's browser on click. Hovering one shows its destination in the
## footer, so nobody has to click blind.

signal closed

const COL_SECTION := "#ffd66b"    ## gold, matches the menu titles
const COL_SUB := "#6fd3e2"        ## reef teal
const COL_NAME := "#e9f0f6"
const COL_LINK := "#7fe3f5"
const COL_NOTE := "#7c8fa0"
const COL_PARA := "#b9c8d4"

@onready var scroll: ScrollContainer = $Page/Margin/VBox/Scroll
@onready var credits_label: RichTextLabel = $Page/Margin/VBox/Scroll/ScrollMargin/CreditsLabel
@onready var status_label: Label = $Page/Margin/VBox/StatusLabel
@onready var back_button: Button = $Page/Margin/VBox/FooterRow/FooterRight/BackButton

var _default_status := ""


func _ready() -> void:
	_default_status = status_label.text
	credits_label.text = _build_bbcode()
	credits_label.meta_clicked.connect(_on_meta_clicked)
	credits_label.meta_hover_started.connect(_on_meta_hover_started)
	credits_label.meta_hover_ended.connect(_on_meta_hover_ended)
	back_button.pressed.connect(func() -> void: closed.emit())


func focus_default() -> void:
	back_button.grab_focus()
	# Re-opening the screen should start at the top rather than wherever the
	# player last scrolled to. Deferred as well as immediate: on the first open the
	# RichTextLabel has not been laid out yet, so the ScrollContainer clamps an
	# early write against a scroll range it does not know about.
	scroll.scroll_vertical = 0
	scroll.set_deferred(&"scroll_vertical", 0)


func _build_bbcode() -> String:
	var out: PackedStringArray = []
	var first_section := true
	for block in CreditsData.blocks():
		match int(block["kind"]):
			CreditsData.Kind.SECTION:
				# A section owns the air above it, so the gap belongs here rather
				# than as a trailing blank on whatever came before.
				if not first_section:
					out.append("")
				first_section = false
				out.append("[font_size=11][color=%s][b]%s[/b][/color][/font_size]" % [
					COL_SECTION, String(block["text"]).to_upper()
				])
			CreditsData.Kind.SUB:
				out.append("")
				out.append("[color=%s]%s[/color]" % [COL_SUB, block["text"]])
			CreditsData.Kind.PARA:
				out.append("[color=%s]%s[/color]" % [COL_PARA, block["text"]])
				out.append("")
			CreditsData.Kind.ENTRY:
				out.append(_entry_bbcode(block))
	return "\n".join(out)


## Two lines per entry: what it is, then who made it and under what terms. The
## author doubles as the hyperlink anchor because a raw itch.io URL does not fit
## in 480 pixels.
func _entry_bbcode(entry: Dictionary) -> String:
	var name_line := "[color=%s]%s[/color]" % [COL_NAME, entry["name"]]

	var credit: PackedStringArray = []
	var author := String(entry["author"])
	var url := String(entry["url"])
	if not author.is_empty():
		if url.is_empty():
			credit.append("[color=%s]%s[/color]" % [COL_NOTE, author])
		else:
			credit.append("[url=%s][color=%s][u]%s[/u][/color][/url]" % [url, COL_LINK, author])
	elif not url.is_empty():
		credit.append("[url=%s][color=%s][u]Open link[/u][/color][/url]" % [url, COL_LINK])

	var note := String(entry["note"])
	if not note.is_empty():
		credit.append("[color=%s]%s[/color]" % [COL_NOTE, note])

	if credit.is_empty():
		return name_line
	return "%s\n[indent]%s[/indent]" % [name_line, "   ".join(credit)]


func _on_meta_clicked(meta: Variant) -> void:
	var url := String(meta)
	if not url.begins_with("http"):
		return
	Sfx.play(&"ui_confirm", 0.04, -5.0)
	OS.shell_open(url)


func _on_meta_hover_started(meta: Variant) -> void:
	status_label.text = _short_url(String(meta))
	credits_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_meta_hover_ended(_meta: Variant) -> void:
	status_label.text = _default_status
	credits_label.mouse_default_cursor_shape = Control.CURSOR_ARROW


## The footer has about 150 pixels for this. Dropping the scheme and the www is
## enough to fit most itch.io addresses while still naming the real destination.
func _short_url(url: String) -> String:
	return url.trim_prefix("https://").trim_prefix("http://").trim_prefix("www.").trim_suffix("/")


## Esc backs out of this screen. Handled here and marked consumed so it works
## identically from the main menu (whose own handler sits on a parent node) and
## from the in-game MenuManager stack, without both of them popping at once.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
