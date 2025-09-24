class_name ThreadedRenderer
extends RefCounted

# Threading state
static var render_thread: Thread = null
static var render_mutex: Mutex = Mutex.new()
static var render_semaphore: Semaphore = Semaphore.new()
static var should_abort: bool = false

# Render queue
static var render_queue: Array = []

# Results queue  
static var completed_renders: Array = []

# Thread communication data
class RenderTask:
	var id: String
	var html_bytes: PackedByteArray
	var current_domain: String
	var tab_id: String
	var callback_target: WeakRef
	var start_time: float

static func start_render_thread():
	if render_thread and render_thread.is_alive():
		return
	
	render_thread = Thread.new()
	should_abort = false
	render_thread.start(_render_worker_thread)

static func stop_render_thread():
	if not render_thread or not render_thread.is_alive():
		return
	
	render_mutex.lock()
	should_abort = true
	render_mutex.unlock()
	
	render_semaphore.post()  # Wake up worker thread
	render_thread.wait_to_finish()
	render_thread = null

static func queue_render(html_bytes: PackedByteArray, current_domain: String, tab_id: String, callback_target) -> String:
	var task = RenderTask.new()
	task.id = "render_" + str(Time.get_ticks_msec())
	task.html_bytes = html_bytes
	task.current_domain = current_domain
	task.tab_id = tab_id
	task.callback_target = weakref(callback_target)
	task.start_time = Time.get_ticks_msec()
	
	render_mutex.lock()
	render_queue.append(task)
	render_mutex.unlock()
	
	render_semaphore.post()  # Signal worker thread
	return task.id

static func check_completed_renders() -> Array:
	render_mutex.lock()
	var results = completed_renders.duplicate()
	completed_renders.clear()
	render_mutex.unlock()
	return results

static func _render_worker_thread():
	while true:
		render_semaphore.wait()  # Wait for work
		
		render_mutex.lock()
		if should_abort:
			render_mutex.unlock()
			break
		
		if render_queue.is_empty():
			render_mutex.unlock()
			continue
		
		var task: RenderTask = render_queue.pop_front()
		render_mutex.unlock()
		
		# Perform HTML parsing in thread (thread-safe operations only)
		var result = _parse_html_threaded(task)
		
		# Add result to completed queue
		render_mutex.lock()
		completed_renders.append(result)
		render_mutex.unlock()

static func _parse_html_threaded(task: RenderTask) -> Dictionary:
	var start_time = Time.get_ticks_msec()
	
	# Parse HTML (thread-safe)
	var parser: HTMLParser = HTMLParser.new(task.html_bytes)
	var parse_result = parser.parse()
	
	# Process CSS/styles (thread-safe)
	parser.process_styles()
	
	# Extract critical page data
	var title = parser.get_title()
	var icon = parser.get_icon()
	var body = parser.find_first("body")
	var scripts = parser.find_all("script")
	
	var end_time = Time.get_ticks_msec()
	
	return {
		"task_id": task.id,
		"tab_id": task.tab_id,
		"callback_target": task.callback_target,
		"parser": parser,
		"parse_result": parse_result,
		"title": title,
		"icon": icon,
		"body": body,
		"scripts": scripts,
		"current_domain": task.current_domain,
		"parse_time_ms": end_time - start_time,
		"success": true
	}