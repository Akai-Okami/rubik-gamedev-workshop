extends Node3D

const CUBE_SIZE := 4
const CUBIE_SIZE := 2.0
const ANIMATION_DURATION := 0.3

# Color de cada cara del cubo resuelto.
const FACE_COLORS := {
	"Z+": Color(0.0, 1.0, 0.278),   # Verde    – Frente
	"Z-": Color(0.729, 0.337, 1.0), # Morado   – Atrás
	"Y+": Color.WHITE,               # Blanco   – Arriba
	"Y-": Color(0.0, 0.956, 0.967), # Cyan     – Abajo
	"X+": Color(0.902, 0.0, 0.431), # Rosa     – Derecha
	"X-": Color(1.0, 1.0, 0.0)      # Amarillo – Izquierda
}

# Offset y orientación de cada sticker respecto al centro del cubito.
# Inicializados en _ready porque Basis(axis, angle) no es const.
var _face_offset: Dictionary = {}
var _face_basis: Dictionary = {}

class Cubie:
	var node: Node3D
	var x: int
	var y: int
	var z: int

	func _init(n: Node3D, cx: int, cy: int, cz: int) -> void:
		node = n
		x = cx
		y = cy
		z = cz

var cubies: Array[Cubie] = []
var is_rotating: bool = false

# ── Inicialización ────────────────────────────────────────────────────
func _ready() -> void:
	_init_face_data()
	RenderingServer.set_default_clear_color(Color(0.15, 0.15, 0.2))
	_build_cube()
	print("=== CUBO DE RUBIK 4×4 ===")
	print("Capas X → 1-4   |   Y → Q W E R   |   Z → A S F G")
	print("Shift: sentido contrario   |   Espacio: reiniciar")

func _init_face_data() -> void:
	var d := CUBIE_SIZE * 0.501
	_face_offset = {
		"X+": Vector3( d, 0, 0),
		"X-": Vector3(-d, 0, 0),
		"Y+": Vector3(0,  d, 0),
		"Y-": Vector3(0, -d, 0),
		"Z+": Vector3(0, 0,  d),
		"Z-": Vector3(0, 0, -d),
	}
	# Cada basis orienta un QuadMesh (normal +Z por defecto) hacia la cara.
	_face_basis = {
		"Z+": Basis.IDENTITY,
		"Z-": Basis(Vector3.UP,    deg_to_rad(180.0)),
		"Y+": Basis(Vector3.RIGHT, deg_to_rad(-90.0)),
		"Y-": Basis(Vector3.RIGHT, deg_to_rad( 90.0)),
		"X+": Basis(Vector3.UP,    deg_to_rad( 90.0)),
		"X-": Basis(Vector3.UP,    deg_to_rad(-90.0)),
	}

# ── Construcción ──────────────────────────────────────────────────────
func _build_cube() -> void:
	for x in 2:                                    # debería ser CUBE_SIZE: solo genera 2 capas en X en lugar de 4
		for y in CUBE_SIZE:                        # correcto: genera las 4 capas en Y
			for z in CUBE_SIZE:                    # correcto: genera las 4 capas en Z
				var node := _make_cubie(x, y, z)   # crea el cubito en esa posición
				add_child(node)                    # lo agrega a la escena como nodo hijo
				cubies.append(Cubie.new(node, x, y, z))  # lo registra en la lista de nodos del cubo

func _make_cubie(x: int, y: int, z: int) -> Node3D:
	var cubie := Node3D.new()
	cubie.name = "Cubie_%d_%d_%d" % [x, y, z]
	cubie.position = _grid_pos(x, y, z)

	# Núcleo negro del cubito.
	var core := MeshInstance3D.new()
	core.name = "Core"
	var box := BoxMesh.new()
	box.size = Vector3.ONE * CUBIE_SIZE
	core.mesh = box
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.06, 0.06, 0.06)
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.set_surface_override_material(0, core_mat)
	cubie.add_child(core)

	# Stickers solo en las caras exteriores. Se crean UNA vez y quedan
	# pegados al cubito — rotan con él vía el Transform3D. No se recrean.
	for face in FACE_COLORS:
		if _is_face_visible(x, y, z, face):
			_add_sticker(cubie, face, FACE_COLORS[face])
	return cubie

func _add_sticker(cubie: Node3D, face: String, color: Color) -> void:
	var sticker := MeshInstance3D.new()
	sticker.name = "Sticker_" + face
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * CUBIE_SIZE * 0.9
	sticker.mesh = quad
	sticker.transform = Transform3D(_face_basis[face], _face_offset[face])

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sticker.set_surface_override_material(0, mat)
	cubie.add_child(sticker)

func _is_face_visible(x: int, y: int, z: int, face: String) -> bool:
	match face:
		"X+": return x == CUBE_SIZE - 1
		"X-": return x == 0
		"Y+": return y == CUBE_SIZE - 1
		"Y-": return y == 0
		"Z+": return z == CUBE_SIZE - 1
		"Z-": return z == 0
	return false

func _grid_pos(x: int, y: int, z: int) -> Vector3:
	var half := (CUBE_SIZE - 1) * CUBIE_SIZE / 2.0
	return Vector3(
		x * CUBIE_SIZE - half,
		y * CUBIE_SIZE - half,
		z * CUBIE_SIZE - half
	)

# ── Rotación de capas ────────────────────────────────────────────────
func rotate_layer(axis: String, layer: int, clockwise: bool = true) -> void:
	if is_rotating:
		return
	is_rotating = true

	var affected: Array[Cubie] = []
	for c in cubies:
		var coord: int = c.x
		match axis:
			"Y": coord = c.y
			"Z": coord = c.z
		if coord == layer:
			affected.append(c)

	if affected.is_empty():
		is_rotating = false
		return

	await _animate(affected, axis, clockwise)
	_finalize(affected, axis, clockwise)
	is_rotating = false

# Anima la rotación usando un pivote temporal. Los cubitos se reparentan
# al pivote, rotan con él, y vuelven al padre original preservando su
# transform global (la rotación queda acumulada en cada cubito).
func _animate(affected: Array[Cubie], axis: String, clockwise: bool) -> void:
	var pivot := Node3D.new()
	pivot.name = "RotPivot"
	add_child(pivot)

	var rot_axis: Vector3
	match axis:
		"X":
			pivot.position.x = _grid_pos(affected[0].x, 0, 0).x
			rot_axis = Vector3.RIGHT
		"Y":
			pivot.position.y = _grid_pos(0, affected[0].y, 0).y
			rot_axis = Vector3.UP
		"Z":
			pivot.position.z = _grid_pos(0, 0, affected[0].z).z
			rot_axis = Vector3.BACK  # (0,0,1)

	# Reparentar al pivote preservando transform global.
	var originals: Array = []
	for c in affected:
		var gt := c.node.global_transform
		var parent := c.node.get_parent()
		parent.remove_child(c.node)
		pivot.add_child(c.node)
		c.node.global_transform = gt
		originals.append({"cubie": c, "parent": parent})

	var target_angle := deg_to_rad(90.0) * (1.0 if clockwise else -1.0)
	var elapsed := 0.0

	while elapsed < ANIMATION_DURATION:
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / ANIMATION_DURATION, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)  # smoothstep
		pivot.basis = Basis(rot_axis, target_angle * t)
		await get_tree().process_frame
	pivot.basis = Basis(rot_axis, target_angle)

	# Devolver al padre original, preservando la rotación acumulada.
	for item in originals:
		var c: Cubie = item["cubie"]
		var gt := c.node.global_transform
		pivot.remove_child(c.node)
		item["parent"].add_child(c.node)
		c.node.global_transform = gt
	pivot.queue_free()

# Actualiza posición lógica y "snapea" el transform para evitar
# acumulación de error de punto flotante tras muchas rotaciones.
func _finalize(affected: Array[Cubie], axis: String, clockwise: bool) -> void:
	var max_i := CUBE_SIZE - 1
	for c in affected:
		var nx := c.x
		var ny := c.y
		var nz := c.z
		# Fórmulas consistentes con R_A(+90°) — regla de mano derecha.
		match axis:
			"X":
				if clockwise:
					ny = max_i - c.z
					nz = c.y
				else:
					ny = c.z
					nz = max_i - c.y
			"Y":
				if clockwise:
					nx = c.z
					nz = max_i - c.x
				else:
					nx = max_i - c.z
					nz = c.x
			"Z":
				if clockwise:
					nx = max_i - c.y
					ny = c.x
				else:
					nx = c.y
					ny = max_i - c.x
		c.x = nx
		c.y = ny
		c.z = nz

		# Snap: posición exacta y basis limpio en ejes cardinales.
		c.node.position = _grid_pos(c.x, c.y, c.z)
		c.node.basis = _snap_basis(c.node.basis)

# Redondea cada componente al entero más cercano. Para rotaciones
# compuestas de múltiplos de 90° alrededor de ejes, cada vector base
# siempre es una permutación de ±(1,0,0), ±(0,1,0) o ±(0,0,1).
func _snap_basis(b: Basis) -> Basis:
	return Basis(
		Vector3(roundf(b.x.x), roundf(b.x.y), roundf(b.x.z)),
		Vector3(roundf(b.y.x), roundf(b.y.y), roundf(b.y.z)),
		Vector3(roundf(b.z.x), roundf(b.z.y), roundf(b.z.z))
	)

# ── Input ─────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var shift: bool = (event as InputEventKey).shift_pressed

	match (event as InputEventKey).keycode:
		KEY_SPACE:
			get_tree().reload_current_scene()

		KEY_1: rotate_layer("X", 0, not shift)
		KEY_2: rotate_layer("X", 1, not shift)
		KEY_3: rotate_layer("X", 2, not shift)
		KEY_4: rotate_layer("X", 3, not shift)

		KEY_Q: rotate_layer("Y", 0, not shift)
		KEY_W: rotate_layer("Y", 1, not shift)
		KEY_E: rotate_layer("Y", 2, not shift)
		KEY_R: rotate_layer("Y", 3, not shift)

		KEY_A: rotate_layer("Z", 0, not shift)
		KEY_S: rotate_layer("Z", 1, not shift)
		KEY_F: rotate_layer("Z", 2, not shift)
		KEY_G: rotate_layer("Z", 3, not shift)
