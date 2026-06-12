extends Node

# ==============================================================================
# 大语言模型通信客户端 (LLM_Client) - OpenAI Chat Completions 兼容版
# 支持 DeepSeek V4 与 GCLI 代理的 Gemini 模型。
# ==============================================================================

var http_request: HTTPRequest
var is_requesting: bool = false

func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.use_threads = true
	http_request.timeout = 90.0 # 设置 90 秒超时，防止玩家无限等待
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

## 发起非流式请求
func generate_content(context_array: Array) -> void:
	if is_requesting:
		push_warning("[LLM_Client] 正在请求中，请勿重复发送！")
		return
		
	if not GameManager.has_valid_api_key():
		EventBus.system_error_occurred.emit("请先在主界面配置并保存 API Key！")
		return
		
	is_requesting = true
	EventBus.llm_response_started.emit()
	
	# 获取当前激活的专区配置
	var cfg = GameManager.api_configs.get(GameManager.api_type, {})
	var api_url = cfg.get("url", "")
	var api_key = cfg.get("key", "")
	var api_model = cfg.get("model", "")
	var temp = cfg.get("temp", 1.0)
	var top_p = cfg.get("top_p", 0.9)
	
	# 统一使用 OpenAI 格式的头部
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	# 构建标准 Chat Completions 请求体
	var request_body = {
		"model": api_model,
		"messages": context_array,
		"temperature": float(temp),
		"top_p": float(top_p)
	}
	
	var json_body = JSON.stringify(request_body)
	var err = http_request.request(api_url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		is_requesting = false
		EventBus.system_error_occurred.emit("请求发送失败，网络错误代码: " + str(err))

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	is_requesting = false
	EventBus.llm_response_finished.emit()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var err_msg = "API 请求失败，HTTP状态码: " + str(response_code) + " (内部结果码: " + str(result) + ")"
		var error_body = body.get_string_from_utf8()
		push_error("[LLM_Client] 发生严重网络错误: ", err_msg)
		push_error("[LLM_Client] 服务器返回的错误信息: ", error_body)
		EventBus.system_error_occurred.emit(err_msg + "\n服务器原始返回体如下：\n" + error_body)
		return
		
	var response_text = body.get_string_from_utf8()
	var parsed_text = _extract_text_from_response(response_text)
	
	# 如果解析失败（报错或触发敏感词返回空文本），主动发射报错信号
	if parsed_text == "":
		EventBus.system_error_occurred.emit("大模型返回了空文本！导致解析失败的原始 API 报文如下：\n" + response_text)
		return
		
	# 正常情况：拼接预填充并交给解析器处理
	var char_id = GameManager.current_char_id
	var builder = get_node_or_null("/root/PromptBuilder")
	var prefill = builder.get_assistant_prefill(char_id) if builder else ""
	var final_text = prefill + parsed_text
	
	ResponseParser.parse_full_response(final_text)

## 解析标准 OpenAI 格式的返回 JSON
func _extract_text_from_response(json_string: String) -> String:
	var final_text = ""
	var json = JSON.new()
	if json.parse(json_string) == OK:
		if typeof(json.data) == TYPE_DICTIONARY:
			if json.data.has("error"):
				push_error("[LLM_Client] API 拒绝了请求，返回错误信息: ", json_string)
				return ""
				
			# OpenAI 格式: {"choices": [{"message": {"content": "..."}}]}
			if json.data.has("choices") and typeof(json.data.choices) == TYPE_ARRAY and json.data.choices.size() > 0:
				var choice = json.data.choices[0]
				if choice.has("message") and choice.message.has("content"):
					final_text = choice.message.content
				else:
					push_error("[LLM_Client] API 返回无 content", json_string)
			else:
				push_error("[LLM_Client] API 返回无 choices", json_string)
	else:
		push_error("[LLM_Client] API 返回非 JSON", json_string)
	return final_text
