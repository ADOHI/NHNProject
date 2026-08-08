extends GutTest
## 자개 조각의 위상 · 표류 · 배치 단위 테스트.
##
## 규칙은 docs/design/20-ui-kit.md §20.3.5 다.
## 여기서 지키려는 것은 하나다 — **어느 두 조각도 같은 박자에 놓이지 않는다.**
## 그것이 깨지면 조각 여럿이 한 몸으로 깜박여 재료가 아니라 효과로 보인다.

const _PLATE := Vector2(160.0, 44.0)
const _CHAMFER := 12.0

# ---------------------------------------------------------------- 위상


## 위상은 늘 0~1 안에 있다. 넘어가면 간섭 램프가 엉뚱한 칸을 읽는다.
func test_phase_stays_in_unit_range() -> void:
	for i in range(200):
		var phase := NacrePhase.shard_phase(i)
		assert_between(phase, 0.0, 1.0, "조각 %d 의 위상이 범위를 벗어났다" % i)


## 이웃한 두 조각의 위상이 붙어 있으면 안 된다. 하나가 시안일 때 옆은 라일락이어야 한다.
func test_neighbours_never_share_a_phase() -> void:
	for i in range(64):
		var gap := absf(NacrePhase.shard_phase(i) - NacrePhase.shard_phase(i + 1))
		assert_gt(minf(gap, 1.0 - gap), 0.15, "조각 %d 와 %d 의 위상이 너무 가깝다" % [i, i + 1])


## 같은 인덱스는 늘 같은 값이어야 한다. 난수면 캡처마다 화면이 달라져 심사가 흔들린다.
func test_phase_is_deterministic() -> void:
	for i in range(32):
		assert_eq(NacrePhase.shard_phase(i), NacrePhase.shard_phase(i))


# ---------------------------------------------------------------- 표류


## 표류 폭은 정해진 크기를 넘지 않는다. 넘으면 박힌 것이 아니라 떠다니는 것이 된다.
func test_drift_stays_within_amplitude() -> void:
	var limit := NacrePhase.DRIFT_AMPLITUDE * 1.45
	for i in range(8):
		for step in range(240):
			var offset := NacrePhase.drift(i, float(step) * 0.25)
			assert_lte(offset.length(), limit, "조각 %d 가 너무 멀리 표류했다" % i)


## 표류는 실제로 움직여야 한다. 앞 판본은 12프레임 표준편차가 0.00 이라 불합격했다.
func test_drift_actually_moves() -> void:
	for i in range(6):
		var lowest := Vector2(999.0, 999.0)
		var highest := Vector2(-999.0, -999.0)
		for step in range(400):
			var offset := NacrePhase.drift(i, float(step) * 0.2)
			lowest = lowest.min(offset)
			highest = highest.max(offset)
		var span := highest - lowest
		assert_gt(span.x, 1.0, "조각 %d 가 가로로 거의 안 움직인다" % i)
		assert_gt(span.y, 1.0, "조각 %d 가 세로로 거의 안 움직인다" % i)


## 두 조각이 영영 같은 자리에 오지 않아야 한다. 주기가 같으면 한 몸으로 흔들린다.
func test_two_shards_never_march_together() -> void:
	var apart := 0
	for step in range(600):
		var t := float(step) * 0.1
		if NacrePhase.drift(0, t).distance_to(NacrePhase.drift(1, t)) > 0.4:
			apart += 1
	assert_gt(apart, 480, "두 조각이 너무 오래 같은 자리에 함께 있다")


# ---------------------------------------------------------------- 배치


## 조각은 판 **밖**에 있어야 한다. 안에 들어가면 틀을 넘어가는 유일한 자리가 사라진다.
func test_chips_sit_outside_the_plate() -> void:
	var plate := Rect2(Vector2.ZERO, _PLATE)
	for slot in range(2):
		for i in range(24):
			var at := NacrePhase.chip_offset(i, slot, _PLATE, _CHAMFER)
			# 잘린 모서리 바깥쪽에 있으면 된다. 판의 오른쪽 위 대각선 너머다.
			assert_gt(at.x - at.y, _PLATE.x - _CHAMFER - 1.0, "조각(%d,%d)이 판 안에 들어갔다" % [i, slot])
			assert_true(plate.grow(_CHAMFER * 4.0).has_point(at), "조각이 너무 멀리 갔다")


## 가까운 조각과 먼 조각은 실제로 거리가 달라야 한다.
## 거리를 위상에만 맡겼더니 둘이 겹쳐 나비 모양 얼룩이 됐다 (1차 렌더).
func test_slots_separate_the_chips() -> void:
	for i in range(24):
		var near := NacrePhase.chip_offset(i, 0, _PLATE, _CHAMFER)
		var far := NacrePhase.chip_offset(i, 1, _PLATE, _CHAMFER)
		assert_gt(near.distance_to(far), 12.0, "조각 %d 의 두 자리가 겹친다" % i)


## 조각 크기는 자리마다 달라야 손으로 깬 부스러기로 보인다.
func test_chip_sizes_vary() -> void:
	var smallest := 999.0
	var largest := 0.0
	for i in range(24):
		var side := NacrePhase.chip_size(i)
		smallest = minf(smallest, side)
		largest = maxf(largest, side)
	assert_gt(largest - smallest, 4.0, "조각 크기가 사실상 하나뿐이다")
	assert_gte(smallest, 8.0, "조각이 먼지처럼 작아지면 재료로 안 보인다")


## 튀어 나가는 방향은 늘 오른쪽 위 — 잘린 모서리 바깥이다. 아무 데로나 튀면 인과가 없다.
func test_kick_flies_away_from_the_cut_corner() -> void:
	for i in range(24):
		var direction := NacrePhase.kick_direction(i)
		assert_almost_eq(direction.length(), 1.0, 0.001, "방향이 단위 벡터가 아니다")
		assert_gt(direction.x, 0.0, "조각 %d 가 왼쪽으로 튄다" % i)
		assert_lt(direction.y, 0.0, "조각 %d 가 아래로 튄다" % i)


## 판마다 다른 조각을 쓰되 언제나 같은 것을 골라야 한다.
func test_texture_choice_is_stable_and_in_range() -> void:
	for seed_value in range(40):
		for slot in range(2):
			var index := NacrePhase.chip_texture_index(seed_value, slot, 15)
			assert_between(index, 0, 14, "조각 파일 번호가 범위를 벗어났다")
			assert_eq(index, NacrePhase.chip_texture_index(seed_value, slot, 15))


## 조각 파일이 하나도 없어도 터지지 않는다.
func test_texture_choice_survives_empty_pool() -> void:
	assert_eq(NacrePhase.chip_texture_index(3, 1, 0), 0)
