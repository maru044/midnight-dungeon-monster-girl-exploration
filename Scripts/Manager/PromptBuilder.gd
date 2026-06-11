extends Node

# ==============================================================================
# 提示词组装引擎 (PromptBuilder) - OpenAI 兼容格式版
# 职责：负责读取预定义的 Markdown 模块，并将它们按顺序拼接。
# 输出兼容 OpenAI Chat Completions 的消息数组 (role: system/user/assistant)。
# ==============================================================================

# 升级版本号，强制系统重新从 res:// 拷贝最新的设定档，覆盖旧的 user:// 缓存
const GAME_VERSION = "v1.1"
const RES_PROMPT_DIR = "res://Data/Prompts/"
var user_prompt_dir = "user://prompts/" + GAME_VERSION + "/"

func _ready() -> void:
	_ensure_user_prompts()

## 将 res:// 里的预设同步到 user:// 下以支持玩家修改
func _ensure_user_prompts() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("prompts"):
		dir.make_dir("prompts")
		
	if not dir.dir_exists("prompts/" + GAME_VERSION):
		dir.make_dir("prompts/" + GAME_VERSION)
		dir.make_dir("prompts/" + GAME_VERSION + "/Characters")
		
		# 仅在版本第一次启动时拷贝基础文件
		var files_to_copy = [
			"1_System_Intro.md",
			"2_World_Rules.md",
			"3_Format_Guidelines.md",
			"Characters/hakuri.md",
			"Characters/hiba.md",
			"Characters/shion.md"
		]
		
		for f in files_to_copy:
			if FileAccess.file_exists(RES_PROMPT_DIR + f):
				var content = FileAccess.get_file_as_string(RES_PROMPT_DIR + f)
				var out_file = FileAccess.open(user_prompt_dir + f, FileAccess.WRITE)
				if out_file:
					out_file.store_string(content)
					out_file.close()
		print("[PromptBuilder] 首次启动 " + GAME_VERSION + "，已将预设文件拷贝至沙盒。")

func _load_md(file_path: String) -> String:
	if FileAccess.file_exists(file_path):
		return FileAccess.get_file_as_string(file_path)
	else:
		push_error("[PromptBuilder] 找不到核心提示词模板: " + file_path)
		return ""

## 为全新遭遇构建最初的 LLM Context 数组
func build_initial_context(char_id: String) -> Array:
	var context_array = []
	
	# 1. 依次加载各部分的 Markdown 文件 (从支持读写的 user 目录读取)
	var intro = _load_md(user_prompt_dir + "1_System_Intro.md")
	var rules = _load_md(user_prompt_dir + "2_World_Rules.md")
	var character_card = _load_md(user_prompt_dir + "Characters/" + char_id + ".md")
	var format_guide = _load_md(user_prompt_dir + "3_Format_Guidelines.md")
	
	if character_card == "":
		push_error("[PromptBuilder] 严重错误：缺少角色设定卡 " + char_id)
		return context_array
		
	# 2. 将内容拼接为一个巨大的 System Prompt
	# 在兼容 OpenAI 的格式中，这些都作为第一条 "user" 消息（部分代理不支持 system）
	var full_system_prompt = intro + "\n\n" + rules + "\n\n" + character_card + "\n\n" + format_guide
	
	context_array.append({
		"role": "system",
		"content": full_system_prompt
	})
	
	# 3. 压入一条伪造的 Assistant 回复，用于锁定语气并接受设定
	# 【终极防穿帮】：在这里反复强调 Miku 只是后台，必须隔离。
	var ack_text = "OKnya！Miku作为后台管理员已经完全了解了所有规则和【" + char_id.to_upper() + "】的角色设定！我保证在进入沙盒后，前台的 <content> 绝对只出现【" + char_id.to_upper() + "】的剧情和台词，并采用客观的第三人称描写动作。请问现在要开始夜晚的遭遇战了吗？"
	context_array.append({
		"role": "assistant",
		"content": ack_text
	})
	
	return context_array

## 处理玩家新发送的消息，并在末尾挂载强制的标签劫持
func append_user_message_with_prefill(context_array: Array, user_text: String, char_id: String) -> Array:
	# 先压入玩家真实说的话
	context_array.append({
		"role": "user",
		"content": "{[Master最新行动/语言： " + user_text + " ]} ｝"
	})
	
	# 然后压入一段假的 assistant 预填充文本，强制模型从 thinking 开始续写
	# 【终极防穿帮】：在最后几个字再次按着模型的头，强迫它记住现在该扮演谁！
	var prefill_text = "</think>\n<thinking>\nOK，后台系统Miku上线！我要严格遵守隔离规则，接下来的正文内容必须完全交由【" + char_id.to_upper() + "】来扮演，除非Master明确呼叫系统管理员^_^。OK，Master刚才的行动是"
	context_array.append({
		"role": "assistant",
		"content": prefill_text
	})
	
	return context_array
