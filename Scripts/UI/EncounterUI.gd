extends Control
class_name EncounterUI

# ==============================================================================
# 遭遇战交互界面 (EncounterUI)
# 职责：右侧主聊天面板，处理玩家输入，连接 LLM 网络层与存档管理器。
# ==============================================================================

var scroll_chat: ScrollContainer
var vbox_chat: VBoxContainer
var input_field: TextEdit
var btn_send: Button
var btn_toggle_think: Button
var panel_main: PanelContainer

var current_context: Array = []
var is_thinking_visible: bool = true
var is_waiting_for_llm: bool = false

# 临时缓存最新解析出的文本块
var latest_thinking_text: String = ""
var latest_commands_text: String = ""

func _ready() -> void:
	_build_ui()
	_connect_signals()

func _connect_signals() -> void:
	# 修复时序 Bug：监听遭遇战正式开始的信号
	EventBus.encounter_started.connect(_on_encounter_started)
	
	EventBus.llm_response_started.connect(_on_llm_started)
	EventBus.llm_response_finished.connect(_on_llm_finished)
	EventBus.system_error_occurred.connect(_on_system_error)
	EventBus.presets_reloaded.connect(_on_presets_reloaded)
	# 监听解析器的非流式抛出
	var parser = get_node_or_null("/root/ResponseParser")
	if parser:
		parser.content_extracted.connect(_on_content_extracted)
		parser.thinking_extracted.connect(_on_thinking_extracted)
		parser.commands_extracted.connect(_on_commands_extracted)
	else:
		push_error("[EncounterUI] 找不到 ResponseParser 单例！")

func _on_encounter_started(char_id: String) -> void:
	if char_id == "": return
	
	# 1. 尝试读取该角色专属存档
	var save_mgr = get_node_or_null("/root/SaveManager")
	var builder = get_node_or_null("/root/PromptBuilder")
	if save_mgr.has_save(char_id):
		current_context = save_mgr.load_history(char_id)
		_render_history()
		
		# 状态恢复：遍历历史记录，如果曾经输出过[开灯]或[上床]，则重塑视觉状态
		var has_lit = false
		var has_sex = false
		for msg in current_context:
			# 【致命 Bug 修复】：绝对不能直接搜 msg.content！因为最开始的 System Prompt 里包含了
			# “你必须输出 [上床] 标签” 的教学规则，直接搜会导致开局必定判定为上床！
			# 必须只在 Assistant 的回复中，专门去 <commands> 标签块里去扫描！
			if msg.has("role") and msg.role == "assistant":
				var c_start = msg.content.find("<commands>")
				var c_end = msg.content.find("</commands>")
				if c_start != -1 and c_end != -1:
					var cmds = msg.content.substr(c_start, c_end - c_start)
					if "[开灯]" in cmds: has_lit = true
					if "[上床]" in cmds: has_sex = true
		
		# 利用全局事件总线自动恢复光照与图片
		if has_sex:
			GameManager.current_phase = 3
			EventBus.visual_phase_changed.emit(3)
		elif has_lit:
			GameManager.current_phase = 2
			EventBus.visual_phase_changed.emit(2)
			
	else:
		# 初见该角色，构建初始预设
		current_context = builder.build_initial_context(char_id)
		_add_system_message("在深邃的夜色中，你用手电筒偶然照亮了前方的 " + char_id.to_upper() + " ... 等待你的第一步行动。")

## ---------------------------------------------------------
## UI 构建
## ---------------------------------------------------------

func _build_ui() -> void:
	# 设置自身占据屏幕右侧
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -1312 # 1920 - 608(立绘宽度) = 1312
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	
	panel_main = PanelContainer.new()
	panel_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb_main = StyleBoxFlat.new()
	sb_main.bg_color = Color(1.0, 1.0, 1.0, 1.0) # 提供实色底板让 Shader 生效
	sb_main.corner_radius_top_left = 30
	sb_main.corner_radius_bottom_left = 30
	sb_main.border_width_left = 2
	sb_main.border_color = Color(0.3, 0.6, 0.9, 0.5)
	panel_main.add_theme_stylebox_override("panel", sb_main)
	
	# 应用高级毛玻璃与颗粒噪声 Shader
	var mat_main = ShaderMaterial.new()
	mat_main.shader = load("res://Shaders/frosted_glass_noise.gdshader")
	panel_main.material = mat_main
	add_child(panel_main)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel_main.add_child(margin)
	
	var vbox_root = VBoxContainer.new()
	vbox_root.add_theme_constant_override("separation", 20)
	margin.add_child(vbox_root)
	
	# 顶部导航栏 (带斜线网格磨砂玻璃)
	var top_panel = PanelContainer.new()
	var sb_top = StyleBoxFlat.new()
	sb_top.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	sb_top.corner_radius_top_left = 15; sb_top.corner_radius_bottom_right = 15; sb_top.corner_radius_top_right = 15; sb_top.corner_radius_bottom_left = 15
	top_panel.add_theme_stylebox_override("panel", sb_top)
	
	var mat_top = ShaderMaterial.new()
	mat_top.shader = load("res://Shaders/grid_frosted_glass.gdshader")
	top_panel.material = mat_top
	vbox_root.add_child(top_panel)
	
	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 15); top_margin.add_theme_constant_override("margin_right", 15)
	top_margin.add_theme_constant_override("margin_top", 10); top_margin.add_theme_constant_override("margin_bottom", 10)
	top_panel.add_child(top_margin)
	
	var top_hbox = HBoxContainer.new()
	top_margin.add_child(top_hbox)
	
	var btn_home = _create_btn("🏠 撤退 (返回主菜单)", Color(0.8, 0.3, 0.4))
	btn_home.pressed.connect(_on_btn_home_pressed)
	top_hbox.add_child(btn_home)
	
	var btn_new_chat = _create_btn("✨ 开始新聊天", Color(0.2, 0.6, 0.4))
	btn_new_chat.pressed.connect(_on_btn_new_chat_pressed)
	top_hbox.add_child(btn_new_chat)
	
	var btn_save = _create_btn("💾 历史档案室", Color(0.8, 0.6, 0.2))
	btn_save.pressed.connect(_on_btn_save_pressed)
	top_hbox.add_child(btn_save)
	
	var btn_editor = _create_btn("⚙️ 预设编辑器", Color(0.3, 0.3, 0.4))
	btn_editor.pressed.connect(func():
		var editor = PromptEditorUI.new()
		add_child(editor)
		editor.popup_centered()
	)
	top_hbox.add_child(btn_editor)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)
	
	btn_toggle_think = _create_btn("🔍 思维链: ON" if is_thinking_visible else "🔍 思维链: OFF", Color(0.4, 0.4, 0.6))
	btn_toggle_think.pressed.connect(func():
		is_thinking_visible = !is_thinking_visible
		btn_toggle_think.text = "🔍 思维链: ON" if is_thinking_visible else "🔍 思维链: OFF"
		_refresh_thinking_visibility()
	)
	top_hbox.add_child(btn_toggle_think)
	
	# 聊天滚动区
	scroll_chat = ScrollContainer.new()
	scroll_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_chat.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox_root.add_child(scroll_chat)
	
	vbox_chat = VBoxContainer.new()
	vbox_chat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_chat.add_theme_constant_override("separation", 25)
	scroll_chat.add_child(vbox_chat)
	
	# 底部输入区
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 20)
	bottom_hbox.custom_minimum_size = Vector2(0, 80)
	vbox_root.add_child(bottom_hbox)
	
	input_field = TextEdit.new()
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.placeholder_text = "在此输入你的动作或对话... (支持多行)"
	input_field.add_theme_font_size_override("font_size", 22)
	var sb_input = StyleBoxFlat.new()
	sb_input.bg_color = Color(0.05, 0.06, 0.08, 0.4) # 输入框也降透明度
	sb_input.corner_radius_top_left = 15; sb_input.corner_radius_bottom_right = 15; sb_input.corner_radius_top_right = 15; sb_input.corner_radius_bottom_left = 15
	sb_input.content_margin_left = 20; sb_input.content_margin_top = 20
	# 霓虹发光边框
	sb_input.border_width_left = 2; sb_input.border_width_top = 2; sb_input.border_width_right = 2; sb_input.border_width_bottom = 2
	sb_input.border_color = Color(0.0, 0.9, 1.0, 0.8)
	sb_input.shadow_size = 15
	sb_input.shadow_color = Color(0.0, 0.9, 1.0, 0.3)
	input_field.add_theme_stylebox_override("normal", sb_input)
	bottom_hbox.add_child(input_field)
	
	btn_send = Button.new()
	btn_send.text = "发 送\nSEND"
	btn_send.add_theme_font_size_override("font_size", 22)
	btn_send.custom_minimum_size = Vector2(120, 0)
	
	var sb_send = StyleBoxFlat.new()
	sb_send.bg_color = Color(0.1, 0.5, 0.7, 0.9)
	sb_send.corner_radius_top_left = 15; sb_send.corner_radius_bottom_right = 15; sb_send.corner_radius_top_right = 15; sb_send.corner_radius_bottom_left = 15
	sb_send.border_width_left = 2; sb_send.border_width_top = 2; sb_send.border_width_right = 2; sb_send.border_width_bottom = 2
	sb_send.border_color = Color(0.0, 0.9, 1.0, 0.9)
	sb_send.shadow_size = 18
	sb_send.shadow_color = Color(0.0, 0.9, 1.0, 0.5)
	
	var sb_send_disabled = sb_send.duplicate()
	sb_send_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	sb_send_disabled.border_color = Color(0.4, 0.4, 0.4, 0.5)
	sb_send_disabled.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	
	btn_send.add_theme_stylebox_override("normal", sb_send)
	btn_send.add_theme_stylebox_override("disabled", sb_send_disabled)
	btn_send.pressed.connect(_on_btn_send_pressed)
	bottom_hbox.add_child(btn_send)

func _create_btn(txt: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 18)
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 10; sb.corner_radius_bottom_right = 10; sb.corner_radius_top_right = 10; sb.corner_radius_bottom_left = 10
	btn.add_theme_stylebox_override("normal", sb)
	
	var sb_disabled = sb.duplicate()
	sb_disabled.bg_color = color.darkened(0.6)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	return btn

## ---------------------------------------------------------
## 交互逻辑
## ---------------------------------------------------------

func _on_btn_send_pressed() -> void:
	if is_waiting_for_llm: return
	
	var txt = input_field.text.strip_edges()
	var builder = get_node_or_null("/root/PromptBuilder")
	var llm = get_node_or_null("/root/LLM_Client")
	
	if txt != "":
		input_field.text = ""
		if builder and llm:
			current_context = builder.append_user_message_with_prefill(current_context, txt, GameManager.current_char_id)
			# 获取刚才压入的 user 消息索引（倒数第二条，因为最后一条是 prefill）
			var user_idx = current_context.size() - 2
			_add_message_bubble("Master", txt, true, "", user_idx)
			llm.generate_content(current_context)
	else:
		# 当输入框为空，且最后一条消息是 user 时，作为【报错重试】功能
		if current_context.size() > 0 and current_context[-1].has("role") and current_context[-1].role == "user":
			if builder and llm:
				var char_id = GameManager.current_char_id
				var prefill_text = builder.get_assistant_prefill(char_id)
				current_context.append({
					"role": "assistant",
					"content": prefill_text
				})
				llm.generate_content(current_context)

func _on_llm_started() -> void:
	is_waiting_for_llm = true
	btn_send.disabled = true
	btn_send.text = "思考中..."

func _on_llm_finished() -> void:
	is_waiting_for_llm = false
	btn_send.disabled = false
	btn_send.text = "发 送\nSEND"

func _on_system_error(err_msg: String) -> void:
	is_waiting_for_llm = false
	btn_send.disabled = false
	btn_send.text = "发 送\nSEND"
	_add_system_message("【系统错误】" + err_msg)
	
	# 【修复因报错导致进度卡死的 BUG】
	# 如果发生错误，只弹出大模型的预填充占位符，保留玩家的 User 消息！
	# 这样玩家只需再次点击“发送”按钮，系统就会重新拼接预填充并重试。
	if current_context.size() >= 1 and current_context[-1].has("role") and current_context[-1].role == "assistant":
		if "</think>" in current_context[-1].content:
			current_context.pop_back() # 仅弹出 Assistant Prefill

func _on_thinking_extracted(think_text: String) -> void:
	latest_thinking_text = think_text

func _on_commands_extracted(cmds_text: String) -> void:
	latest_commands_text = cmds_text

func _on_content_extracted(content_text: String) -> void:
	# 同步记录到当前 Context 数组的最后 (拼接之前劫持的 prefill)
	# 【BUG修复】：直接使用 '=' 覆盖原有的占位 prefill！
	# 因为 latest_thinking_text 中已经包含了解析器拼上的 prefill 文本。如果用 '+=' 会导致俄罗斯套娃。
	if current_context.size() > 0 and current_context[-1].has("role") and current_context[-1].role == "assistant":
		var full_reconstructed_text = "</think>\n<thinking>\n" + latest_thinking_text + "\n</thinking>\n<commands>" + latest_commands_text + "</commands>\n<content>\n" + content_text + "\n</content>"
		current_context[-1].content = full_reconstructed_text
		
		# 收到完整回复，此时 context_array 已经组装好，传递 index = size - 1 给重 Roll 按钮
		_add_message_bubble(GameManager.current_char_id.to_upper(), content_text, false, latest_thinking_text, current_context.size() - 1)
	
	latest_thinking_text = ""
	latest_commands_text = ""
	
	# 自动保存进度
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr: save_mgr.save_history(GameManager.current_char_id, current_context)

func _on_btn_home_pressed() -> void:
	EventBus.encounter_ended.emit()
	queue_free() # 这里我们假设主菜单在下层，直接摧毁遭遇战 UI 即可

func _on_btn_new_chat_pressed() -> void:
	# 清空聊天内容，重新构建预设
	for child in vbox_chat.get_children():
		child.queue_free()
		
	var builder = get_node_or_null("/root/PromptBuilder")
	if builder:
		current_context = builder.build_initial_context(GameManager.current_char_id)
		_add_system_message("在深邃的夜色中，你用手电筒偶然照亮了前方的 " + GameManager.current_char_id.to_upper() + " ... 等待你的第一步行动。")
		
		# 重新发送 encounter_started 信号，强制 GameManager 重置阶段标志并让立绘重新抽卡加载
		EventBus.encounter_started.emit(GameManager.current_char_id)

func _on_btn_save_pressed() -> void:
	var save_menu = SaveLoadMenuUI.new(self, GameManager.current_char_id)
	add_child(save_menu)
	save_menu.open_panel()

func _on_presets_reloaded() -> void:
	# 核心热重载逻辑：直接更换当前大模型的脑子 (System Prompt)
	if current_context.size() >= 2:
		var builder = get_node_or_null("/root/PromptBuilder")
		if builder:
			# 生成一个包含最新规则的新初始 Context
			var fresh_context = builder.build_initial_context(GameManager.current_char_id)
			if fresh_context.size() >= 2:
				# 偷天换日：替换掉旧的全局设定和确认回应，保留后续的聊天记录！
				current_context[0] = fresh_context[0]
				current_context[1] = fresh_context[1]
				_add_system_message("⚙️ 检测到后台设定变更，系统逻辑已无缝热重载。下一回合生效。")

func load_context_from_slot(slot_name: String) -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		var ctx = save_mgr.load_slot(GameManager.current_char_id, slot_name)
		if ctx.size() > 0:
			current_context = ctx
			# 清空旧面板
			for child in vbox_chat.get_children():
				child.queue_free()
			_render_history()
			
			# 恢复视觉阶段状态
			var has_lit = false
			var has_sex = false
			for msg in current_context:
				if msg.has("role") and msg.role == "assistant":
					var c_start = msg.content.find("<commands>")
					var c_end = msg.content.find("</commands>")
					if c_start != -1 and c_end != -1:
						var cmds = msg.content.substr(c_start, c_end - c_start)
						if "[开灯]" in cmds: has_lit = true
						if "[上床]" in cmds: has_sex = true
			
			# 【终极修复】：在回滚任何状态之前，必须先把全局状态机清零。
			# 否则，如果从色色(3)回滚到开灯(2)，发射[开灯]信号时，GameManager会因为 3 > 2 而拒绝执行！
			GameManager.current_phase = 1
			
			if has_sex:
				EventBus.llm_tag_detected.emit("[上床]")
			elif has_lit:
				EventBus.llm_tag_detected.emit("[开灯]")
			else:
				EventBus.visual_phase_changed.emit(1)

## ---------------------------------------------------------
## 气泡渲染
## ---------------------------------------------------------

func _add_message_bubble(sender: String, text: String, is_player: bool, think_txt: String = "", msg_index: int = -1) -> void:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.corner_radius_top_left = 15; sb.corner_radius_bottom_right = 15; sb.corner_radius_top_right = 15; sb.corner_radius_bottom_left = 15
	sb.content_margin_left = 25; sb.content_margin_right = 25; sb.content_margin_top = 20; sb.content_margin_bottom = 20
	
	if is_player:
		sb.bg_color = Color(0.2, 0.4, 0.6, 0.25) # 极低透明度，让水波纹透出来
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		sb.bg_color = Color(0.1, 0.1, 0.15, 0.35) # 极低透明度，让水波纹透出来
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
	panel.add_theme_stylebox_override("panel", sb)
	vbox_chat.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var top_bar = HBoxContainer.new()
	vbox.add_child(top_bar)

	var name_lbl = Label.new()
	name_lbl.text = sender
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4) if not is_player else Color(0.8, 0.9, 1.0))
	top_bar.add_child(name_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	
	if not is_player and msg_index != -1:
		var btn_reroll = Button.new()
		btn_reroll.text = "🔄 返回此层并重写"
		var sb_reroll = StyleBoxFlat.new()
		sb_reroll.bg_color = Color(0.8, 0.4, 0.2, 0.8)
		sb_reroll.corner_radius_top_left = 8; sb_reroll.corner_radius_bottom_right = 8; sb_reroll.corner_radius_top_right = 8; sb_reroll.corner_radius_bottom_left = 8
		btn_reroll.add_theme_stylebox_override("normal", sb_reroll)
		btn_reroll.pressed.connect(func(): _on_btn_rollback_pressed(msg_index))
		top_bar.add_child(btn_reroll)
		
	var rtb = RichTextLabel.new()
	
	if is_player and msg_index != -1:
		var btn_edit = Button.new()
		btn_edit.text = "✏️ 修改发言"
		var sb_edit = StyleBoxFlat.new()
		sb_edit.bg_color = Color(0.4, 0.6, 0.8, 0.8)
		sb_edit.corner_radius_top_left = 8; sb_edit.corner_radius_bottom_right = 8; sb_edit.corner_radius_top_right = 8; sb_edit.corner_radius_bottom_left = 8
		btn_edit.add_theme_stylebox_override("normal", sb_edit)
		btn_edit.pressed.connect(func(): _on_btn_edit_user_msg_pressed(vbox, rtb, msg_index))
		top_bar.add_child(btn_edit)
	rtb.bbcode_enabled = true
	rtb.fit_content = true
	rtb.selection_enabled = true
	rtb.text = text
	
	var custom_font = load("res://Fonts/SmileySans-Oblique.otf")
	if custom_font:
		rtb.add_theme_font_override("normal_font", custom_font)
		rtb.add_theme_font_override("bold_font", custom_font)
		rtb.add_theme_font_override("italics_font", custom_font)
		rtb.add_theme_font_override("bold_italics_font", custom_font)
		
	rtb.add_theme_font_size_override("normal_font_size", 22)
	rtb.add_theme_font_size_override("bold_font_size", 26)
	rtb.add_theme_font_size_override("italics_font_size", 22)
	rtb.add_theme_font_size_override("bold_italics_font_size", 26)
	vbox.add_child(rtb)
	
	if think_txt != "":
		var think_rtb = RichTextLabel.new()
		think_rtb.bbcode_enabled = true
		think_rtb.fit_content = true
		think_rtb.selection_enabled = true
		think_rtb.text = "[color=#888888][i]<Miku 的思维链>\n" + think_txt + "[/i][/color]"
		think_rtb.add_theme_font_size_override("normal_font_size", 18)
		think_rtb.add_to_group("thinking_nodes") # 方便后续一键显隐
		think_rtb.visible = is_thinking_visible
		vbox.add_child(think_rtb)
		
	# 滚动到底部
	await get_tree().process_frame
	scroll_chat.scroll_vertical = int(scroll_chat.get_v_scroll_bar().max_value)

func _add_system_message(text: String) -> void:
	var rtb = RichTextLabel.new()
	rtb.bbcode_enabled = true
	rtb.fit_content = true
	rtb.selection_enabled = true
	rtb.text = "[center][color=#808080]—— " + text + " ——[/color][/center]"
	rtb.add_theme_font_size_override("normal_font_size", 16)
	vbox_chat.add_child(rtb)

func _refresh_thinking_visibility() -> void:
	var nodes = get_tree().get_nodes_in_group("thinking_nodes")
	for n in nodes:
		if n is Control: n.visible = is_thinking_visible

func _on_btn_edit_user_msg_pressed(vbox: VBoxContainer, rtb: RichTextLabel, msg_index: int) -> void:
	if is_waiting_for_llm: return
	
	rtb.visible = false
	var edit_container = VBoxContainer.new()
	vbox.add_child(edit_container)
	
	var text_edit = TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, 100)
	text_edit.add_theme_font_size_override("font_size", 22)
	
	# 脱壳：提取原本纯净的用户输入
	var raw_msg = current_context[msg_index].content
	var clean_txt = raw_msg.replace("{[Master最新行动/语言： ", "").replace(" ]} ｝", "").strip_edges()
	text_edit.text = clean_txt
	edit_container.add_child(text_edit)
	
	var btn_save_edit = Button.new()
	btn_save_edit.text = "💾 保存修改并覆盖当前记录"
	var sb_save = StyleBoxFlat.new()
	sb_save.bg_color = Color(0.2, 0.6, 0.4, 0.9)
	sb_save.corner_radius_top_left = 8; sb_save.corner_radius_bottom_right = 8; sb_save.corner_radius_top_right = 8; sb_save.corner_radius_bottom_left = 8
	btn_save_edit.add_theme_stylebox_override("normal", sb_save)
	btn_save_edit.pressed.connect(func():
		var new_text = text_edit.text.strip_edges()
		if new_text != "":
			# 重塑：重新套上底层格式锁并更新数组
			current_context[msg_index].content = "{[Master最新行动/语言： " + new_text + " ]} ｝"
			
			# 自动保存进度
			var save_mgr = get_node_or_null("/root/SaveManager")
			if save_mgr: save_mgr.save_history(GameManager.current_char_id, current_context)
			
			# 恢复 UI 显示
			rtb.text = new_text
			rtb.visible = true
			edit_container.queue_free()
	)
	edit_container.add_child(btn_save_edit)

func _on_btn_rollback_pressed(index: int) -> void:
	if is_waiting_for_llm: return
	
	# 1. 截断数组：丢弃选定气泡本身以及之后的所有对话记录
	current_context.resize(index)
	
	# 2. 重新拼接纯净的 Prefill
	var char_id = GameManager.current_char_id
	var builder = get_node_or_null("/root/PromptBuilder")
	var prefill_text = builder.get_assistant_prefill(char_id) if builder else ""
	current_context.append({
		"role": "assistant",
		"content": prefill_text
	})
	
	# 3. 视觉状态恢复 (遍历截断后的消息)
	var has_lit = false
	var has_sex = false
	for msg in current_context:
		if msg.has("role") and msg.role == "assistant":
			var c_start = msg.content.find("<commands>")
			var c_end = msg.content.find("</commands>")
			if c_start != -1 and c_end != -1:
				var cmds = msg.content.substr(c_start, c_end - c_start)
				if "[开灯]" in cmds: has_lit = true
				if "[上床]" in cmds: has_sex = true
	
	GameManager.current_phase = 1 # 强制同步状态机
	
	if has_sex:
		GameManager.current_phase = 3
		EventBus.visual_phase_changed.emit(3)
	elif has_lit:
		GameManager.current_phase = 2
		EventBus.visual_phase_changed.emit(2)
	else:
		EventBus.visual_phase_changed.emit(1)
		
	# 4. 保存截断后的存档
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr: save_mgr.save_history(GameManager.current_char_id, current_context)
	
	# 5. UI 清理与重绘
	for child in vbox_chat.get_children():
		child.queue_free()
	_render_history()
	
	# 6. 发送重新生成的请求
	var llm = get_node_or_null("/root/LLM_Client")
	if llm: llm.generate_content(current_context)


## 历史记录恢复渲染
func _render_history() -> void:
	_add_system_message("档案读取完毕。你回到了 " + GameManager.current_char_id.to_upper() + " 身边。")
	for i in range(current_context.size()):
		var msg = current_context[i]
		if msg.role == "user" and "{[Master" in msg.content:
			# 提取玩家原话
			var txt = msg.content.replace("{[Master最新行动/语言： ", "").replace(" ]} ｝", "").strip_edges()
			_add_message_bubble("Master", txt, true, "", i)
		elif msg.role == "assistant":
			# 跳过系统自动拼接的初始化预设回复，避免脏乱UI
			if "OKnya！Miku作为后台管理员" in msg.content: continue
			# 跳过悬空的预填充块 (当玩家正在等待模型回复，或者刚刚 Rollback 后)
			if "OK，后台系统Miku上线" in msg.content and not "<content>" in msg.content: continue
			
			var parser = get_node_or_null("/root/ResponseParser")
			if parser:
				# 利用正则提取历史记录中的思维与正文
				var t_match = parser.regex_thinking.search(msg.content)
				var c_match = parser.regex_content.search(msg.content)
				var t_txt = t_match.get_string(1).strip_edges() if t_match else ""
				var c_txt = c_match.get_string(1).strip_edges() if c_match else msg.content.replace("</think>", "").replace("<thinking>", "")
				_add_message_bubble(GameManager.current_char_id.to_upper(), c_txt, false, t_txt, i)
