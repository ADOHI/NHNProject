class_name KitShards
extends Control
## 겹 4 — 흩어진 조각. **이 키트에서 요소가 자기 사각형을 넘어가는 유일한 자리다.**
##
## 모서리를 비스듬히 자를 때 떨어져 나온 부스러기라는 뜻이라, 조각은 판 안이 아니라
## **틀 밖**에 있어야 한다. 사각형 안에 얌전히 든 UI 는 어느 화면에나 있다.
##
## 그리고 이 조각들은 **셰이더 시간이 아니라 노드가 직접 움직인다.**
## 조각마다 주기가 달라서 둘이 영영 같은 자리에 오지 않는다.

const SHARD_DIR := "res://assets/ui/kit/shards/"

## 판 하나에 붙는 조각 수. 셋을 넘으면 판이 지저분해지고, 하나면 실수처럼 보인다.
const COUNT: int = 2

static var _pool: Array[Texture2D] = []

var plate_size: Vector2 = Vector2(160.0, 44.0)
var phase: float = 0.0
var glow: float = 0.0
var dead: float = 0.0

## 눌림에서 조각이 튀어 나가는 세기. 1 에서 시작해 잦아든다.
var kick: float = 0.0

var _pieces: Array[TextureRect] = []
var _materials: Array[ShaderMaterial] = []
var _seed: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_pool()


## 판이 자기 자리에서 씨앗을 뽑아 준다. 난수가 아니라 자리의 함수라
## 캡처마다 같은 그림이 나오고, 이웃한 두 판은 다른 조각을 쓴다.
func build(seed_value: int, shader: Shader) -> void:
	_seed = seed_value
	_load_pool()
	if _pool.is_empty():
		return
	for i in range(COUNT):
		var tex_index := NacrePhase.chip_texture_index(_seed, i, _pool.size())
		var rect := TextureRect.new()
		rect.texture = _pool[tex_index]
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side := NacrePhase.chip_size(_seed + i * 11)
		var tex_size := _pool[tex_index].get_size()
		var scale_factor := side / maxf(tex_size.x, tex_size.y)
		rect.size = tex_size * scale_factor
		# 조각마다 기울기가 다르다. 축에 정렬된 부스러기는 부스러기가 아니다.
		rect.pivot_offset = rect.size * 0.5
		rect.rotation = NacrePhase.shard_phase(_seed + i * 3) * TAU

		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("src", _pool[tex_index])
		rect.material = mat

		add_child(rect)
		_pieces.append(rect)
		_materials.append(mat)


func advance(time: float) -> void:
	for i in range(_pieces.size()):
		var rect := _pieces[i]
		var home := NacrePhase.chip_offset(_seed + i * 11, i, plate_size, KitMetrics.CHAMFER)
		var drift := NacrePhase.drift(_seed + i * 7, time)
		var fly := NacrePhase.kick_direction(_seed + i * 5) * kick * 8.0
		rect.position = home - rect.size * 0.5 + drift + fly

		var mat := _materials[i]
		# 조각마다 편광 위상이 다르다. 하나가 시안일 때 옆 것은 라일락이어야 한다.
		mat.set_shader_parameter("phase", phase + NacrePhase.shard_phase(_seed + i * 13))
		mat.set_shader_parameter("glow", glow)
		mat.set_shader_parameter("dead", dead)
		mat.set_shader_parameter("gain", 0.88)
		mat.set_shader_parameter("material_mix", 0.95)


func _load_pool() -> void:
	if not _pool.is_empty():
		return
	var dir := DirAccess.open(SHARD_DIR)
	if dir == null:
		push_warning("자개 조각 폴더를 열 수 없다: " + SHARD_DIR)
		return
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		# 임포트된 리소스는 .import 가 붙어 나온다. 원본 이름만 쓴다.
		var clean := file_name.trim_suffix(".import")
		if not clean.ends_with(".webp"):
			continue
		var tex := load(SHARD_DIR + clean) as Texture2D
		if tex != null and not _pool.has(tex):
			_pool.append(tex)
