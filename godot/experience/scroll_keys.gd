extends RefCounted
## Focused transcript navigation must be consumed before gameplay input.
static func bind(scroll: ScrollContainer) -> void:
	scroll.gui_input.connect(func(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed: return
		var bar := scroll.get_v_scroll_bar()
		match event.keycode:
			KEY_DOWN: bar.value += 28
			KEY_UP: bar.value -= 28
			KEY_PAGEDOWN: bar.value += bar.page
			KEY_PAGEUP: bar.value -= bar.page
			KEY_HOME: bar.value = bar.min_value
			KEY_END: bar.value = bar.max_value
			_: return
		scroll.accept_event())
