class_name AsyncDOMBuilder
extends RefCounted

const StyleQueueManager = preload("res://Scripts/Engine/StyleQueueManager.gd")

# Build DOM incrementally to avoid blocking
static func build_dom_async(parser: HTMLParser, body: HTMLParser.HTMLElement, target_container: Control, main_instance) -> bool:
	if not body or not target_container:
		return false
	
	var batch_size = 3  # Process 3 elements per frame
	
	# Process body children in small batches
	var i = 0
	while i < body.children.size():
		var batch_processed = 0
		
		while i < body.children.size() and batch_processed < batch_size:
			var element: HTMLParser.HTMLElement = body.children[i]
			
			# Create element node (this is the heavy part)
			var element_node = await main_instance.create_element_node_lightweight(element, parser, target_container)
			
			if element_node:
				# Register DOM node
				if element.tag_name not in ["input", "textarea", "select", "button", "audio", "canvas"]:
					parser.register_dom_node(element, element_node)
				
				# Add to container
				if element.tag_name != "ul" and element.tag_name != "ol":
					main_instance.safe_add_child(target_container, element_node)
				
				# Handle hyperlinks
				if main_instance.contains_hyperlink(element):
					if element_node is RichTextLabel:
						element_node.meta_clicked.connect(main_instance.handle_link_click)
			
			batch_processed += 1
			i += 1
		
		# Yield after each batch to keep UI responsive
		await Engine.get_main_loop().process_frame
		
		# Check if tab switched or should abort
		var active_tab = main_instance.get_active_tab()
		if not active_tab or not active_tab.loading_tween:
			return false
	
	return true

# Lightweight element creation - defer heavy styling
static func create_element_node_lightweight(element: HTMLParser.HTMLElement, parser: HTMLParser, main_instance) -> Control:
	var node: Control = null
	
	# Create basic nodes without heavy styling
	match element.tag_name:
		"p", "h1", "h2", "h3", "h4", "h5", "h6":
			node = main_instance.P.instantiate()
			# Basic init only - defer styling
			await node.basic_init(element, parser)
		"div":
			var styles = parser.get_element_styles_with_inheritance(element, "", [])
			var is_flex = styles.has("display") and ("flex" in styles["display"])
			var is_grid = styles.has("display") and ("grid" in styles["display"])
			
			if is_flex or is_grid:
				# Handle complex layouts normally (they're less common)
				return await main_instance.create_element_node_internal(element, parser)
			else:
				# Simple div - create lightweight
				node = main_instance.DIV.instantiate()
				await node.basic_init(element, parser)
		"img":
			node = main_instance.IMG.instantiate()
			await node.basic_init(element, parser)
		"br":
			node = main_instance.BR.instantiate()
			await node.basic_init(element, parser)
		"span", "b", "i", "u", "small", "mark", "code", "a":
			node = main_instance.SPAN.instantiate()
			await node.basic_init(element, parser)
		_:
			# For complex elements, fall back to full creation
			return await main_instance.create_element_node_internal(element, parser)
	
	# Queue heavy styling for later
	if node:
		StyleQueueManager.queue_styling(node, element, parser)
	
	return node
