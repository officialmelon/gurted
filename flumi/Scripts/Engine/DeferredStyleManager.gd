class_name DeferredStyleManager
extends RefCounted

# Queue for deferred style operations
static var deferred_queue = []
static var is_processing = false

# Styles that can be safely deferred (non-critical for layout)
static var deferrable_styles = [
	"border-radius",
	"box-shadow", 
	"text-shadow",
	"background-image",
	"opacity",
	"transform",
	"transition",
	"animation",
	"filter",
	"backdrop-filter"
]

# Styles that must be applied immediately (critical for layout)
static var critical_styles = [
	"width",
	"height", 
	"margin",
	"margin-top",
	"margin-right", 
	"margin-bottom",
	"margin-left",
	"padding",
	"padding-top",
	"padding-right",
	"padding-bottom", 
	"padding-left",
	"display",
	"position",
	"top",
	"right",
	"bottom",
	"left",
	"border-width",
	"border-top-width",
	"border-right-width", 
	"border-bottom-width",
	"border-left-width"
]

static func split_styles(styles: Dictionary) -> Dictionary:
	var critical = {}
	var deferrable = {}
	
	for key in styles:
		if key in critical_styles:
			critical[key] = styles[key]
		elif key in deferrable_styles:
			deferrable[key] = styles[key]
		else:
			# Default to critical for unknown styles to be safe
			critical[key] = styles[key]
	
	return {
		"critical": critical,
		"deferrable": deferrable
	}

static func queue_deferred_styling(node: Control, element: HTMLParser.HTMLElement, parser: HTMLParser, deferred_styles: Dictionary):
	if deferred_styles.is_empty():
		return
		
	deferred_queue.append({
		"node": weakref(node),
		"element": element,
		"parser": parser,
		"styles": deferred_styles,
		"timestamp": Time.get_time_dict_from_system()
	})

static func process_deferred_queue_async():
	if is_processing or deferred_queue.is_empty():
		return
	
	is_processing = true
	
	# Process in small batches to avoid frame drops
	var batch_size = 5
	var processed = 0
	
	while not deferred_queue.is_empty() and processed < batch_size:
		var item = deferred_queue.pop_front()
		var node_ref = item.node as WeakRef
		var node = node_ref.get_ref() if node_ref else null
		
		# Skip if node was destroyed
		if not node or not is_instance_valid(node):
			processed += 1
			continue
		
		# Apply deferred styles
		apply_deferred_styles_to_node(node, item.element, item.parser, item.styles)
		processed += 1
		
		# Yield every few operations to maintain responsiveness
		if processed % 3 == 0:
			await Engine.get_main_loop().process_frame
	
	is_processing = false
	
	# Schedule next batch if queue still has items
	if not deferred_queue.is_empty():
		# Create a small delay before processing next batch
		await Engine.get_main_loop().create_timer(0.016).timeout  # ~60fps delay
		if not deferred_queue.is_empty():
			process_deferred_queue_async()

static func apply_deferred_styles_to_node(node: Control, _element: HTMLParser.HTMLElement, _parser: HTMLParser, styles: Dictionary):
	# Apply deferred visual styles
	for style_key in styles:
		match style_key:
			"border-radius":
				apply_border_radius_deferred(node, styles[style_key])
			"opacity":
				if node:
					node.modulate.a = float(styles[style_key])
			"transform":
				apply_transform_deferred(node, styles[style_key])
			# Add more deferred style handlers as needed
			_:
				# For unknown deferred styles, apply them normally
				var single_style = {style_key: styles[style_key]}
				if node is PanelContainer:
					StyleManager.apply_stylebox_to_panel_container(node, single_style)
				else:
					StyleManager.apply_stylebox_to_container_direct(node, single_style)

static func apply_border_radius_deferred(node: Control, border_radius_value):
	if not node:
		return
		
	# Create or update stylebox with border radius
	var style_box = null
	if node.has_theme_stylebox_override("panel"):
		style_box = node.get_theme_stylebox("panel").duplicate()
	else:
		style_box = StyleBoxFlat.new()
	
	var radius = StyleManager.parse_radius(str(border_radius_value))
	style_box.corner_radius_top_left = radius
	style_box.corner_radius_top_right = radius
	style_box.corner_radius_bottom_left = radius
	style_box.corner_radius_bottom_right = radius
	
	node.add_theme_stylebox_override("panel", style_box)

static func apply_transform_deferred(node: Control, _transform_value):
	# Apply CSS transforms like scale, rotate, translate
	if not node:
		return
	
	# This would need full CSS transform parsing
	# For now, just a placeholder
	pass

static func clear_queue():
	deferred_queue.clear()
	is_processing = false

static func get_queue_stats() -> Dictionary:
	return {
		"queue_size": deferred_queue.size(),
		"is_processing": is_processing
	}