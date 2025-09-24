class_name StyleQueueManager
extends RefCounted

# Queue for deferred styling operations
static var styling_queue: Array = []
static var is_processing: bool = false

class StyleTask:
	var node: WeakRef
	var element: HTMLParser.HTMLElement
	var parser: HTMLParser
	var priority: int = 0  # 0 = low, 1 = medium, 2 = high

static func queue_styling(node: Control, element: HTMLParser.HTMLElement, parser: HTMLParser, priority: int = 0):
	var task = StyleTask.new()
	task.node = weakref(node)
	task.element = element
	task.parser = parser
	task.priority = priority
	
	styling_queue.append(task)

static func process_styling_queue_async():
	if is_processing:
		return
	
	is_processing = true
	var processed = 0
	var max_per_frame = 5
	
	while not styling_queue.is_empty() and processed < max_per_frame:
		var task: StyleTask = styling_queue.pop_front()
		var node = task.node.get_ref()
		
		if node and is_instance_valid(node):
			# Apply full styling
			StyleManager.apply_element_styles(node, task.element, task.parser)
			processed += 1
		
		# Yield every few operations
		if processed % 2 == 0:
			await Engine.get_main_loop().process_frame
	
	is_processing = false
	
	# Schedule next batch if needed
	if not styling_queue.is_empty():
		# Create a small delay before processing next batch
		await Engine.get_main_loop().create_timer(0.016).timeout  # ~60fps delay
		if not styling_queue.is_empty():
			process_styling_queue_async()

static func clear_queue():
	styling_queue.clear()
	is_processing = false

static func get_queue_size() -> int:
	return styling_queue.size()