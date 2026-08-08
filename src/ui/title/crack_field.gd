class_name CrackField
extends RefCounted
## **금이 가는 것.** 취성 파괴의 균열망을 만드는 순수 로직.
##
## 제목이 「금」이고 그 글자는 두 뜻을 동시에 진다 — 금(金)과 **금이 간다**의 금.
## 그래서 이 파일은 장식이 아니라 **제목 그 자체**를 만든다
## (docs/design/21-title.md §21.2).
##
## `UiShape` 와 같은 원칙이다 — 여기는 점 목록만 돌려주고, 그리는 일은 부르는 쪽이 한다.
## 노드도 캔버스도 모르므로 씬 없이 단위 테스트된다 (test/unit/test_crack_field.gd).
##
## ---
##
## **왜 보로노이를 쓰지 않는가.**
##
## 절차적 균열이 가짜로 보이는 이유는 거의 항상 하나다 — 셀 경계를 균열이라고
## 부르는 것. 보로노이 경계는 **동시에, 전부, 같은 굵기로** 생기고 교차점이
## 죄다 Y 자다. 실제 취성 파괴는 그 반대다.
##
## | 실제 균열의 성질 | 여기서 어떻게 |
## | --- | --- |
## | 한 점에서 시작해 **번져 나간다** | `arrivals` — 점마다 전파 거리를 들고 있다 |
## | 끝으로 갈수록 **가늘어진다** | `widths` — 에너지에 비례. 끝은 0 |
## | 갈라질 때 **에너지를 나눠 가진다** | 가지는 부모의 `_BRANCH_TOLL` 만 받는다 |
## | 먼저 난 금을 만나면 **거기서 멈춘다** | T 자 정지 (`_arrest_at_crossing`) |
##
## 마지막 항목이 가장 중요하다. 균열은 이미 갈라진 자리에서 응력이 풀리므로
## 그것을 **뚫고 지나가지 못한다.** 그래서 실제 균열망의 교차점은 X 가 아니라 T 다.
## 이 규칙 하나를 빼면 아무리 손을 봐도 그림이 "무늬"로 보인다.


## 균열 한 가닥. 꺾인 선 하나와 그 위의 굵기·전파 거리다.
class Vein:
	extends RefCounted

	## 꺾은 점들. 첫 점이 시작점이다.
	var points := PackedVector2Array()

	## 각 점에서의 굵기(정규화 좌표). 끝점은 0 이다 — 균열의 끝은 뾰족하다.
	var widths := PackedFloat32Array()

	## 각 점의 **전파 거리.** 균열이 시작점에서 여기까지 오는 데 걸린 길이다.
	## 그림을 시간에 따라 자라게 하려면 프레임이 아니라 이 값으로 잘라야 한다.
	var arrivals := PackedFloat32Array()

	## 몇 번째 갈래인가. 0 이 최초의 금이다.
	var generation := 0

	## 이 가닥이 다른 금에 막혀 멈췄는가. 막힌 끝은 T 자 접점이다.
	var is_arrested := false

	func length() -> float:
		return 0.0 if arrivals.is_empty() else arrivals[arrivals.size() - 1]


## 한 걸음의 길이(정규화). 짧을수록 곡선이 곱지만 선분이 늘어난다.
const _STEP := 0.016

## 한 걸음마다 방향이 흔들리는 최대 각도. 균열은 자로 그은 직선이 아니다.
## 그렇다고 크게 주면 지렁이가 된다 — 취성 파괴는 **거의 곧게** 간다.
const _WANDER_DEGREES := 9.0

## 갈라질 때의 각도 범위. **60도 언저리다.**
##
## 근거가 있다 — Yoffe(1951) 이후로 후프 응력의 최대가 진행 방향에서 60도인 선에
## 수직으로 걸린다는 것이 분기각의 고전적 설명이다
## (docs/design/21-title.md §21.6.6). 5도로 주면 갈라진 것으로 안 보이고,
## 90도로 주면 격자무늬가 된다.
const _BRANCH_MIN_DEGREES := 42.0
const _BRANCH_MAX_DEGREES := 72.0

## 한 걸음마다 갈라질 확률(에너지 1 기준). 에너지가 떨어지면 같이 떨어진다.
##
## 낮게 잡는다. 분기 시점의 응력 확대 계수가 개시값의 **2.4~3배**라는 측정이 있다 —
## **갈라지는 것은 기본값이 아니라 큰 사건이다.** 흔하게 갈라지면 이끼가 된다.
const _BRANCH_CHANCE := 0.085

## 가지가 부모에게서 받아 가는 에너지 비율.
##
## **대칭으로 갈라지지 않는다.** 실제 취성 파괴에서 대칭 분기는 불안정해서
## "보통 한쪽 연장만 살아남는" 것으로 관측된다(§21.6.6).
## 그래서 부모는 거의 그대로 가고 가지는 짧게 죽는 그루터기가 된다.
## 이 둘을 비슷하게 주면 나뭇가지가 아니라 **혈관**이 된다.
const _BRANCH_TOLL := 0.40

## 갈라진 직후 부모가 잃는 에너지. 살아남는 쪽은 거의 잃지 않는다.
const _BRANCH_RECOIL := 0.94

## 한 걸음마다 남는 에너지. 1 에 가까울수록 멀리 간다.
const _ENERGY_KEEP := 0.962

## 이 밑으로 떨어지면 균열이 멎는다.
const _ENERGY_FLOOR := 0.085

## 에너지를 굵기로 바꾸는 배율(정규화 좌표).
##
## 균열을 보여 주는 일은 **조각을 벌리는 것이 아니라 이 선이** 한다.
## 벌려서 말하면 글자가 부서지고, 그으면 글자 위에 금이 간다
## (docs/design/21-title.md §21.11.5).
const _WIDTH_SCALE := 0.0125

## 한 가닥의 최대 걸음 수. 발산을 막는 안전장치다.
const _MAX_STEPS := 260

## 균열망 전체의 최대 가닥 수. 웹 빌드에서 그리는 비용이 여기서 정해진다.
const _MAX_VEINS := 96

## 갈라진 직후에는 다시 갈라지지 않는다. 없으면 시작점에 가지가 뭉쳐 붓이 된다.
const _BRANCH_COOLDOWN := 5

const _EPSILON := 0.00001

var _veins: Array[Vein] = []
var _rng := RandomNumberGenerator.new()
var _bounds := Rect2(Vector2.ZERO, Vector2.ONE)
var _span := 0.0
var _seam := PackedVector2Array()


## 시드를 받는다. **같은 시드는 같은 균열망**이어야 한다 —
## 캡처로 심사받는 그림이 매번 달라지면 무엇을 고쳤는지 비교할 수 없다.
func _init(seed_value: int = 0, bounds: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)) -> void:
	_rng.seed = seed_value
	_bounds = bounds


## **때린 자리에서 금이 간다.** 방사상으로 여러 가닥을 틔운다.
##
## 균열은 응력이 풀리는 방향으로 달아나므로 한 점을 때리면 사방으로 벌어진다.
## `arms` 를 짝수로 주면 정확히 갈라진 대칭이 되어 인공적으로 보이니
## 각도를 흔들어 앉힌다.
func strike(origin: Vector2, arms: int, energy: float = 1.0) -> void:
	var offset := _rng.randf() * TAU
	for index in arms:
		var spread := TAU / float(maxi(arms, 1))
		var angle := offset + spread * float(index) + _rng.randf_range(-0.35, 0.35) * spread
		# 팔마다 힘이 다르다. 똑같이 주면 별표가 된다.
		var arm_energy := energy * _rng.randf_range(0.62, 1.0)
		_run(origin, Vector2.from_angle(angle), arm_energy, 0)
	_measure_span()


## 한 방향으로 금이 달린다. 벽을 따라 번지는 균열처럼 한 가닥만 길게 뻗는다.
func run_from(origin: Vector2, direction: Vector2, energy: float = 1.0) -> void:
	_run(origin, direction.normalized(), energy, 0)
	_measure_span()


## **판을 가르는 금 한 줄.** 한 점에서 양쪽으로 달려 판을 끝에서 끝까지 건넌다.
##
## 이것만 다른 가닥과 취급이 다르다. 나머지는 무늬지만 이 한 줄은 **경계**여서,
## 글자를 두 조각으로 나누는 일이 여기서 결정된다. 가운데서 끊기면
## 어느 쪽이 어느 조각인지 정할 수 없어 갈라지지 않는다.
func split_across(origin: Vector2, direction: Vector2, energy: float = 1.0) -> void:
	var heading := direction.normalized()
	var forward_at := _veins.size()
	_run(origin, heading, energy, 0)
	var backward_at := _veins.size()
	_run(origin, -heading, energy, 0)
	if _veins.size() <= backward_at:
		return
	var line := PackedVector2Array(_veins[backward_at].points)
	line.reverse()
	# 시작점은 양쪽 줄기가 함께 들고 있다. 한 벌은 버려야 이음매가 겹치지 않는다.
	line.remove_at(line.size() - 1)
	line.append_array(_veins[forward_at].points)
	_seam = line
	_measure_span()


## 가르는 금을 정해진 점 수로 다시 뜬 것. 셰이더가 배열 크기를 고정으로 받는다.
##
## 양 끝은 판 **밖으로** 밀어 낸다. 금이 판 안에서 끝나면 그 자리에서
## 두 조각이 도로 하나가 되어, 갈라진 글자가 한쪽만 매달린 것으로 보인다.
func seam(points: int = 10, overhang: float = 0.25) -> PackedVector2Array:
	if _seam.size() < 2:
		return PackedVector2Array()
	var line := resample(_seam, points)
	var head := line[0] + (line[0] - line[1]).normalized() * overhang
	var tail := (
		line[line.size() - 1]
		+ (line[line.size() - 1] - line[line.size() - 2]).normalized() * overhang
	)
	line[0] = head
	line[line.size() - 1] = tail
	return line


## 꺾은선을 **길이 기준으로** 고르게 다시 뜬다.
##
## 점 번호로 건너뛰면 곱게 꺾인 데는 촘촘하고 곧은 데는 성겨서 모양이 달라진다.
static func resample(line: PackedVector2Array, count: int) -> PackedVector2Array:
	var wanted := maxi(count, 2)
	if line.size() < 2:
		return PackedVector2Array(line)
	var marks := PackedFloat32Array([0.0])
	var total := 0.0
	for index in range(1, line.size()):
		total += line[index - 1].distance_to(line[index])
		marks.append(total)
	if total <= _EPSILON:
		return PackedVector2Array(line)
	var out := PackedVector2Array()
	var cursor := 1
	for step in wanted:
		var target := total * float(step) / float(wanted - 1)
		while cursor < marks.size() - 1 and marks[cursor] < target:
			cursor += 1
		var back := marks[cursor - 1]
		var stride := maxf(marks[cursor] - back, _EPSILON)
		var ratio := clampf((target - back) / stride, 0.0, 1.0)
		out.append(line[cursor - 1].lerp(line[cursor], ratio))
	return out


func veins() -> Array[Vein]:
	return _veins


## 균열망 전체가 다 번지는 데 걸리는 길이. `arrivals` 를 0~1 로 읽을 때 나눈다.
func span() -> float:
	return _span


func is_empty() -> bool:
	return _veins.is_empty()


func clear() -> void:
	_veins.clear()
	_seam.clear()
	_span = 0.0


## **갈래점과 끝점.** 전환에서 이 자리가 그대로 던전의 방이 된다.
##
## 우리 던전은 평면 그래프라 생김새가 실제로 균열망과 같다
## (docs/design/17-dungeon-generation.md). 그래서 화면이 바뀌는 것이 아니라
## **갈라져서 이어진다** — 균열이 곧 지도다.
##
## `min_gap` 보다 가까운 자리는 하나로 친다. 방이 겹쳐 앉으면 지도가 아니라 얼룩이다.
func junctions(min_gap: float = 0.035) -> PackedVector2Array:
	var found := PackedVector2Array()
	for vein in _veins:
		if vein.points.is_empty():
			continue
		for candidate in [vein.points[0], vein.points[vein.points.size() - 1]]:
			var point: Vector2 = candidate
			var is_new := true
			for existing in found:
				if existing.distance_to(point) < min_gap:
					is_new = false
					break
			if is_new:
				found.append(point)
	return found


## **자라나는 중의 균열 한 가닥.** `reach` 까지 번진 부분만 잘라 돌려준다.
##
## 통째로 그려 놓고 알파를 올리면 그냥 나타나는 선이다.
## 금은 **끝에서부터 자라나야** 금이 가는 것으로 보인다.
static func advanced(vein: Vein, reach: float) -> PackedVector2Array:
	var grown := PackedVector2Array()
	if vein.points.size() < 2:
		return grown
	for index in vein.points.size():
		if vein.arrivals[index] <= reach:
			grown.append(vein.points[index])
			continue
		# 마지막 점은 정확히 reach 자리에 앉힌다. 점 단위로 끊으면 끝이 튄다.
		var previous := vein.arrivals[index - 1]
		var stride := maxf(vein.arrivals[index] - previous, _EPSILON)
		var ratio := clampf((reach - previous) / stride, 0.0, 1.0)
		# 길이가 0 인 조각은 붙이지 않는다. 겹친 점 두 개는 화면에 점 하나로 찍힌다.
		if ratio > _EPSILON:
			grown.append(vein.points[index - 1].lerp(vein.points[index], ratio))
		break
	return grown


## **띠로 만든 균열.** 굵기가 변하는 선은 폴리곤이어야 한다.
##
## `draw_polyline` 은 굵기가 하나뿐이라 끝이 뾰족해지지 않는다.
## 균열의 끝이 뭉툭하면 그것은 금이 아니라 그어 놓은 선이다.
static func ribbon(vein: Vein, reach: float) -> PackedVector2Array:
	var line := advanced(vein, reach)
	if line.size() < 2:
		return PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for index in line.size():
		var here := line[index]
		var ahead := line[mini(index + 1, line.size() - 1)]
		var behind := line[maxi(index - 1, 0)]
		var normal := (ahead - behind).orthogonal()
		if normal.length_squared() <= _EPSILON:
			normal = Vector2.UP
		normal = normal.normalized()
		# 굵기는 원래 가닥의 것을 쓰되, 잘려 나온 마지막 점은 0 으로 좁힌다.
		var half := 0.0
		if index < vein.widths.size() and index < line.size() - 1:
			half = vein.widths[index] * 0.5
		left.append(here + normal * half)
		right.append(here - normal * half)
	right.reverse()
	var polygon := PackedVector2Array(left)
	polygon.append_array(right)
	return polygon


# ---------------------------------------------------------------------------
# 자라남
# ---------------------------------------------------------------------------


## 균열 한 가닥을 끝까지 달리게 한다. 도중에 갈라지면 그 가지도 여기서 다시 돈다.
func _run(origin: Vector2, direction: Vector2, energy: float, generation: int) -> void:
	if _veins.size() >= _MAX_VEINS or energy < _ENERGY_FLOOR:
		return
	var vein := Vein.new()
	vein.generation = generation
	vein.points.append(origin)
	vein.widths.append(energy * _WIDTH_SCALE)
	vein.arrivals.append(0.0)
	_veins.append(vein)

	var pending: Array = []
	var cursor := origin
	var heading := direction.normalized()
	var travelled := 0.0
	var cooldown := _BRANCH_COOLDOWN

	for step in _MAX_STEPS:
		if energy < _ENERGY_FLOOR:
			break
		var wander := deg_to_rad(_WANDER_DEGREES) * _rng.randf_range(-1.0, 1.0)
		heading = heading.rotated(wander).normalized()
		var next := cursor + heading * _STEP

		# 첫 걸음은 교차를 보지 않는다. 가지는 부모 **위에서** 출발하므로
		# 그대로 재면 시작하자마자 자기 부모에 막혀 한 걸음도 못 간다.
		var crossing: Variant = null if step == 0 else _arrest_at_crossing(cursor, next, vein)
		if crossing != null:
			# T 자 접점. 먼저 난 금이 응력을 이미 풀어 놓아서 여기를 뚫지 못한다.
			travelled += cursor.distance_to(crossing)
			vein.points.append(crossing)
			vein.widths.append(0.0)
			vein.arrivals.append(travelled)
			vein.is_arrested = true
			break

		if not _bounds.has_point(next):
			break

		travelled += _STEP
		cursor = next
		energy *= _ENERGY_KEEP
		vein.points.append(cursor)
		vein.widths.append(energy * _WIDTH_SCALE)
		vein.arrivals.append(travelled)

		cooldown -= 1
		if cooldown <= 0 and _rng.randf() < _BRANCH_CHANCE * energy:
			cooldown = _BRANCH_COOLDOWN
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			var angle := deg_to_rad(_rng.randf_range(_BRANCH_MIN_DEGREES, _BRANCH_MAX_DEGREES))
			pending.append([cursor, heading.rotated(angle * side), energy * _BRANCH_TOLL])
			# 갈라진 부모도 약해진다. 이게 없으면 한 가닥이 영원히 갈라지며 간다.
			energy *= _BRANCH_RECOIL

	# 끝은 뾰족하다. 막혀서 멈춘 것이 아니면 마지막 굵기를 0 으로 좁힌다.
	if not vein.is_arrested and not vein.widths.is_empty():
		vein.widths[vein.widths.size() - 1] = 0.0

	# 가지는 부모를 다 그린 **뒤에** 돈다. 그래야 부모가 T 자 정지의 상대가 된다.
	for branch in pending:
		_run(branch[0], branch[1], branch[2], generation + 1)


## 이번 걸음이 **먼저 난 금**을 건너는가. 건넌다면 그 자리를 돌려준다.
##
## 자기 자신과는 재지 않는다. 방금 지나온 선분과 늘 닿아 있기 때문이다.
func _arrest_at_crossing(from: Vector2, to: Vector2, self_vein: Vein) -> Variant:
	var nearest: Variant = null
	var best := INF
	for vein in _veins:
		if vein == self_vein or vein.points.size() < 2:
			continue
		for index in vein.points.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(
				from, to, vein.points[index], vein.points[index + 1]
			)
			if hit == null:
				continue
			var distance: float = from.distance_to(hit)
			if distance < best:
				best = distance
				nearest = hit
	return nearest


func _measure_span() -> void:
	for vein in _veins:
		_span = maxf(_span, vein.length())
