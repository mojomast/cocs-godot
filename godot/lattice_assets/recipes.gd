extends RefCounted
## Finite, hand-authored faceted instrument family. No random/runtime input recipes.
const VERSION := "lattice-instruments-1"
const KINDS := ["hq", "front", "relay", "economy", "depot", "operations"]
const PALETTES := {
	"asterion-relay": {"dark":"263343", "armor":"9caebb", "trim":"d5d9cb", "identity":"74d5cf", "roughness":0.72, "metallic":0.28},
	"monsoon-foundry": {"dark":"233933", "armor":"57796b", "trim":"c6a976", "identity":"b7d29b", "roughness":0.86, "metallic":0.12},
}
const STATE_COLORS := {"unknown":"6d7882", "neutral":"d4dfeb", "red":"f05c58", "blue":"4d9fff", "contest":"ffc46d"}

static func part(label: String, at: Vector3, size: Vector3, material: String, upper: float = 0.85, yaw: float = 0.0) -> Dictionary:
	return {"name":label, "op":"prism", "position":[at.x,at.y,at.z], "size":[size.x,size.y,size.z], "material":material, "lower":1.0, "upper":upper, "bevel":0.12, "yaw":yaw}

static func parts(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind not in KINDS: return out
	# Low inlays mark authored sockets without imitating a capture-radius boundary.
	for i: int in range(4):
		var angle := i * PI / 2.0
		var radius := 2.8 if kind == "depot" else 1.25
		out.append(part("Inlay%d" % i, Vector3(sin(angle)*radius,0.035,cos(angle)*radius), Vector3(0.65,0.05,0.18), "trim", 1.0, angle))
	if kind == "depot":
		# Two open-ended service rails and inset sleepers; no vehicle-shaped proxy.
		for side: int in [-1,1]:
			out.append(part("Rail%d" % (side+1),Vector3(side*2.1,0.035,0),Vector3(0.18,0.05,5.6),"armor"))
			for i: int in range(3):
				out.append(part("Sleeper%d_%d" % [side+1,i],Vector3(side*2.1,0.065,(i-1)*1.65),Vector3(0.65,0.035,0.22),"dark"))
		return out
	# Instruments float above the interaction column: lowest solid detail >= 3.2m.
	# Deliberately no poles, cover, colliders, lights, simulation or capture volumes.
	var y := 3.55
	out.append(part("Keel",Vector3(0,y,0),Vector3(1.15,0.3,0.9),"dark"))
	out.append(part("Collar",Vector3(0,y+0.2,0),Vector3(1.38,0.12,1.02),"trim"))
	out.append(part("Core",Vector3(0,y+0.45,0),Vector3(0.72,0.48,0.65),"armor",0.65))
	out.append(part("Identity",Vector3(0,y+0.48,-0.34),Vector3(0.08,0.3,0.035),"identity",1.0))
	# Owner bars: one red, two blue; neutral is a central white diamond.
	for i: int in range(2):
		out.append(part("Owner%d" % i,Vector3((i-0.5)*0.28,y-0.18,-0.3),Vector3(0.18,0.07,0.4),"owner",1.0))
	out.append(part("Neutral",Vector3(0,y-0.18,0.24),Vector3(0.18,0.07,0.18),"neutral",1.0,PI/4))
	for side: int in [-1,1]:
		out.append(part("Contest%d" % (side+1),Vector3(side*0.77,y+0.12,0),Vector3(0.09,0.2,0.7),"contest",1.0))
	match kind:
		"hq":
			# Split bastion crown, layered shoulder plates, three command vanes.
			for side: int in [-1,1]:
				out.append(part("Shoulder%d" % (side+1),Vector3(side*0.86,y+0.45,0),Vector3(0.55,0.58,1.1),"armor",0.65))
				out.append(part("Crown%d" % (side+1),Vector3(side*0.65,y+1.0,0),Vector3(0.38,0.85,0.58),"trim",0.45))
				out.append(part("Vent%d" % (side+1),Vector3(side*0.88,y+0.48,-0.54),Vector3(0.32,0.28,0.045),"dark"))
			for i: int in range(3):
				out.append(part("Vane%d" % i,Vector3((i-1)*0.22,y+1.0,0.3),Vector3(0.09,0.7,0.22),"armor",0.6))
		"front":
			# Broad opposing arrowhead wings, not a wall or shield bubble.
			for side: int in [-1,1]:
				out.append(part("Wing%d" % (side+1),Vector3(side*0.85,y+0.55,0),Vector3(0.7,0.36,0.74),"armor",0.4,side*0.35))
				out.append(part("Tip%d" % (side+1),Vector3(side*1.2,y+0.7,0),Vector3(0.2,0.25,0.46),"trim",0.5))
			out.append(part("Blade",Vector3(0,y+0.95,0),Vector3(0.3,0.65,0.4),"trim",0.4))
		"relay":
			# Open four-tine antenna cage, negative space reads from every approach.
			for i: int in range(4):
				var a := i*PI/2
				out.append(part("Antenna%d" % i,Vector3(sin(a)*0.85,y+0.85,cos(a)*0.85),Vector3(0.18,1.3,0.32),"armor",0.5,a))
				out.append(part("Cap%d" % i,Vector3(sin(a)*0.85,y+1.52,cos(a)*0.85),Vector3(0.2,0.08,0.34),"trim",1.0,a))
			out.append(part("Signal",Vector3(0,y+1.05,0),Vector3(0.3,0.46,0.3),"identity",0.4,PI/4))
		"economy":
			# Twin faceted pressure vessels and stacked heat-exchanger fins.
			for side: int in [-1,1]:
				out.append(part("Vessel%d" % (side+1),Vector3(side*0.73,y+0.55,0),Vector3(0.44,0.85,0.58),"armor",0.8))
				for i: int in range(3):
					out.append(part("Fin%d_%d" % [side+1,i],Vector3(side*0.73,y+0.25+i*0.24,0),Vector3(0.56,0.065,0.7),"trim",1.0))
			out.append(part("Manifold",Vector3(0,y+1.05,0),Vector3(1.7,0.15,0.35),"dark"))
		"operations":
			# Three sealed mission cartridges; no invented wave/completion light.
			for i: int in range(3):
				out.append(part("Cartridge%d" % i,Vector3((i-1)*0.5,y+0.85,0),Vector3(0.32,0.65,0.44),"armor",0.65))
				out.append(part("Latch%d" % i,Vector3((i-1)*0.5,y+0.85,-0.24),Vector3(0.18,0.12,0.04),"trim",1.0))
	return out
