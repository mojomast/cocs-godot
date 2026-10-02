extends Camera3D
## No shake, no physics ownership. KEEP_HEIGHT orthographic projection.
var reduced_motion := false
const MAX_JUMP := 8.0
const TOP_MARGIN := 0.30
const BOTTOM_MARGIN := 0.12

static func framing(fighters: Array, aspect: float, locked: bool = false) -> Dictionary:
	var left := -8.0 if locked else 0.0
	var right := 8.0 if locked else 0.0
	if not locked and fighters.size() == 2:
		left = minf(float(fighters[0].x),float(fighters[1].x))/1000.0
		right = maxf(float(fighters[0].x),float(fighters[1].x))/1000.0
	var height := maxf((MAX_JUMP+2.4)/(1.0-TOP_MARGIN-BOTTOM_MARGIN),(right-left+3.2)/maxf(aspect,0.1))
	return {"height":height,"center":Vector3(clampf((left+right)*0.5,-4.0,4.0),height*0.5-height*BOTTOM_MARGIN,24.0)}

func present(fighters: Array, viewport_size: Vector2) -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	var frame := framing(fighters,viewport_size.x/maxf(viewport_size.y,1.0),reduced_motion)
	size = frame.height
	position = frame.center
	rotation = Vector3.ZERO
	near = 0.1
	far = 140.0
