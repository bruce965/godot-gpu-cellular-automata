extends Node

const materials = [
	{ "color": Color8(  0,   0,   0, 255), "name": "Wall"  },
	{ "color": Color8(156,  68,   0, 255), "name": "Dirt"  },
	{ "color": Color8(134, 134, 134, 255), "name": "Stone" },
	{ "color": Color8( 32, 125, 253, 255), "name": "Water" },
	{ "color": Color8(207, 156, 110, 255), "name": "Sand"  },
	{ "color": Color8( 95,  20,   0, 255), "name": "Wood"  },
	{ "color": Color8(  0,  95,   0, 255), "name": "Grass" },
	{ "color": Color8(255,  78,   0, 255), "name": "Lava"  },
	{ "color": Color8(255,   0,   0, 255), "name": "Fire"  },
	{ "color": Color8(136, 164, 201, 255), "name": "Steam" },
];

var _first_frame_rendered = false
var _material_opacity = 0

func _ready():
	# The simulation computes the cellular automata, but doesn't draw anything
	# on the screen. The "Render" sprite renders a copy of the simulation.
	$Render/World.texture = $Simulation/Viewport.get_texture()
	
	# Initially hide material selection label.
	$CanvasLayer/GUI/Selection.modulate.a8 = 0

func _process(delta):
	if !_first_frame_rendered:
		_first_frame_rendered = true
	else:
		# After the first frame is rendered, assign viewport back to itself,
		# so that next frame can be computed from the previous.
		$Simulation/Viewport/World.texture = $Simulation/Viewport.get_texture()
	
	# Fade out material selection panel.
	if _material_opacity > 0:
		_material_opacity = _material_opacity - 3
		$CanvasLayer/GUI/Selection.modulate.a8 = clamp(_material_opacity, 0, 255)

func _input(event):
	# Brush follows mouse movements.
	if event is InputEventMouseMotion:
		$Simulation/Viewport/Brush.position = get_viewport().get_mouse_position()
		
	elif event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_SPACE:
				$Simulation/Viewport.render_target_update_mode = Viewport.UPDATE_ONCE
			elif event.scancode == KEY_ENTER:
				var is_paused = $Simulation/Viewport.render_target_update_mode != Viewport.UPDATE_ALWAYS
				var new_mode = Viewport.UPDATE_ALWAYS if is_paused else Viewport.UPDATE_DISABLED
				$Simulation/Viewport.render_target_update_mode = new_mode
	
	elif event is InputEventMouseButton:
		# Mouse wheel to change material.
		if event.button_index == BUTTON_WHEEL_UP || event.button_index == BUTTON_WHEEL_DOWN:
			if event.pressed:
				var current_material = 0
				for i in range(materials.size()):
					if materials[i].color == $Simulation/Viewport/Brush.color:
						current_material = i
						break
				
				var offset = -1 if event.button_index == BUTTON_WHEEL_UP else +1
				var set_material = (current_material + offset) % materials.size()
				
				$Simulation/Viewport/Brush.color = materials[set_material].color
				$CanvasLayer/GUI/Selection/Material/Color.color = materials[set_material].color
				$CanvasLayer/GUI/Selection/Material/Label.text = materials[set_material].name
				
				_material_opacity = 400
		
		# Click to paint.
		elif event.button_index == BUTTON_LEFT:
			$Simulation/Viewport/Brush.visible = event.pressed
