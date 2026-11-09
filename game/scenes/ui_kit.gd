class_name UiKit
extends RefCounted
## Small helpers so menus share one storybook look without a theme asset.

const INK := Color(0.95, 0.92, 0.86)
const MUTED := Color(0.75, 0.72, 0.68)
const ACCENT := Color(0.95, 0.72, 0.25)


static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	var glow := ColorRect.new()
	glow.color = Color(0.95, 0.6, 0.25, 0.05)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(glow)


static func panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Hud.panel_style(0.9))
	parent.add_child(p)
	return p


static func label(parent: Control, text: String, size: int = 16, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


static func button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 38)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


static func row(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	return h


static func centered_column(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	return v


## IPv4 addresses partners can join; Tailscale's 100.64.0.0/10 range is labelled.
static func join_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a: String in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		var parts := a.split(".")
		var tailscale := parts.size() == 4 and parts[0] == "100" and int(parts[1]) >= 64 and int(parts[1]) <= 127
		out.append(("%s (Tailscale)" % a) if tailscale else ("%s (LAN)" % a))
	return out
