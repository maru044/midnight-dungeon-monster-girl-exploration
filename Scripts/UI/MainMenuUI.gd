extends Control
class_name MainMenuUI

# ==============================================================================
# 主菜单界面 (MainMenuUI)
# 职责：提供 API 配置（BA风格磨砂卡片）、提供角色入口按钮。
# ==============================================================================

var opt_type: OptionButton
var input_url: LineEdit
var input_key: LineEdit
var input_model: LineEdit
var input_temp: LineEdit
var input_top_p: LineEdit

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 深色背景
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var hbox_main = HBoxContainer.new()
	hbox_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox_main)
	
	# ==========================================
	# 左侧区域：API 配置卡片
	# ==========================================
	var left_margin = MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 100)
	left_margin.add_theme_constant_override("margin_top", 150)
	left_margin.add_theme_constant_override("margin_bottom", 150)
	hbox_main.add_child(left_margin)
	
	var config_panel = PanelContainer.new()
	var sb_config = StyleBoxFlat.new()
	sb_config.bg_color = Color(0.12, 0.15, 0.2, 0.9)
	sb_config.corner_radius_top_left = 30; sb_config.corner_radius_bottom_right = 30; sb_config.corner_radius_top_right = 30; sb_config.corner_radius_bottom_left = 30
	sb_config.border_width_left = 4; sb_config.border_color = Color(0.3, 0.8, 0.9, 0.8) # 左侧高亮边
	config_panel.add_theme_stylebox_override("panel", sb_config)
	left_margin.add_child(config_panel)
	
	var vbox_cfg = VBoxContainer.new()
	vbox_cfg.add_theme_constant_override("separation", 25)
	
	var cfg_margin = MarginContainer.new()
	cfg_margin.add_theme_constant_override("margin_left", 40)
	cfg_margin.add_theme_constant_override("margin_right", 40)
	cfg_margin.add_theme_constant_override("margin_top", 40)
	cfg_margin.add_theme_constant_override("margin_bottom", 40)
	cfg_margin.add_child(vbox_cfg)
	config_panel.add_child(cfg_margin)
	
	var title = Label.new()
	title.text = "大模型终端配置 (API Config)"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
	vbox_cfg.add_child(title)
	
	# 下拉菜单 API Type
	var lbl_type = Label.new(); lbl_type.text = "API 专区选择"; vbox_cfg.add_child(lbl_type)
	opt_type = OptionButton.new()
	opt_type.add_item("Gemini 3.1 Pro (GCLI 代理专区)", 0)
	opt_type.add_item("DeepSeek V4 专区", 1)
	if GameManager.api_type == "deepseek":
		opt_type.select(1)
	else:
		opt_type.select(0)
	opt_type.item_selected.connect(_on_api_type_changed)
	vbox_cfg.add_child(opt_type)
	
	var lbl_url = Label.new(); lbl_url.text = "API URL (完整终点)"; vbox_cfg.add_child(lbl_url)
	input_url = LineEdit.new(); vbox_cfg.add_child(input_url)
	
	var lbl_key = Label.new(); lbl_key.text = "API Key (Bearer)"; vbox_cfg.add_child(lbl_key)
	input_key = LineEdit.new(); input_key.secret = true; vbox_cfg.add_child(input_key)
	
	var lbl_model = Label.new(); lbl_model.text = "模型名 (Model Name)"; vbox_cfg.add_child(lbl_model)
	input_model = LineEdit.new(); vbox_cfg.add_child(input_model)
	
	var param_hbox = HBoxContainer.new()
	param_hbox.add_theme_constant_override("separation", 20)
	vbox_cfg.add_child(param_hbox)
	
	var temp_vbox = VBoxContainer.new()
	temp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_hbox.add_child(temp_vbox)
	var lbl_temp = Label.new(); lbl_temp.text = "温度 (Temperature)"; temp_vbox.add_child(lbl_temp)
	input_temp = LineEdit.new(); temp_vbox.add_child(input_temp)
	
	var top_vbox = VBoxContainer.new()
	top_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_hbox.add_child(top_vbox)
	var lbl_top = Label.new(); lbl_top.text = "核采样 (Top P)"; top_vbox.add_child(lbl_top)
	input_top_p = LineEdit.new(); top_vbox.add_child(input_top_p)
	
	# 初次加载回显数据
	_refresh_api_inputs(GameManager.api_type)
	
	# ==========================================
	# 右侧区域：角色遭遇入口
	# ==========================================
	var right_margin = MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_right", 100)
	right_margin.add_theme_constant_override("margin_top", 200)
	right_margin.add_theme_constant_override("margin_bottom", 200)
	hbox_main.add_child(right_margin)
	
	var vbox_chars = VBoxContainer.new()
	vbox_chars.add_theme_constant_override("separation", 30)
	right_margin.add_child(vbox_chars)
	
	var title_char = Label.new()
	title_char.text = "开始深夜遭遇战"
	title_char.add_theme_font_size_override("font_size", 36)
	title_char.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_chars.add_child(title_char)
	
	# 预设角色（带图鉴迷雾锁定）
	var save_mgr = get_node_or_null("/root/SaveManager")
	var is_locked = func(c_id):
		if not save_mgr: return true
		return not save_mgr.has_encountered(c_id)
		
	_add_char_btn(vbox_chars, "hakuri", "🦊 遭遇：狐妖 白璃 (Hakuri)", is_locked.call("hakuri"))
	_add_char_btn(vbox_chars, "hiba", "🦟 遭遇：蚊子娘 绯羽 (Hiba)", is_locked.call("hiba"))
	_add_char_btn(vbox_chars, "shion", "🐉 遭遇：龙娘 紫音 (Shion)", is_locked.call("shion"))
	
	# 随机抽取是不受限制的唯一合法入口
	var btn_random = _add_char_btn(vbox_chars, "random", "🎲 命运指引 (深入黑暗随机遭遇)", false)
	var sb_rnd = btn_random.get_theme_stylebox("normal").duplicate()
	sb_rnd.bg_color = Color(0.6, 0.4, 0.8)
	btn_random.add_theme_stylebox_override("normal", sb_rnd)

	# 保存按钮 (属于左侧面板)
	var btn_save_cfg = Button.new()
	btn_save_cfg.text = "保存配置"
	btn_save_cfg.custom_minimum_size = Vector2(0, 60)
	var sb_btn_cfg = StyleBoxFlat.new()
	sb_btn_cfg.bg_color = Color(0.2, 0.6, 0.4)
	sb_btn_cfg.corner_radius_top_left = 10; sb_btn_cfg.corner_radius_bottom_right = 10; sb_btn_cfg.corner_radius_top_right = 10; sb_btn_cfg.corner_radius_bottom_left = 10
	btn_save_cfg.add_theme_stylebox_override("normal", sb_btn_cfg)
	btn_save_cfg.pressed.connect(func():
		var type_str = "gemini" if opt_type.get_selected_id() == 0 else "deepseek"
		var temp_val = input_temp.text.to_float()
		var top_val = input_top_p.text.to_float()
		GameManager.save_api_config(type_str, input_url.text, input_key.text, input_model.text, temp_val, top_val)
		btn_save_cfg.text = "已保存该专区配置!"
		await get_tree().create_timer(1.0).timeout
		btn_save_cfg.text = "保存配置"
	)
	vbox_cfg.add_child(btn_save_cfg)

func _on_api_type_changed(idx: int) -> void:
	var type_str = "gemini" if idx == 0 else "deepseek"
	_refresh_api_inputs(type_str)

func _refresh_api_inputs(type_str: String) -> void:
	var cfg = GameManager.api_configs.get(type_str, {})
	input_url.text = cfg.get("url", "")
	input_key.text = cfg.get("key", "")
	input_model.text = cfg.get("model", "")
	input_temp.text = str(cfg.get("temp", 1.0))
	input_top_p.text = str(cfg.get("top_p", 0.9))

func _add_char_btn(parent: Control, char_id: String, text: String, locked: bool = false) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 24)
	
	var sb = StyleBoxFlat.new()
	sb.corner_radius_top_left = 15; sb.corner_radius_bottom_right = 15; sb.corner_radius_top_right = 15; sb.corner_radius_bottom_left = 15
	
	if locked:
		btn.text = "🔒 未知区域 (???)"
		sb.bg_color = Color(0.15, 0.15, 0.15, 0.9)
		btn.disabled = true
	else:
		btn.text = text
		sb.bg_color = Color(0.2, 0.35, 0.5, 0.9)
		var sb_hover = sb.duplicate()
		sb_hover.bg_color = sb.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", sb_hover)
		
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	
	if not locked:
		btn.pressed.connect(func(): _start_encounter(char_id))
		
	parent.add_child(btn)
	return btn

func _start_encounter(target_id: String) -> void:
	if not GameManager.has_valid_api_key():
		print("请先保存 API 配置！")
		return
		
	var actual_id = target_id
	if target_id == "random":
		var pool = ["hakuri", "hiba", "shion"]
		actual_id = pool[randi() % pool.size()]
		
	# 构建遭遇战完整场景
	var encounter_root = Control.new()
	encounter_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 1. 实例化立绘视觉控制器
	var visual_ctrl = VisualController.new()
	visual_ctrl.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	visual_ctrl.offset_right = 608
	visual_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 【修复锚点与缩放问题】：必须设置正确的 expand 模式，否则大图无法显示或会溢出
	visual_ctrl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual_ctrl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	var mat = ShaderMaterial.new()
	var shader = load("res://Shaders/2.5d_parallax.gdshader")
	if shader:
		mat.shader = shader
	visual_ctrl.material = mat
	encounter_root.add_child(visual_ctrl)
	
	# 2. 实例化右侧聊天面板
	var encounter_ui = EncounterUI.new()
	encounter_root.add_child(encounter_ui)
	
	# 将完整场景添加到树
	get_tree().root.add_child(encounter_root)
	
	self.visible = false
	
	# 【修复内存泄漏与空指针异常】：必须使用 CONNECT_ONE_SHOT！
	# 否则每次进入遭遇战都会在全局 EventBus 上挂载一个新的匿名函数。
	EventBus.encounter_started.emit(actual_id)
	
	var on_end = func():
		# 当遭遇战结束返回时，强制重建主界面，以刷新可能新解锁的角色图鉴
		for child in get_children():
			child.queue_free()
		_build_ui()
		self.visible = true
		if is_instance_valid(encounter_root):
			encounter_root.queue_free()
			
	EventBus.encounter_ended.connect(on_end, CONNECT_ONE_SHOT)
