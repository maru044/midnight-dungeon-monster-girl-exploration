extends Window
class_name PromptEditorUI

# ==============================================================================
# 提示词预设编辑器 (PromptEditorUI)
# 职责：提供界面让玩家修改 user:// 下的提示词设定，并触发热重载。
# ==============================================================================

var list_files: ItemList
var text_editor: TextEdit
var btn_save: Button
var current_file: String = ""

var _available_files = [
	"1_System_Intro.md",
	"2_World_Rules.md",
	"3_Format_Guidelines.md",
	"Characters/hakuri.md",
	"Characters/hiba.md",
	"Characters/shion.md"
]

func _init() -> void:
	title = "⚙️ 大模型底层预设编辑器 (Prompt Editor)"
	size = Vector2i(1300, 800)
	visible = false
	exclusive = true
	close_requested.connect(func(): hide())

func _ready() -> void:
	_build_ui()
	if _available_files.size() > 0:
		list_files.select(0)
		_on_file_selected(0)

func _build_ui() -> void:
	var is_mobile = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	var font_scale = 1.6 if is_mobile else 1.0

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15, 0.98)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	
	# 左侧文件列表
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(300, 0)
	hbox.add_child(left_vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "预设文件清单 (V1.0)"
	title_lbl.add_theme_font_size_override("font_size", int(22 * font_scale))
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.6))
	left_vbox.add_child(title_lbl)
	
	list_files = ItemList.new()
	list_files.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_files.add_theme_font_size_override("font_size", int(18 * font_scale))
	for f in _available_files:
		list_files.add_item(f)
	list_files.item_selected.connect(_on_file_selected)
	left_vbox.add_child(list_files)
	
	# 右侧编辑区
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 15)
	hbox.add_child(right_vbox)
	
	text_editor = TextEdit.new()
	text_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_editor.add_theme_font_size_override("font_size", int(18 * font_scale))
	var sb_edit = StyleBoxFlat.new()
	sb_edit.bg_color = Color(0.05, 0.05, 0.07, 1.0)
	sb_edit.content_margin_left = 15; sb_edit.content_margin_top = 15
	text_editor.add_theme_stylebox_override("normal", sb_edit)
	right_vbox.add_child(text_editor)
	
	btn_save = Button.new()
	btn_save.text = "💾 保存当前文件并全系统热重载"
	btn_save.custom_minimum_size = Vector2(0, 60)
	btn_save.add_theme_font_size_override("font_size", int(22 * font_scale))
	var sb_btn = StyleBoxFlat.new()
	sb_btn.bg_color = Color(0.2, 0.6, 0.4)
	sb_btn.corner_radius_top_left = 8; sb_btn.corner_radius_bottom_right = 8; sb_btn.corner_radius_top_right = 8; sb_btn.corner_radius_bottom_left = 8
	btn_save.add_theme_stylebox_override("normal", sb_btn)
	btn_save.pressed.connect(_on_save_pressed)
	right_vbox.add_child(btn_save)

func _on_file_selected(idx: int) -> void:
	current_file = _available_files[idx]
	var builder = get_node_or_null("/root/PromptBuilder")
	if not builder: return
	
	var full_path = builder.user_prompt_dir + current_file
	if FileAccess.file_exists(full_path):
		text_editor.text = FileAccess.get_file_as_string(full_path)
	else:
		text_editor.text = "（无法读取该文件，可能未初始化成功）"

func _on_save_pressed() -> void:
	if current_file == "": return
	
	var builder = get_node_or_null("/root/PromptBuilder")
	if not builder: return
	
	var full_path = builder.user_prompt_dir + current_file
	var f = FileAccess.open(full_path, FileAccess.WRITE)
	if f:
		f.store_string(text_editor.text)
		f.close()
		
		# 发送热重载信号，通知正在进行的沙盒更换脑子
		EventBus.presets_reloaded.emit()
		
		var original_text = btn_save.text
		btn_save.text = "✔️ 热重载完毕！立即生效！"
		await get_tree().create_timer(1.5).timeout
		btn_save.text = original_text
