extends Node

# ==============================================================================
# 全局状态管理器 (GameManager)
# 职责：存储游戏运行时的生命周期数据，以及 API 的配置信息。
# ==============================================================================

enum VisualPhase {
	PHASE_1_FLASHLIGHT = 1, 
	PHASE_2_NORMAL = 2,     
	PHASE_3_SEX = 3         
}

# 全局运行状态
var current_char_id: String = ""
var current_phase: int = VisualPhase.PHASE_1_FLASHLIGHT

# API 配置状态 (支持 DeepSeek 与 GCLI Gemini)
var api_type: String = "gemini"

var api_configs: Dictionary = {
	"gemini": {
		"url": "https://gcli.ggchan.dev/v1/chat/completions",
		"key": "",
		"model": "gemini-3.1-pro-preview",
		"temp": 1.5,
		"top_p": 0.88
	},
	"deepseek": {
		"url": "https://api.deepseek.com/chat/completions",
		"key": "",
		"model": "deepseek-v4-flash",
		"temp": 1.0,
		"top_p": 0.90
	}
}

const CONFIG_PATH = "user://api_config.json"

func _ready() -> void:
	load_api_config()
	EventBus.llm_tag_detected.connect(_on_llm_tag_detected)
	EventBus.encounter_started.connect(_on_encounter_started)
	EventBus.encounter_ended.connect(_on_encounter_ended)

## ---------------------------------------------------------
## 事件响应逻辑
## ---------------------------------------------------------

func _on_encounter_started(char_id: String) -> void:
	current_char_id = char_id
	current_phase = VisualPhase.PHASE_1_FLASHLIGHT
	EventBus.visual_phase_changed.emit(current_phase)

func _on_encounter_ended() -> void:
	current_char_id = ""
	current_phase = VisualPhase.PHASE_1_FLASHLIGHT

func _on_llm_tag_detected(tag: String) -> void:
	if tag == "[开灯]":
		if current_phase < VisualPhase.PHASE_2_NORMAL:
			current_phase = VisualPhase.PHASE_2_NORMAL
			EventBus.visual_phase_changed.emit(current_phase)
			
	elif tag == "[上床]":
		if current_phase < VisualPhase.PHASE_3_SEX:
			current_phase = VisualPhase.PHASE_3_SEX
			EventBus.visual_phase_changed.emit(current_phase)

## ---------------------------------------------------------
## 配置存取接口
## ---------------------------------------------------------

func save_api_config(type: String, url: String, key: String, model: String, temp: float, top_p: float) -> void:
	api_type = type
	api_configs[type] = {
		"url": url,
		"key": key,
		"model": model,
		"temp": temp,
		"top_p": top_p
	}
	
	var data = {
		"api_type": api_type,
		"configs": api_configs
	}
	
	var f = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	EventBus.api_key_updated.emit(key)

func load_api_config() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var content = FileAccess.get_file_as_string(CONFIG_PATH)
		var json = JSON.new()
		if json.parse(content) == OK and typeof(json.data) == TYPE_DICTIONARY:
			api_type = json.data.get("api_type", "gemini")
			var saved_configs = json.data.get("configs", {})
			# 合并保存的配置，防止缺少字段
			for k in saved_configs.keys():
				if api_configs.has(k):
					for field in saved_configs[k].keys():
						api_configs[k][field] = saved_configs[k][field]
			
func has_valid_api_key() -> bool:
	var cfg = api_configs.get(api_type, {})
	var key = cfg.get("key", "")
	return key.strip_edges() != ""
