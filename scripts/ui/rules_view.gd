extends Control
## Il regolamento a tutto schermo, con le carte dei personaggi.

var main


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/ui/cover.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.45, 0.45, 0.5)
	add_child(bg)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 30)
	add_child(mc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.parchment(26))
	mc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	var hb := HBoxContainer.new()
	var t := UI.label("Il regolamento", 44, UI.INK, UI.font_deco)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	var back := UI.primary(UI.button("Torna al menu", 240, 52, 20))
	back.pressed.connect(func(): main.show_menu())
	hb.add_child(back)
	vb.add_child(hb)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	sc.add_child(inner)
	var r := UI.rich(21, UI.INK)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.append_text(RulesText.TEXT)
	inner.add_child(r)
	inner.add_child(UI.title("Le carte dei personaggi", 30, UI.INK))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 14)
	fl.add_theme_constant_override("v_separation", 14)
	for c in SKData.CHARS:
		var ic := UI.icon(SKData.ccard(c), 280)
		ic.custom_minimum_size = Vector2(280, 420)
		fl.add_child(ic)
	inner.add_child(fl)
	inner.add_child(UI.title("Le carte obiettivo", 30, UI.INK))
	var fl2 := HFlowContainer.new()
	fl2.add_theme_constant_override("h_separation", 10)
	fl2.add_theme_constant_override("v_separation", 10)
	for o in SKData.OBJECTIVES:
		var ic2 := UI.icon(SKData.obj_image(o["id"]), 190)
		ic2.custom_minimum_size = Vector2(190, 272)
		ic2.tooltip_text = SKData.obj_text(o["id"])
		fl2.add_child(ic2)
	inner.add_child(fl2)
