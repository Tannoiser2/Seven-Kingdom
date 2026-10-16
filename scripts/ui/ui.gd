class_name UI
extends RefCounted
## Stile grafico di Seven Kingdom: pergamena, blu notte e oro delle cornici delle carte, rosso cardinalizio.
## Titoli in Cinzel Decorative (come il cartiglio del tabellone), intestazioni in Cinzel, testo in EB Garamond.

const INK := Color("#2b1d12")
const INK2 := Color("#5c4128")
const PARCH := Color("#f2e3c2")
const LIGHT := Color("#f7ecd2")
const GOLD := Color("#d9ac4f")
const GOLD_DARK := Color("#9a7130")
const NAVY := Color("#14223d")
const NAVY2 := Color("#1d3157")
const RED := Color("#9e1f24")
const GREEN := Color("#3f7d3a")
const SEA := Color("#1f6b78")
const DARK := Color("#0e1524")

static var _tex := {}
## Colore di ciascun giocatore della partita (indice in SKData.COLORS): chi è assente lascia il suo colore libero.
static var cmap: Array = [0, 1, 2, 3]
static var font_deco: Font
static var font_title: Font
static var font_body: Font
static var font_bold: Font
static var font_italic: Font
static var font_fell: Font


static func _vf(path: String, weight: int) -> Font:
	var base: FontFile = load(path)
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


static func init_fonts() -> void:
	if font_title != null:
		return
	font_deco = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	font_title = _vf("res://assets/fonts/Cinzel-VF.ttf", 700)
	font_body = _vf("res://assets/fonts/EBGaramond-VF.ttf", 500)
	font_bold = _vf("res://assets/fonts/EBGaramond-VF.ttf", 700)
	font_italic = _vf("res://assets/fonts/EBGaramond-Italic-VF.ttf", 500)
	font_fell = load("res://assets/fonts/IMFeENrm28P.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func pcol(p: int) -> Color:
	if p == SKState.INV:
		return SKData.INVADER_COLOR
	if p < 0 or p >= cmap.size():
		return Color(0.5, 0.5, 0.5)
	return SKData.COLORS[cmap[p]]["col"]


static func plight(p: int) -> Color:
	if p < 0 or p >= cmap.size():
		return Color(0.7, 0.7, 0.7)
	return SKData.COLORS[cmap[p]]["light"]


static func cid(p: int) -> String:
	return SKData.COLORS[cmap[p]]["id"]


static func cidx(p: int) -> int:
	return cmap[p] if p >= 0 and p < cmap.size() else 0


static func night(alpha := 0.93, border := GOLD_DARK, bw := 2, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.09, 0.16, alpha)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.set_content_margin_all(12)
	return s


static func parchment(margin := 18.0, border := GOLD_DARK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PARCH
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 10
	s.set_content_margin_all(margin)
	return s


static func flat(bg: Color, border: Color, bw := 1, radius := 6, margin := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func label(text: String, size := 20, col := LIGHT, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", font if font != null else font_body)
	return l


static func wrap(text: String, size := 19, col := LIGHT, width := 300.0, font: Font = null) -> Label:
	var l := label(text, size, col, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func title(text: String, size := 30, col := GOLD) -> Label:
	init_fonts()
	var l := label(text, size, col, font_title)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func rich(size := 19, col := LIGHT) -> RichTextLabel:
	init_fonts()
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_override("normal_font", font_body)
	r.add_theme_font_override("bold_font", font_bold)
	r.add_theme_font_override("italics_font", font_italic)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", col)
	return r


static func button(text: String, w := 180.0, h := 44.0, size := 17) -> Button:
	init_fonts()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_override("font", font_title)
	b.add_theme_font_size_override("font_size", size)
	_skin(b, NAVY2, Color("#2a4677"), GOLD_DARK)
	return b


static func _skin(b: Button, base: Color, hover: Color, border: Color, fcol := LIGHT) -> Button:
	var n := flat(base, border, 2, 6, 6)
	var hv := flat(hover, GOLD, 2, 6, 6)
	var pr := flat(base.darkened(0.25), GOLD, 2, 6, 6)
	var ds := flat(Color(0.14, 0.16, 0.22, 0.8), Color(0.3, 0.32, 0.38), 1, 6, 6)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", hv)
	b.add_theme_stylebox_override("disabled", ds)
	b.add_theme_color_override("font_color", fcol)
	b.add_theme_color_override("font_hover_color", Color("#fff6dc") if fcol == LIGHT else fcol)
	b.add_theme_color_override("font_pressed_color", GOLD if fcol == LIGHT else fcol)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.58))
	return b


static func primary(b: Button) -> Button:
	return _skin(b, Color("#8e1d22"), Color("#b0292e"), GOLD)


static func gold(b: Button) -> Button:
	return _skin(b, Color("#c99a43"), Color("#e2b65a"), Color("#fff0c0"), DARK)


static func colored(b: Button, c: Color) -> Button:
	return _skin(b, c.darkened(0.25), c, GOLD)


static func make_theme() -> Theme:
	init_fonts()
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 19
	t.set_color("font_color", "Label", LIGHT)
	t.set_stylebox("panel", "PanelContainer", night())
	t.set_stylebox("panel", "TooltipPanel", flat(Color("#101a2e"), GOLD, 1, 4, 8))
	t.set_color("font_color", "TooltipLabel", LIGHT)
	t.set_font_size("font_size", "TooltipLabel", 17)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.66, 0.3, 0.6)
	sb.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb)
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0, 0, 0, 0.2)
	t.set_stylebox("scroll", "VScrollBar", sb2)
	var le := flat(Color("#f5e8cc"), GOLD_DARK, 2, 6, 8)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", flat(Color("#fff3da"), GOLD, 2, 6, 8))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK2)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", RED)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_hover_pressed_color", "CheckBox", RED)
	t.set_font_size("font_size", "CheckBox", 19)
	return t


## Piccola pastiglia con l'icona di una risorsa e il numero.
static func res_chip(t: String, v: int, size := 26) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	var ic := TextureRect.new()
	ic.texture = tex("res://assets/res/%s.webp" % t)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(size, size)
	hb.add_child(ic)
	hb.add_child(label(str(v), int(size * 0.72), LIGHT, font_bold))
	hb.tooltip_text = SKData.RES_NAME[t]
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	return hb


static func icon(path: String, size := 32.0) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = tex(path)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(size, size)
	ic.mouse_filter = Control.MOUSE_FILTER_PASS
	return ic
