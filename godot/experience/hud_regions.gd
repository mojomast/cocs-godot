extends RefCounted
## Logical-pixel free-space layout. Existing HUD rectangles always win; a small
## scroll viewport is preferable to drawing new text over an objective or story.
static func subtract(region: Rect2, obstacle: Rect2) -> Array[Rect2]:
	if not region.intersects(obstacle): return [region]
	var cut := region.intersection(obstacle)
	var pieces: Array[Rect2] = [
		Rect2(region.position, Vector2(region.size.x, cut.position.y - region.position.y)),
		Rect2(Vector2(region.position.x, cut.end.y), Vector2(region.size.x, region.end.y - cut.end.y)),
		Rect2(region.position, Vector2(cut.position.x - region.position.x, region.size.y)),
		Rect2(Vector2(cut.end.x, region.position.y), Vector2(region.end.x - cut.end.x, region.size.y))]
	var result: Array[Rect2] = []
	for piece: Rect2 in pieces:
		if piece.size.x >= 40 and piece.size.y >= 18: result.append(piece)
	return result

static func choose(view: Vector2, obstacles: Array[Rect2], wanted: Vector2, bottom: bool = false) -> Rect2:
	var regions: Array[Rect2] = [Rect2(Vector2(12, 12), view - Vector2(24, 24))]
	for obstacle: Rect2 in obstacles:
		var next: Array[Rect2] = []
		for region: Rect2 in regions:
			for piece: Rect2 in subtract(region, obstacle.grow(6)):
				if not next.has(piece): next.append(piece)
		# Prune contained rectangles, retaining maximal usable slots.
		regions.clear()
		for piece: Rect2 in next:
			var contained := false
			for other: Rect2 in next:
				if other != piece and other.encloses(piece):
					contained = true
					break
			if not contained: regions.append(piece)
	var best := Rect2()
	var score := -INF
	for region: Rect2 in regions:
		if region.size.x < minf(220, wanted.x) or region.size.y < 28: continue
		var size := Vector2(minf(region.size.x, wanted.x), minf(region.size.y, wanted.y))
		var position := Vector2(region.end.x - size.x, region.end.y - size.y if bottom else region.position.y)
		var candidate := Rect2(position, size)
		var fit := minf(size.y / maxf(1, wanted.y), 1) * 10000 + minf(size.x / maxf(1, wanted.x), 1) * 2000
		fit += position.y if bottom else -position.y
		fit += position.x * 0.1
		if fit > score:
			score = fit
			best = candidate
	return best

static func occupied(owner: Node, ignored: Array[Node] = []) -> Array[Rect2]:
	var result: Array[Rect2] = []
	_collect(owner, owner, ignored, result)
	return result

static func _collect(node: Node, owner: Node, ignored: Array[Node], result: Array[Rect2]) -> void:
	if node in ignored: return
	# Arena/actor meshes are not HUD roots. Avoid traversing the world each frame.
	if node != owner and node is Node3D: return
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is CanvasLayer and not node.visible: return
	if node is Control and (node is PanelContainer or node is ScrollContainer or node is Label or node is BaseButton):
		if node is Label and node.text.is_empty(): return
		var rect: Rect2 = node.get_global_rect()
		if rect.has_area(): result.append(rect)
		return # Children are already contained by this panel/scroll viewport.
	for child: Node in node.get_children(): _collect(child, owner, ignored, result)
