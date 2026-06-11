extends Window
class_name SaveLoadMenuUI

# ==============================================================================
# 历史档案室面板 (SaveLoadMenuUI)
# ==============================================================================

var save_list: ItemList
var input_save_name: LineEdit
var btn_load: Button
var btn_overwrite: Button
var btn_delete: Button

var saves_data: Array = []
var target_char_id: String = ""

# 引用父级 EncounterUI 的方法
var encounter_ui_ref = null

func _init(encounter_ui, char_id: String) -> void:
	encounter_ui_ref = encounter_ui
	target_char_id = char_id
	title = "📚 历史档案室 [" + char_id.to_upper() + "]"
	size = Vector2i(900, 600)
	visible = false
	exclusive = true
	close_requested.connect(func(): hide())

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	margin.add_child(hbox)
	
	# 左侧：列表与新建
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.5
	hbox.add_child(left_vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "存档列表"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
	left_vbox.add_child(title_lbl)
	
	save_list = ItemList.new()
	save_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	save_list.add_theme_font_size_override("font_size", 20)
	var list_sb = StyleBoxFlat.new()
	list_sb.bg_color = Color(0.05, 0.05, 0.08, 0.6)
	save_list.add_theme_stylebox_override("panel", list_sb)
	save_list.item_selected.connect(_on_save_selected)
	left_vbox.add_child(save_list)
	
	var new_save_hbox = HBoxContainer.new()
	new_save_hbox.add_theme_constant_override("separation", 15)
	left_vbox.add_child(new_save_hbox)
	
	input_save_name = LineEdit.new()
	input_save_name.placeholder_text = "输入新存档名称..."
	input_save_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_save_name.custom_minimum_size = Vector2(0, 50)
	new_save_hbox.add_child(input_save_name)
	
	var btn_new = Button.new()
	btn_new.text = "➕ 创建新存档"
	btn_new.custom_minimum_size = Vector2(150, 0)
	btn_new.pressed.connect(_on_new_save_pressed)
	new_save_hbox.add_child(btn_new)
	
	# 右侧：详情与操作
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 20)
	hbox.add_child(right_vbox)
	
	var op_title = Label.new()
	op_title.text = "操作"
	op_title.add_theme_font_size_override("font_size", 28)
	right_vbox.add_child(op_title)
	
	btn_load = _create_action_btn("📂 读取存档", Color(0.2, 0.5, 0.8))
	btn_load.pressed.connect(_on_load_pressed)
	right_vbox.add_child(btn_load)
	
	btn_overwrite = _create_action_btn("💾 覆盖存档", Color(0.8, 0.6, 0.2))
	btn_overwrite.pressed.connect(_on_overwrite_pressed)
	right_vbox.add_child(btn_overwrite)
	
	btn_delete = _create_action_btn("🗑️ 删除存档", Color(0.8, 0.3, 0.3))
	btn_delete.pressed.connect(_on_delete_pressed)
	right_vbox.add_child(btn_delete)

func _create_action_btn(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 60)
	btn.add_theme_font_size_override("font_size", 22)
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 12; sb.corner_radius_bottom_right = 12; sb.corner_radius_top_right = 12; sb.corner_radius_bottom_left = 12
	btn.add_theme_stylebox_override("normal", sb)
	return btn

func open_panel() -> void:
	_refresh_list()
	popup_centered()

func _refresh_list() -> void:
	save_list.clear()
	btn_load.disabled = true
	btn_overwrite.disabled = true
	btn_delete.disabled = true
	
	var hm = get_node_or_null("/root/SaveManager")
	if not hm: return
	
	saves_data = hm.get_all_saves(target_char_id)
	for s in saves_data:
		save_list.add_item(s["time_str"] + " | " + s["slot_name"])

func _on_save_selected(idx: int) -> void:
	btn_load.disabled = false
	btn_overwrite.disabled = false
	btn_delete.disabled = false

func _on_new_save_pressed() -> void:
	var s_name = input_save_name.text.strip_edges()
	if s_name == "": s_name = "未命名存档_" + str(Time.get_unix_time_from_system())
	var hm = get_node_or_null("/root/SaveManager")
	if hm and encounter_ui_ref:
		hm.save_slot(target_char_id, s_name, encounter_ui_ref.current_context)
		input_save_name.text = ""
		_refresh_list()

func _on_load_pressed() -> void:
	var sel = save_list.get_selected_items()
	if sel.is_empty(): return
	var meta = saves_data[sel[0]]
	var hm = get_node_or_null("/root/SaveManager")
	if hm and encounter_ui_ref:
		encounter_ui_ref.load_context_from_slot(meta["slot_name"])
		hide()

func _on_overwrite_pressed() -> void:
	var sel = save_list.get_selected_items()
	if sel.is_empty(): return
	var meta = saves_data[sel[0]]
	var hm = get_node_or_null("/root/SaveManager")
	if hm and encounter_ui_ref:
		hm.save_slot(target_char_id, meta["slot_name"], encounter_ui_ref.current_context)
		_refresh_list()

func _on_delete_pressed() -> void:
	var sel = save_list.get_selected_items()
	if sel.is_empty(): return
	var meta = saves_data[sel[0]]
	var hm = get_node_or_null("/root/SaveManager")
	if hm:
		hm.delete_slot(target_char_id, meta["slot_name"])
		_refresh_list()
