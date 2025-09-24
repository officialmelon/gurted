class_name StyleCacheManager
extends RefCounted

# Cache for StyleBox objects based on style hash
static var style_cache = {}

# Cache for style hashes to avoid re-computation
static var hash_cache = {}

# Maximum cache size to prevent memory bloat
static var MAX_CACHE_SIZE = 500

# Cache statistics for performance monitoring
static var cache_hits = 0
static var cache_misses = 0

static func get_cached_stylebox(styles: Dictionary, container: Control = null) -> StyleBoxFlat:
	var style_hash = get_style_hash(styles, container)
	
	if style_cache.has(style_hash):
		cache_hits += 1
		# Return a duplicate to avoid shared state issues
		return style_cache[style_hash].duplicate()
	
	cache_misses += 1
	
	# Create new StyleBox and cache it
	var style_box = BackgroundUtils.create_stylebox_from_styles_direct(styles, container)
	
	# Manage cache size
	if style_cache.size() >= MAX_CACHE_SIZE:
		# Remove oldest entries (simple FIFO)
		var keys_to_remove = []
		var count = 0
		for key in style_cache:
			keys_to_remove.append(key)
			count += 1
			if count >= MAX_CACHE_SIZE / 4.0:  # Remove 25% of cache
				break
		
		for key in keys_to_remove:
			style_cache.erase(key)
	
	# Store in cache
	style_cache[style_hash] = style_box.duplicate()
	
	return style_box

static func get_style_hash(styles: Dictionary, container: Control = null) -> String:
	# Create hash from relevant style properties only (ignore container ID for better cache sharing)
	var hash_components = []
	
	# Sort keys for consistent hashing
	var sorted_keys = styles.keys()
	sorted_keys.sort()
	
	# Background properties
	if styles.has("background-color"):
		hash_components.append("bg:" + str(styles["background-color"]))
	
	# Border properties  
	var border_props = ["border-radius", "border-width", "border-color", 
					   "border-top-width", "border-right-width", 
					   "border-bottom-width", "border-left-width"]
	for prop in border_props:
		if styles.has(prop):
			hash_components.append(prop + ":" + str(styles[prop]))
	
	# Padding properties
	var padding_props = ["padding", "padding-top", "padding-right", 
						"padding-bottom", "padding-left"]
	for prop in padding_props:
		if styles.has(prop):
			hash_components.append(prop + ":" + str(styles[prop]))
	
	# Other visual properties that affect StyleBox
	var other_props = ["border-style", "border-top-color", "border-right-color", 
					  "border-bottom-color", "border-left-color"]
	for prop in other_props:
		if styles.has(prop):
			hash_components.append(prop + ":" + str(styles[prop]))
	
	# Container metadata (only if it affects the style)
	if container:
		var meta_props = ["custom_css_background_color", "custom_css_border_radius", 
						 "custom_css_border_width"]
		for prop in meta_props:
			if container.has_meta(prop):
				hash_components.append("meta_" + prop + ":" + str(container.get_meta(prop)))
	
	var hash_string = "_".join(hash_components)
	
	# Use a simpler cache key that focuses on content, not container identity
	var cache_key = hash_string
	hash_cache[cache_key] = hash_string
	
	return hash_string

static func clear_cache():
	style_cache.clear()
	hash_cache.clear()
	cache_hits = 0
	cache_misses = 0

static func get_cache_stats() -> Dictionary:
	var total_requests = cache_hits + cache_misses
	var hit_rate = float(cache_hits) / float(total_requests) if total_requests > 0 else 0.0
	
	return {
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"hit_rate": hit_rate,
		"cache_size": style_cache.size()
	}
