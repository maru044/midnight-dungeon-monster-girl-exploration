extends Node

# ==============================================================================
# 非流式响应解析器 (ResponseParser)
# 职责：在收到 LLM 完整回复后，一次性分析并分离出 <thinking>、<commands> 和 <content>。
# 并将捕获到的特定指令通过 EventBus 分发。
# ==============================================================================

signal thinking_extracted(text: String)
signal commands_extracted(text: String)
signal content_extracted(text: String)

var regex_thinking: RegEx
var regex_commands: RegEx
var regex_content: RegEx

func _ready() -> void:
	regex_thinking = RegEx.new()
	regex_thinking.compile("(?s)<thinking>(.*?)</thinking>")
	
	regex_commands = RegEx.new()
	regex_commands.compile("(?s)<commands>(.*?)</commands>")
	
	regex_content = RegEx.new()
	regex_content.compile("(?s)<content>(.*?)</content>")

## 处理从 LLM 传来的完整文本
func parse_full_response(full_text: String) -> void:
	# 增强容错机制：处理 LLM 忘记写闭合标签的情况
	var thinking_text = ""
	var cmds_text = ""
	var content_text = ""
	
	# 1. 提取 Thinking 区域
	var thinking_match = regex_thinking.search(full_text)
	if thinking_match:
		thinking_text = thinking_match.get_string(1).strip_edges()
	else:
		# 容错：如果有 <thinking> 但没闭合，或者碰到了 <content> 才被截断
		var t_start = full_text.find("<thinking>")
		var c_start = full_text.find("<content>")
		if t_start != -1:
			if c_start != -1 and c_start > t_start:
				thinking_text = full_text.substr(t_start + 10, c_start - t_start - 10).strip_edges()
			else:
				thinking_text = full_text.substr(t_start + 10).strip_edges()
				
	# 清理可能混入的 commands 标签
	var t_cmd_idx = thinking_text.find("<commands>")
	if t_cmd_idx != -1:
		thinking_text = thinking_text.substr(0, t_cmd_idx).strip_edges()

	thinking_extracted.emit(thinking_text if thinking_text != "" else "（本次回复无思维过程）")

	# 2. 提取 Commands 区块
	var commands_match = regex_commands.search(full_text)
	if commands_match:
		cmds_text = commands_match.get_string(1)
		_check_and_fire_tags(cmds_text)
	else:
		var cmd_start = full_text.find("<commands>")
		var cmd_end = full_text.find("</commands>")
		if cmd_start != -1 and cmd_end != -1:
			cmds_text = full_text.substr(cmd_start + 10, cmd_end - cmd_start - 10)
			_check_and_fire_tags(cmds_text)
			
	commands_extracted.emit(cmds_text)

	# 3. 提取 Content 区域
	var content_match = regex_content.search(full_text)
	if content_match:
		content_text = content_match.get_string(1).strip_edges()
	else:
		var c_start = full_text.find("<content>")
		if c_start != -1:
			content_text = full_text.substr(c_start + 9).replace("</content>", "").strip_edges()
		else:
			# 极端容错：大模型彻底忘记了所有标签，那我们就假设整个文本都是说话内容，但要把思考部分过滤掉
			var fallback = full_text
			if thinking_text != "":
				fallback = fallback.replace(thinking_text, "")
			fallback = fallback.replace("<thinking>", "").replace("</thinking>", "")
			fallback = fallback.replace("<commands>", "").replace("</commands>", "")
			fallback = fallback.replace("<content>", "").replace("</content>", "")
			content_text = fallback.strip_edges()
			
	content_extracted.emit(content_text)

## 检查并触发系统级标签
func _check_and_fire_tags(cmds_text: String) -> void:
	if "[开灯]" in cmds_text:
		EventBus.llm_tag_detected.emit("[开灯]")
		
	if "[上床]" in cmds_text:
		EventBus.llm_tag_detected.emit("[上床]")
