class_name PoissonDiskSampler
extends RefCounted
## 블루 노이즈로 방 자리를 뿌린다 (Bridson 2007 의 푸아송 디스크 샘플링).
##
## **판의 불균형은 자리를 나중에 정하기 때문에 생긴다.**
## 그래프를 먼저 만들고 힘으로 펼치면 밀도를 직접 통제할 수단이 없다.
## 배치가 연결 관계를 따라가느라 어떤 곳은 뭉치고 어떤 곳은 빈다.
## 그래서 순서를 뒤집어 **자리를 먼저 정한다**
## (docs/design/17-dungeon-generation.md §17.3).
##
## 이 알고리즘이 주는 두 성질이 그대로 "고른 밀도"의 정의가 된다.
##
## | 성질 | 뜻 |
## | --- | --- |
## | 어떤 두 점도 radius 보다 가깝지 않다 | 방이 뭉치지 않는다 |
## | 영역 안 어디서든 근처에 점이 있다 | 넓은 빈 구멍이 없다 |
##
## 균일 난수(그냥 randf 두 개)는 첫 번째 성질이 없어서 반드시 뭉친다.
## 격자는 두 성질을 다 만족하지만 무작위가 아니라 판이 매번 똑같아 보인다.
## 블루 노이즈는 그 사이다.
##
## 좌표 단위는 radius 다. 화면 픽셀로 옮기는 것은 DungeonBlueprint.layout() 이 한다.

## 한 점 주위에서 후보를 몇 번 던져 보고 포기할지.
##
## 크면 빈틈이 줄지만 느려진다. 30 이 원 논문의 값이고, 40 은 "넓은 구멍이 없다"를
## 테스트로 못 박기 위해 조금 올린 것이다.
const DEFAULT_ATTEMPTS := 40

## 반지름 1 기준, 넓이 1 당 찍히는 점의 평균 개수. **실측값이다.**
##
## 최대 푸아송 디스크 집합의 밀도는 이론적으로 정해지지 않아서
## 목표 방 개수에서 영역 크기를 역산하려면 이 값이 필요하다.
## tools/bench_dungeon_generation.gd 로 다시 잴 수 있다.
const _DENSITY := 0.755

## 판의 가로세로 비. 가로로 넓은 판이 화면에서 훑기 편하다.
##
## 정사각형이 가장 단순하지만, 화면이 가로로 길어서 세로 여백만 남는다.
const _ASPECT := 1.45

var _region: Vector2
var _radius: float
var _attempts: int
var _cell: float
var _cols: int
var _rows: int

## 격자 칸 -> 그 칸에 있는 점의 인덱스 (없으면 -1).
##
## 칸의 대각선이 radius 와 같도록 잡아서 **한 칸에 점이 둘 이상 들어갈 수 없다.**
## 덕분에 근처 검사가 5x5 칸 훑기로 끝난다 (전체 비교면 점 개수의 제곱이다).
var _grid: Array[int] = []

var _points: Array[Vector2] = []
var _active: Array[int] = []


func _init(region: Vector2, radius: float = 1.0, attempts: int = DEFAULT_ATTEMPTS) -> void:
	_region = region
	_radius = maxf(radius, 0.0001)
	_attempts = maxi(attempts, 1)
	_cell = _radius / sqrt(2.0)
	_cols = maxi(1, int(ceil(_region.x / _cell)))
	_rows = maxi(1, int(ceil(_region.y / _cell)))


## 목표 개수를 담을 영역 크기.
##
## 넓이가 개수에 비례해야 판이 커져도 밀도가 그대로다.
## 한 변이 개수의 제곱근에 비례하는 것은 그 결과다.
static func region_for_count(count: int, radius: float = 1.0) -> Vector2:
	var area := float(maxi(count, 1)) / _DENSITY * radius * radius
	var height := sqrt(area / _ASPECT)
	return Vector2(height * _ASPECT, height)


## 그 영역에서 나올 점 개수의 기댓값.
##
## 실제 개수는 여기서 ±15% 안팎으로 흔들린다. 정확히 맞추려면 뽑은 점을
## 도로 지워야 하는데, 그러면 방금 보장한 "구멍 없음"이 깨진다.
## 화면에도 "방 N개 안팎"으로 적는 이유다.
static func expected_count(region: Vector2, radius: float = 1.0) -> int:
	return int(round(region.x * region.y * _DENSITY / (radius * radius)))


## 점을 뿌린다. 같은 rng 상태는 같은 결과를 만든다 (§17.7).
func generate(rng: RandomNumberGenerator) -> PackedVector2Array:
	_points.clear()
	_active.clear()
	if _region.x <= 0.0 or _region.y <= 0.0:
		return PackedVector2Array()
	_grid.resize(_cols * _rows)
	_grid.fill(-1)

	_accept(Vector2(rng.randf() * _region.x, rng.randf() * _region.y))
	while not _active.is_empty():
		var slot := rng.randi() % _active.size()
		if not _spawn_around(rng, _points[_active[slot]]):
			# 이 점 주위는 더 이상 자리가 없다. 다시 볼 필요가 없다.
			_active.remove_at(slot)
	return PackedVector2Array(_points)


## 기존 점 주위의 고리에서 새 자리를 찾는다. 찾으면 true.
func _spawn_around(rng: RandomNumberGenerator, origin: Vector2) -> bool:
	for attempt in _attempts:
		var angle := rng.randf() * TAU
		# 반지름 r 과 2r 사이의 고리에서 뽑는다.
		# r 보다 가까우면 어차피 거부되고, 2r 보다 멀면 사이에 구멍이 남는다.
		# sqrt 를 씌우는 것은 고리 위에 고르게 뿌리기 위해서다 (넓이는 반지름의 제곱).
		var distance := _radius * sqrt(rng.randf() * 3.0 + 1.0)
		var candidate := origin + Vector2(cos(angle), sin(angle)) * distance
		if _fits(candidate):
			_accept(candidate)
			return true
	return false


## 영역 안이면서 어떤 점과도 radius 이상 떨어져 있는가.
func _fits(point: Vector2) -> bool:
	if point.x < 0.0 or point.y < 0.0 or point.x >= _region.x or point.y >= _region.y:
		return false
	var col := int(point.x / _cell)
	var row := int(point.y / _cell)
	for r in range(maxi(row - 2, 0), mini(row + 3, _rows)):
		for c in range(maxi(col - 2, 0), mini(col + 3, _cols)):
			var index := _grid[r * _cols + c]
			if index >= 0 and _points[index].distance_to(point) < _radius:
				return false
	return true


func _accept(point: Vector2) -> void:
	var index := _points.size()
	_points.append(point)
	_active.append(index)
	var col := clampi(int(point.x / _cell), 0, _cols - 1)
	var row := clampi(int(point.y / _cell), 0, _rows - 1)
	_grid[row * _cols + col] = index
