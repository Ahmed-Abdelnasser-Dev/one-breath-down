extends VBoxContainer
class_name BrandCorner
## The developer signature: the FakeMC wordmark, optionally over a row of real
## hyperlinks that open in the player's browser.
##
## The link addresses come from CREDITS.md via CreditsData, so there is exactly
## one place to edit them: adding a line under "### Find FakeMC" in that file adds
## a button here. The main menu shows the wordmark alone (`show_links = false`);
## the Credits screen shows the full set.

const LINKS_SECTION := "Find FakeMC"

const COL_LINK := Color(0.5, 0.89, 0.96)
const COL_LINK_HOVER := Color(1.0, 0.91, 0.66)

## Off for the plain menu signature, on for the Credits footer.
@export var show_links: bool = true

@onready var links_row: GridContainer = $LinksRow


func _ready() -> void:
	links_row.visible = show_links
	if show_links:
		_build_links()


## One flat, focusable Button per link. Buttons rather than RichTextLabel metas so
## keyboard and gamepad players can reach them, and so the Sfx autoload's
## automatic BaseButton wiring gives them click and hover sounds for free.
func _build_links() -> void:
	for child in links_row.get_children():
		child.queue_free()

	# `flat` stops the button box being drawn but not its 8px content margins,
	# which is a third of the corner's width across five buttons. The focus box is
	# deliberately left alone so keyboard players can still see where they are.
	var tight := StyleBoxEmpty.new()
	tight.content_margin_left = 3.0
	tight.content_margin_right = 3.0
	tight.content_margin_top = 1.0
	tight.content_margin_bottom = 1.0

	for link in CreditsData.links_in(LINKS_SECTION):
		var url := String(link["url"])
		var button := Button.new()
		button.text = _label_for(link)
		var handle := String(link["author"])
		button.tooltip_text = url if handle.is_empty() else "%s\n%s" % [handle, url]
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override(&"font_size", 8)
		button.add_theme_color_override(&"font_color", COL_LINK)
		button.add_theme_color_override(&"font_hover_color", COL_LINK_HOVER)
		button.add_theme_color_override(&"font_focus_color", COL_LINK_HOVER)
		button.add_theme_color_override(&"font_pressed_color", COL_LINK_HOVER)
		for state in [&"normal", &"hover", &"pressed"]:
			button.add_theme_stylebox_override(state, tight)
		button.pressed.connect(func() -> void: OS.shell_open(url))
		links_row.add_child(button)


## "GitHub | Ahmed-Abdelnasser-Dev | url" becomes "GitHub": only the platform name
## fits in a screen corner. The handle goes in the tooltip, and the Credits screen
## proper shows both.
func _label_for(link: Dictionary) -> String:
	var name := String(link["name"])
	return name if not name.is_empty() else String(link["author"])
