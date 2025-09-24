class_name FontCacheManager
extends RefCounted

# Cache for styled text to avoid repeated BBCode generation
static var text_style_cache = {}

# Cache for font applications
static var font_application_cache = {}

# Maximum cache size
static var MAX_CACHE_SIZE = 300

static var cache_hits = 0
static var cache_misses = 0

static func get_cached_styled_text(element: HTMLParser.HTMLElement, styles: Dictionary, parser, text_override: String = "") -> String:
	var cache_key = generate_text_style_key(element, styles, text_override)
	
	if text_style_cache.has(cache_key):
		cache_hits += 1
		return text_style_cache[cache_key]
	
	cache_misses += 1
	
	# Generate styled text
	var text = text_override if text_override != "" else (element.get_preserved_text() if element.tag_name == "pre" else element.get_bbcode_formatted_text(parser))
	var styled_text = generate_styled_text_direct(text, styles)
	
	# Cache management
	if text_style_cache.size() >= MAX_CACHE_SIZE:
		clear_oldest_entries(text_style_cache, MAX_CACHE_SIZE / 4.0)
	
	text_style_cache[cache_key] = styled_text
	return styled_text

static func generate_text_style_key(element: HTMLParser.HTMLElement, styles: Dictionary, text_override: String) -> String:
	var components = []
	
	# Text content hash - normalize whitespace for better cache hits
	var text = text_override if text_override != "" else element.text_content
	var normalized_text = text.strip_edges().replace("\n", " ").replace("\t", " ")
	while "  " in normalized_text:
		normalized_text = normalized_text.replace("  ", " ")
	components.append("text:" + str(normalized_text.hash()))
	
	# Style properties that affect text appearance (sorted for consistency)
	var text_style_props = ["color", "font-bold", "font-italic", "underline", "font-mono", "text-align", "font-family", "font-size"]
	text_style_props.sort()
	
	for prop in text_style_props:
		if styles.has(prop):
			components.append(prop + ":" + str(styles[prop]))
	
	# Element type affects BBCode generation (but group similar elements)
	var element_group = element.tag_name
	if element.tag_name in ["h1", "h2", "h3", "h4", "h5", "h6"]:
		element_group = "heading"
	elif element.tag_name in ["b", "i", "u", "strong", "em"]:
		element_group = "inline_text"
	
	components.append("tag:" + element_group)
	
	return "_".join(components)

static func generate_styled_text_direct(text: String, styles: Dictionary) -> String:
	var has_existing_bbcode = text.contains("[url=") or text.contains("[color=")
	
	# Apply color
	var color_tag = ""
	if not has_existing_bbcode and styles.has("color"):
		var color = styles["color"] as Color
		if color == Color.BLACK and StyleManager.body_text_color != Color.BLACK:
			color = StyleManager.body_text_color
		color_tag = "[color=#%s]" % color.to_html(false)
	elif not has_existing_bbcode and StyleManager.body_text_color != Color.BLACK:
		color_tag = "[color=#%s]" % StyleManager.body_text_color.to_html(false)

	# Apply text styling (but not for text with existing BBCode)
	var bold_open = ""
	var bold_close = ""
	if not has_existing_bbcode and styles.has("font-bold") and styles["font-bold"]:
		bold_open = "[b]"
		bold_close = "[/b]"
	
	var italic_open = ""
	var italic_close = ""
	if not has_existing_bbcode and styles.has("font-italic") and styles["font-italic"]:
		italic_open = "[i]"
		italic_close = "[/i]"
	
	var underline_open = ""
	var underline_close = ""
	if not has_existing_bbcode and styles.has("underline") and styles["underline"]:
		underline_open = "[u]"
		underline_close = "[/u]"
	
	# Apply monospace font
	var mono_open = ""
	var mono_close = ""
	if styles.has("font-mono") and styles["font-mono"]:
		# If font-family is already monospace, just use BBCode for styling
		if not (styles.has("font-family") and styles["font-family"] == "monospace"):
			mono_open = "[code]"
			mono_close = "[/code]"
	
	# Construct final text
	var styled_text = "%s%s%s%s%s%s%s%s%s%s%s" % [
		color_tag,
		bold_open,
		italic_open,
		underline_open,
		mono_open,
		text,
		mono_close,
		underline_close,
		italic_close,
		bold_close,
		"[/color]" if color_tag.length() > 0 else "",
	]
	
	return styled_text

static func should_skip_font_application(_label: Control, styles: Dictionary) -> bool:
	# Skip if no font-related styles
	var font_props = ["font-family", "font-size", "font-bold", "font-italic", "font-thin", "font-extralight", "font-light", "font-normal", "font-medium", "font-semibold", "font-extrabold", "font-black"]
	for prop in font_props:
		if styles.has(prop):
			return false
	return true

static func clear_oldest_entries(cache_dict: Dictionary, count: float):
	var keys_to_remove = []
	var removed = 0
	for key in cache_dict:
		keys_to_remove.append(key)
		removed += 1
		if removed >= count:
			break
	
	for key in keys_to_remove:
		cache_dict.erase(key)

static func clear_cache():
	text_style_cache.clear()
	font_application_cache.clear()
	cache_hits = 0
	cache_misses = 0

static func get_cache_stats() -> Dictionary:
	var total_requests = cache_hits + cache_misses
	var hit_rate = float(cache_hits) / float(total_requests) if total_requests > 0 else 0.0
	
	return {
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"hit_rate": hit_rate,
		"text_cache_size": text_style_cache.size(),
		"font_cache_size": font_application_cache.size()
	}