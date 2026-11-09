class_name Hud
extends CanvasLayer
## The two-screen HUD: your bars and ability bar, the shared Bond meter, a partner panel, an
## off-screen partner arrow, encounter and pause banners, toasts, the F3 network overlay,
## F1 controls and the Tab loadout (abilities and Form runes, out of combat only).

const SLOT_ACTIONS: Array[StringName] = [&"attack", &"ability_1", &"ability_2", &"ability_3", &"ability_4", &"shove", &"flask"]

var arena: Node
var local_slot: int = 0
var accent := ProcMesh.GOLD
var root: Control
var _hp_fill: ColorRect
var _barrier_fill: ColorRect
var _res_fill: ColorRect
var _res_label: Label
var _hp_label: Label
var _bond_fill: ColorRect
var _bond_label: Label
var _slots: Array[Dictionary] = []
var _dodge_label: Label
var _partner_panel: PanelContainer
var _partner_name: Label
var _partner_hp: ColorRect
var _partner_barrier: ColorRect
var _partner_res: ColorRect
var _partner_status: Label
var _arrow: Control
var _encounter_label: Label
var _toasts: VBoxContainer
var _center_label: Label
var _prompt_label: Label
var _net_label: Label
var _help: PanelContainer
var _pause_panel: PanelContainer
var _pause_label: Label
var _loadout_panel: PanelContainer
var _loadout_box: VBoxContainer
var _loadout_choices: Array[OptionButton] = []
var _rune_choices: Array[OptionButton] = []
var _bar_width: float = 360.0


func setup(p_arena: Node, p_local_slot: int, color: Color) -> void:
	arena = p_arena
	local_slot = p_local_slot
	accent = color
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_bottom()
	_build_partner()
	_build_top()
	_build_overlays()


# --- Construction ---------------------------------------------------------------------------

static func panel_style(alpha: float = 0.72) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.06, 0.09, alpha)
	s.border_color = Color(0.85, 0.7, 0.45, 0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _bar(parent: Control, width: float, height: float, color: Color) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.03, 0.85)
	back.custom_minimum_size = Vector2(width, height)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(width, height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return fill


func _label(parent: Control, text: String, size: int = 16, color: Color = Color(0.95, 0.92, 0.86)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_bottom() -> void:
	var anchor := VBoxContainer.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	anchor.position.y -= 14
	anchor.alignment = BoxContainer.ALIGNMENT_END
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anchor)
	var bond_row := HBoxContainer.new()
	bond_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bond_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(bond_row)
	_bond_label = _label(bond_row, "Bond", 14, Color(1.0, 0.86, 0.6))
	_bond_fill = _bar(bond_row, 260.0, 8.0, Color(1.0, 0.75, 0.45))
	var panel := _panel(anchor)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var bars := HBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bars)
	var hp_box := VBoxContainer.new()
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(hp_box)
	_hp_fill = _bar(hp_box, _bar_width, 14.0, Color(0.82, 0.22, 0.2))
	_barrier_fill = ColorRect.new()
	_barrier_fill.color = Color(1.0, 0.86, 0.45, 0.7)
	_barrier_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.get_parent().add_child(_barrier_fill)
	_hp_label = _label(_hp_fill.get_parent(), "", 11)
	_res_fill = _bar(hp_box, _bar_width, 8.0, Color(0.35, 0.6, 1.0))
	_res_label = _label(_res_fill.get_parent(), "", 10)
	_dodge_label = _label(bars, "", 14, Color(0.85, 0.9, 1.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	for i in SLOT_ACTIONS.size():
		var slot_panel := PanelContainer.new()
		var st := panel_style(0.9)
		st.border_color = accent.darkened(0.2)
		slot_panel.add_theme_stylebox_override("panel", st)
		slot_panel.custom_minimum_size = Vector2(92, 58)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot_panel)
		var inner := Control.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(inner)
		var cd := ColorRect.new()
		cd.color = Color(0, 0, 0, 0.62)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(cd)
		var key := _label(inner, Settings.binding_text(SLOT_ACTIONS[i]), 12, accent)
		var name_label := _label(inner, "", 12)
		name_label.position = Vector2(0, 18)
		name_label.custom_minimum_size = Vector2(80, 0)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		var tag := _label(inner, "", 9, Color(0.75, 0.72, 0.68))
		tag.position = Vector2(0, 42)
		_slots.append({"panel": slot_panel, "cd": cd, "key": key, "name": name_label, "tag": tag})


func _build_partner() -> void:
	_partner_panel = _panel(root)
	_partner_panel.position = Vector2(16, 16)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_partner_panel.add_child(v)
	_partner_name = _label(v, "Partner", 16)
	_partner_hp = _bar(v, 200.0, 10.0, Color(0.82, 0.22, 0.2))
	_partner_barrier = ColorRect.new()
	_partner_barrier.color = Color(1.0, 0.86, 0.45, 0.7)
	_partner_barrier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_partner_hp.get_parent().add_child(_partner_barrier)
	_partner_res = _bar(v, 200.0, 5.0, Color(0.35, 0.6, 1.0))
	_partner_status = _label(v, "", 12, Color(0.85, 0.85, 0.85))
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	root.add_child(_arrow)
	_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)


## A full-width label pinned to the top, centred horizontally (robust at any window size).
func _wide_label(top: float, size: int, color: Color) -> Label:
	var l := _label(root, "", size, color)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.offset_bottom = top + size * 1.6
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_top() -> void:
	_encounter_label = _wide_label(14.0, 22, Color(1.0, 0.92, 0.75))
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 56.0
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)
	_center_label = _label(root, "", 26, Color(1.0, 0.5, 0.45))
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label = _label(root, "", 18, Color(0.95, 0.95, 1.0))
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_label.offset_top = 150.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_net_label = _label(root, "", 13, Color(0.7, 1.0, 0.8))
	_net_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_net_label.offset_top = 16.0
	_net_label.offset_right = -16.0
	_net_label.offset_bottom = 140.0
	_net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_net_label.visible = false


func _centered_overlay() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func _build_overlays() -> void:
	_help = _panel(_centered_overlay())
	var help_text := "Controls (rebind in Settings)\n"
	for action: StringName in Settings.ACTION_LABELS.keys():
		help_text += "%-18s %s\n" % [Settings.ACTION_LABELS[action], Settings.binding_text(action)]
	help_text += "Move: WASD / left stick    Aim: mouse / right stick\nF3 network overlay, F1 this help"
	_label(_help, help_text, 15)
	_help.visible = false
	_pause_panel = _panel(_centered_overlay())
	_pause_label = _label(_pause_panel, "", 20)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_panel.visible = false
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 24.0
	left.offset_top = 140.0
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	_loadout_panel = _panel(left)
	_loadout_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_loadout_box = VBoxContainer.new()
	_loadout_panel.add_child(_loadout_box)
	_loadout_panel.visible = false


# --- Updates ------------------------------------------------------------------------------------

func toast(text: String, color: Color = Color(1.0, 0.92, 0.75), seconds: float = 3.0) -> void:
	var l := _label(_toasts, text, 18, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(l):
			l.queue_free())
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()


func toggle_help() -> void:
	_help.visible = not _help.visible


func toggle_net() -> void:
	_net_label.visible = not _net_label.visible


func set_pause(paused: bool, text: String) -> void:
	_pause_panel.visible = paused
	_pause_label.text = text


func on_event(ev: Array) -> void:
	match int(ev[0]):
		NetProtocol.EV_SAVED:
			toast("Checkpoint saved (revision %d)" % int(ev[1]), Color(0.7, 0.9, 1.0))
		NetProtocol.EV_XP:
			toast("+%d XP · level %d" % [int(ev[1]), int(ev[2])], Color(0.8, 1.0, 0.7))
		NetProtocol.EV_JOURNAL:
			toast("Chronicle: " + str(ev[1]), Color(1.0, 0.85, 0.55), 4.0)
		NetProtocol.EV_REJECTED:
			if int(ev[1]) == local_slot:
				toast(str(ev[2]), Color(1.0, 0.6, 0.5))
		NetProtocol.EV_DOUBLE_TECH:
			match int(ev[1]):
				1:
					toast("Hearthflare requested! Hold %s together." % Settings.binding_text(&"bond"), Color(1.0, 0.8, 0.5))
				2:
					toast("HEARTHFLARE", Color(1.0, 0.75, 0.4), 2.0)


func _process(_delta: float) -> void:
	if arena == null:
		return
	var me: Hero = arena.call("hero", local_slot)
	var partner: Hero = arena.call("hero", 1 - local_slot)
	if me != null:
		_update_self(me)
	_update_partner(partner)
	_update_encounter(me, partner)
	_arrow.queue_redraw()
	if _net_label.visible:
		_net_label.text = arena.call("net_overlay_text")


func _update_self(me: Hero) -> void:
	var s := me.stats
	var hp_frac := s.health_fraction()
	_hp_fill.size.x = _bar_width * hp_frac
	_barrier_fill.size = Vector2(_bar_width * clampf(s.barrier / s.max_health, 0.0, 1.0), 14.0)
	_hp_label.text = " %d / %d%s" % [roundi(s.health), roundi(s.max_health), ("  +%d barrier" % roundi(s.barrier)) if s.barrier > 0.5 else ""]
	var m := me.motor
	_res_fill.size.x = _bar_width * clampf(m.resource / maxf(1.0, m.resource_max), 0.0, 1.0)
	_res_fill.color = Color(0.35, 0.6, 1.0) if m.uses_flux else Color(1.0, 0.65, 0.25)
	_res_label.text = " %s %d" % [me.class_def.resource_label, roundi(m.resource)]
	_dodge_label.text = "  Dodge %d/%d  Flask %d" % [m.dodge_charges, m.dodge_charges_max, m.flask_charges]
	var bond: float = arena.get("bond_meter")
	_bond_fill.size.x = 260.0 * bond
	_bond_label.text = "Bond %d%%  " % roundi(bond * 100.0) if bond < 1.0 else "Bond full: hold %s together  " % Settings.binding_text(&"bond")
	var tick := NetworkTime.tick
	for i in _slots.size():
		var def := m.ability_at(i)
		var slot: Dictionary = _slots[i]
		(slot["name"] as Label).text = def.display_name if def != null else "-"
		(slot["tag"] as Label).text = def.tag_label if def != null else ""
		var cd := slot["cd"] as ColorRect
		var frac := 0.0
		if def != null and def.cooldown_ticks > 0:
			frac = clampf(float(m.get_cd(i) - tick) / def.cooldown_ticks, 0.0, 1.0)
		if def != null and m.uses_flux and m.resource < m.effective_cost(def):
			frac = maxf(frac, 0.35)
		var panel := slot["panel"] as Control
		cd.size = Vector2(panel.size.x - 20.0, (panel.size.y - 12.0) * frac)
		cd.position = Vector2(0, (panel.size.y - 12.0) * (1.0 - frac))
	_center_label.text = ""
	if s.life == NetProtocol.LIFE_DOWNED:
		_center_label.text = "Downed! Crawl to safety; your partner can revive you (%ds)" % ceili(_downed_left(me))
	elif s.life == NetProtocol.LIFE_FALLEN:
		_center_label.text = "Fallen. You'll stand again when the wave ends or the encounter restarts."


func _downed_left(h: Hero) -> float:
	if Net.is_host():
		return maxf(0.0, (h.stats.downed_until - NetworkTime.tick) / 60.0)
	return h.stats.downed_left_s


func _update_partner(partner: Hero) -> void:
	_partner_panel.visible = partner != null
	if partner == null:
		return
	var s := partner.stats
	_partner_name.text = "%s · %s" % [partner.hero_name, partner.class_def.display_name]
	_partner_name.add_theme_color_override("font_color", ProcMesh.player_color(partner.color_name))
	_partner_hp.size.x = 200.0 * s.health_fraction()
	_partner_barrier.size = Vector2(200.0 * clampf(s.barrier / s.max_health, 0.0, 1.0), 10.0)
	_partner_res.size.x = 200.0 * clampf(partner.motor.resource / maxf(1.0, partner.motor.resource_max), 0.0, 1.0)
	var me: Hero = arena.call("hero", local_slot)
	var dist := GameTypes.flat(partner.global_position - me.global_position).length() if me != null else 0.0
	var status := "%.0f m away" % dist
	match s.life:
		NetProtocol.LIFE_DOWNED:
			status = "DOWNED: revive them! (%ds)" % ceili(_downed_left(partner))
		NetProtocol.LIFE_FALLEN:
			status = "Fallen"
	if not bool(arena.call("partner_connected")):
		status = "Reconnecting..."
	_partner_status.text = status


func _update_encounter(me: Hero, partner: Hero) -> void:
	var view: Dictionary = arena.get("encounter_view")
	var state := int(view.get("state", 0))
	var wave := int(view.get("wave", 0))
	var count := int(view.get("count", 3))
	var left := int(view.get("left", 0))
	match state:
		NetProtocol.WAVE_PREP:
			_encounter_label.text = "The Drowned Hall · prepare at the Waystone"
		NetProtocol.WAVE_ACTIVE:
			_encounter_label.text = "Wave %d / %d · %d left" % [wave + 1, count, left]
		NetProtocol.WAVE_BREAK:
			_encounter_label.text = "Wave %d cleared · next wave soon (%s at the Waystone to start now)" % [wave + 1, Settings.binding_text(&"interact")]
		NetProtocol.WAVE_VICTORY:
			_encounter_label.text = "Victory!"
		NetProtocol.WAVE_RESTART:
			_encounter_label.text = "Regrouping at the Waystone..."
	_prompt_label.text = ""
	if me == null:
		return
	if partner != null and partner.stats.life == NetProtocol.LIFE_DOWNED and me.stats.is_alive() \
			and GameTypes.flat(partner.global_position - me.global_position).length() < 3.0:
		_prompt_label.text = "Hold %s to revive %s" % [Settings.binding_text(&"interact"), partner.hero_name]
	elif state == NetProtocol.WAVE_PREP and GameTypes.flat(me.global_position - ArenaLayout.WAYSTONE).length() < 3.0:
		_prompt_label.text = "Hold %s at the Waystone to begin · %s: loadout and runes" % [Settings.binding_text(&"interact"), Settings.binding_text(&"loadout")]


func _draw_arrow() -> void:
	var me: Hero = arena.call("hero", local_slot)
	var partner: Hero = arena.call("hero", 1 - local_slot)
	var cam: Camera3D = arena.call("camera")
	if me == null or partner == null or cam == null:
		return
	var vp := root.get_viewport_rect().size
	var target := partner.global_position + Vector3(0, 1.0, 0)
	var on_screen := cam.is_position_in_frustum(target)
	var dist := GameTypes.flat(target - me.global_position).length()
	var color := ProcMesh.player_color(partner.color_name)
	if partner.stats.life == NetProtocol.LIFE_DOWNED:
		color = Color(1.0, 0.3, 0.25, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01))
	if on_screen and dist < GameData.rule(&"regroup_distance_m"):
		return
	var screen := cam.unproject_position(target)
	if cam.is_position_behind(target):
		screen = vp - screen
	var center := vp * 0.5
	var dir := (screen - center).normalized()
	var margin := 40.0
	var edge := center + dir * minf((vp.x * 0.5 - margin) / maxf(0.001, absf(dir.x)), (vp.y * 0.5 - margin) / maxf(0.001, absf(dir.y)))
	var tip := edge + dir * 14.0
	var side := Vector2(-dir.y, dir.x) * 10.0
	_arrow.draw_colored_polygon(PackedVector2Array([tip, edge - dir * 6.0 + side, edge - dir * 6.0 - side]), color)
	var text := "%s %.0f m%s" % [partner.hero_name, dist, "  REGROUP" if dist >= GameData.rule(&"regroup_distance_m") else ""]
	_arrow.draw_string(ThemeDB.fallback_font, edge - dir * 30.0 - Vector2(30, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


# --- Loadout -----------------------------------------------------------------------------------

func toggle_loadout() -> void:
	if _loadout_panel.visible:
		_loadout_panel.visible = false
		return
	var me: Hero = arena.call("hero", local_slot)
	if me == null:
		return
	var state := int((arena.get("encounter_view") as Dictionary).get("state", 0))
	if state != NetProtocol.WAVE_PREP and state != NetProtocol.WAVE_BREAK:
		toast("Change your loadout at the Waystone between waves.", Color(1.0, 0.7, 0.5))
		return
	for c: Node in _loadout_box.get_children():
		c.queue_free()
	_loadout_choices.clear()
	_rune_choices.clear()
	_label(_loadout_box, "Loadout · %s (level %d)" % [me.class_def.display_name, int(Net.session_setup.get("level", 3))], 18, accent)
	var level := int(Net.session_setup.get("level", 3))
	var unlocked: Array[StringName] = []
	for id: StringName in me.class_def.abilities:
		if GameData.ability(id).unlock_level <= level:
			unlocked.append(id)
	var library: Dictionary = Net.session_setup.get("rune_library", {})
	for i in 4:
		var row := HBoxContainer.new()
		_loadout_box.add_child(row)
		_label(row, "%s:" % Settings.binding_text(SLOT_ACTIONS[i + 1]), 14, accent)
		var ab := OptionButton.new()
		for id: StringName in unlocked:
			ab.add_item(GameData.ability(id).display_name)
			ab.set_item_metadata(ab.item_count - 1, String(id))
		var current := me.loadout_ids[i] if i < me.loadout_ids.size() else &""
		for k in ab.item_count:
			if StringName(str(ab.get_item_metadata(k))) == current:
				ab.select(k)
		row.add_child(ab)
		_loadout_choices.append(ab)
		var rune := OptionButton.new()
		rune.add_item("No rune")
		rune.set_item_metadata(0, "")
		var def := GameData.ability(current)
		var chosen := me.rune_for(current)
		for rid: String in library.keys():
			var r := GameData.rune(StringName(rid))
			if r != null and r.category == &"form" and def != null and r.fits(def):
				rune.add_item("%s: %s" % [r.display_name, r.description])
				rune.set_item_metadata(rune.item_count - 1, rid)
				if chosen != null and chosen.id == r.id:
					rune.select(rune.item_count - 1)
		row.add_child(rune)
		_rune_choices.append(rune)
	var apply := Button.new()
	apply.text = "Apply"
	apply.pressed.connect(_apply_loadout)
	_loadout_box.add_child(apply)
	_label(_loadout_box, "Form runes fit by tag: Fork needs a projectile; a melee strike can't take it.", 12, Color(0.8, 0.78, 0.72))
	_loadout_panel.visible = true


func _apply_loadout() -> void:
	var abilities: Array = []
	var runes: Dictionary = {}
	for i in _loadout_choices.size():
		var ab := _loadout_choices[i]
		var id := str(ab.get_item_metadata(ab.selected))
		abilities.append(id)
		var r := _rune_choices[i]
		var rid := str(r.get_item_metadata(r.selected)) if r.selected >= 0 else ""
		if rid != "":
			runes[id] = {"form": rid}
	Net.send_command({"type": "loadout", "abilities": abilities, "runes": runes, "txn": "%d-%d" % [local_slot, Time.get_ticks_usec()]})
	_loadout_panel.visible = false
