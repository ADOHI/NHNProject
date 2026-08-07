class_name ProtoFormation
extends RefCounted
## 여러 유닛이 한 지점으로 갈 때 **각자 설 자리**를 만들고 나눠 준다.
##
## 전원에게 같은 좌표를 주면 서로 그 한 점을 차지하려고 영원히 밀어댄다.
## 밀치기(분리)만으로 흩어 놓는 방식은 유닛이 늘어날수록 도착 지점이 부풀고,
## 마지막 몇 명이 자리를 못 잡아 계속 떨린다. 자리를 먼저 정해 두면
## 각자 자기 목표에서 멈추므로 도착이 끝난다.

## 육각 격자로 자리를 만든다. 정사각 격자보다 같은 간격에서 더 촘촘하고,
## 사방으로 균등해 어느 방향에서 접근해도 대형이 한쪽으로 쏠리지 않는다.
const _ROW_HEIGHT_RATIO := 0.8660254


## 목표 지점 둘레에 자리를 만든다. 통행 불가 칸은 건너뛴다.
##
## walkable 은 Vector2 를 받아 bool 을 돌려주는 Callable 이다. 격자를 직접 참조하지 않는 이유는
## 이 계산이 격자가 아닌 다른 지형 표현으로 바뀌어도 그대로 쓰이게 하기 위해서다.
static func build_slots(
	count: int, center: Vector2, spacing: float, walkable: Callable
) -> PackedVector2Array:
	var slots := PackedVector2Array()
	if count <= 0:
		return slots
	var candidates := _lattice(count, center, spacing)
	for point in candidates:
		if slots.size() >= count:
			break
		if walkable.is_null() or bool(walkable.call(point)):
			slots.append(point)
	# 자리가 모자라면(좁은 구석) 남은 인원은 목표 지점을 그대로 받는다.
	# 갈 곳이 없다고 명령을 버리면 유저에게는 씹힌 것으로 보인다.
	while slots.size() < count:
		slots.append(center)
	return slots


## 유닛과 자리를 짝짓는다. 안쪽 자리부터 가장 가까운 유닛을 데려가는 탐욕 방식이다.
##
## 헝가리안 같은 최적 배정을 쓰지 않는 이유는, 최적해가 필요한 게 아니라
## **경로가 교차하지 않는 것**이 필요해서다. 자리는 이미 중심에서 가까운 순으로 정렬되어 있어
## 앞선 유닛이 안쪽을 차지하고 뒤따르는 유닛이 바깥을 채운다 — 접근 순서가 그대로 대형이 된다.
##
## 모든 (유닛, 자리) 쌍을 만들어 거리로 정렬하는 방법을 쓰다가 걷어냈다.
## 인원의 제곱만큼 원소를 GDScript 비교 함수로 정렬하는 비용이 200명 부근에서
## 명령 한 번에 100 밀리초를 넘겼다. 정렬을 없애면 같은 결과를 거리 비교만으로 얻는다.
static func assign(positions: PackedVector2Array, slots: PackedVector2Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(positions.size())
	var taken := PackedByteArray()
	taken.resize(positions.size())
	for i in result.size():
		result[i] = -1
	for slot_index in mini(positions.size(), slots.size()):
		var slot := slots[slot_index]
		var best := -1
		var best_distance := INF
		for unit_index in positions.size():
			if taken[unit_index] == 1:
				continue
			var distance := positions[unit_index].distance_squared_to(slot)
			if distance < best_distance:
				best_distance = distance
				best = unit_index
		if best >= 0:
			taken[best] = 1
			result[best] = slot_index
	return result


## 중심에서 가까운 순으로 육각 격자 점을 뽑는다.
static func _lattice(count: int, center: Vector2, spacing: float) -> PackedVector2Array:
	var step := maxf(spacing, 1.0)
	var radius := int(ceil(sqrt(float(count)))) + 2
	var points := PackedVector2Array()
	var keys: Array[float] = []
	for row in range(-radius, radius + 1):
		var offset := step * 0.5 if absi(row) % 2 == 1 else 0.0
		for column in range(-radius, radius + 1):
			var point := center + Vector2(column * step + offset, row * step * _ROW_HEIGHT_RATIO)
			points.append(point)
			keys.append(point.distance_squared_to(center))
	var sorted := PackedVector2Array()
	for index in _sorted_indices(keys):
		sorted.append(points[index])
	return sorted


## 값이 작은 순서대로의 인덱스 목록. 정렬 결과와 원래 위치를 함께 들고 있어야 해서 직접 짠다.
static func _sorted_indices(values: Array[float]) -> PackedInt32Array:
	var indices: Array[int] = []
	for i in values.size():
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool: return values[a] < values[b])
	var result := PackedInt32Array()
	for i in indices:
		result.append(i)
	return result
