class_name FontManager
extends RefCounted

static var loaded_fonts: Dictionary = {}
static var font_requests: Array = []
static var refresh_callback: Callable

static func register_font(name: String, src: String, weight: String = "400") -> void:
	var font_info = {
		"name": name,
		"src": src,
		"weight": weight,
		"font_resource": null
	}
	font_requests.append(font_info)

static func load_all_fonts() -> void:
	if font_requests.size() == 0:
		return
	
	for font_info in font_requests:
		load_font(font_info)


static func load_font(font_info: Dictionary) -> void:
	var src = font_info["src"]
	
	if src.begins_with("http://") or src.begins_with("https://"):
		load_web_font(font_info)

static func load_web_font(font_info: Dictionary) -> void:
	var src = font_info["src"]
	var name = font_info["name"]
	
	var http_request = HTTPRequest.new()
	var temp_parent = Node.new()
	Engine.get_main_loop().root.add_child(temp_parent)
	temp_parent.add_child(http_request)
	
	http_request.timeout = 30.0
	
	http_request.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code >= 200 and response_code < 300:

			if body.size() > 0:
				var font = FontFile.new()
				font.data = body
				font_info["font_resource"] = font
				loaded_fonts[name] = font
				
				# Trigger font refresh if callback is available
				if refresh_callback.is_valid():
					refresh_callback.call(name)
			else:
				print("FontManager: Empty font data received for ", name)
		else:
			print("FontManager: Failed to load font ", name, " - HTTP ", response_code)
		
		if is_instance_valid(temp_parent):
			temp_parent.queue_free()
	)
	
	var headers = PackedStringArray()
	headers.append("User-Agent: " + UserAgent.get_user_agent())
	
	http_request.request(src, headers)

static func clear_fonts() -> void:
	loaded_fonts.clear()
	font_requests.clear()
	refresh_callback = Callable()

static func get_font(family_name: String) -> Font:
	if family_name == "sans-serif":
		var sys_font = SystemFont.new()
		sys_font.font_names = ["sans-serif"]
		return sys_font
	elif family_name == "serif":
		var sys_font = SystemFont.new()
		sys_font.font_names = ["serif"]
		return sys_font
	elif family_name == "monospace":
		var sys_font = SystemFont.new()
		sys_font.font_names = ["Consolas", "monospace"]
		return sys_font
	elif loaded_fonts.has(family_name):
		return loaded_fonts[family_name]
	else:
		# Fallback to system font
		var sys_font = SystemFont.new()
		sys_font.font_names = [family_name]
		return sys_font

static func set_refresh_callback(callback: Callable) -> void:
	refresh_callback = callback
