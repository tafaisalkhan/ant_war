extends Node3D
## Sprite gait follows actual distance travelled; Army owns logical strength.
const BlueTexture = preload("res://assets/ant_colony/ant-blue.png")
const RedTexture = preload("res://assets/ant_colony/ant-red.png")
const ArmoredBlueTexture = preload("res://assets/ant_colony/units/armored-blue.png")
const ArmoredRedTexture = preload("res://assets/ant_colony/units/armored-red.png")
const WalkShader = preload("res://assets/ant_colony/ant_walk.gdshader")
var team := 1
var armored := false
var level
var attacking := false
var dying := false
var phase := 0.0
var body: Sprite3D
var shadow: MeshInstance3D
var walk_material: ShaderMaterial
var last_world_position: Vector3
var gait_strength := 0.0
var desired_yaw := 0.0
var heading_initialized := false
static var materials: Dictionary = {}

func _ready() -> void:
	body = Sprite3D.new()
	body.name = "AntSprite"
	body.texture = (ArmoredBlueTexture if team == 1 else ArmoredRedTexture) if armored else (BlueTexture if team == 1 else RedTexture)
	body.pixel_size = (1.55 if armored else 1.25)/float(body.texture.get_height())
	body.rotation.x = -PI/2.0
	body.position.y = 0.045
	body.shaded = false
	# Write depth for the cutout so the transparent path cannot paint over ants.
	body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body.alpha_scissor_threshold = 0.25
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if team == 0:
		body.modulate = Color("9e8a66")
	walk_material = ShaderMaterial.new()
	walk_material.shader = WalkShader
	walk_material.render_priority = 1
	walk_material.set_shader_parameter("ant_texture",body.texture)
	walk_material.set_shader_parameter("team_tint",Color("9e8a66") if team == 0 else Color.WHITE)
	body.material_override = walk_material
	add_child(body)
	shadow = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.17
	disk.bottom_radius = 0.17
	disk.height = 0.006
	disk.radial_segments = 12
	shadow.mesh = disk
	shadow.scale.z = 1.7
	shadow.position.y = 0.008
	shadow.material_override = material(Color(0.04,0.07,0.025,0.23))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	last_world_position = global_position

func _process(delta: float) -> void:
	if dying:
		return
	var displacement := global_position-last_world_position
	displacement.y = 0.0
	last_world_position = global_position
	var distance := displacement.length()
	var moving: bool = distance > 0.0005 and distance < 0.7
	var target_strength := 1.0 if moving or attacking else 0.0
	gait_strength = lerpf(gait_strength,target_strength,1.0-exp(-delta*14.0))
	if moving:
		phase += distance*22.0
	elif attacking:
		phase += delta*16.0
	walk_material.set_shader_parameter("gait_phase",phase)
	walk_material.set_shader_parameter("gait_strength",gait_strength)
	body.position.y = 0.045+abs(sin(phase*2.0))*0.022*gait_strength
	body.position.x = sin(phase)*0.012*gait_strength
	body.position.z = sin(phase)*0.045 if attacking else 0.0
	body.rotation.z = sin(phase)*0.025*gait_strength
	if heading_initialized:
		rotation.y = lerp_angle(rotation.y,desired_yaw,1.0-exp(-delta*12.0))

func face(direction: Vector3) -> void:
	if direction.length_squared() > 0.001:
		desired_yaw = atan2(-direction.x,-direction.z)
		if not heading_initialized:
			rotation.y = desired_yaw
			heading_initialized = true

func die() -> void:
	if dying:
		return
	dying = true
	if level != null:
		level.smoke(global_position,team)
	var tween := create_tween()
	tween.tween_property(body,"position:y",0.16,0.06)
	tween.tween_property(self,"rotation:y",rotation.y+0.65,0.15)
	tween.parallel().tween_property(body,"scale",Vector3(0.85,0.55,1),0.15)
	tween.tween_interval(0.12)
	tween.tween_method(fade,1.0,0.0,0.35)
	tween.tween_callback(queue_free)

func fade(alpha: float) -> void:
	walk_material.set_shader_parameter("fade_amount",alpha)
	shadow.transparency = 1.0-alpha

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials[key] = mat
	return mat
