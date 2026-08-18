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

## 자리가 모자랄 때 격자를 넓혀 볼 횟수. 한 번에 반지름이 두 배가 된다.
##
## 세 번이면 반지름이 여덟 배, 넓이로는 예순네 배다. 여기까지 넓혀도 자리가 안 나오면
## 정말 갈 곳이 없는 판이다. 무한히 넓히면 통행 불가 지점을 찍었을 때 명령 한 번이
## 프레임을 통째로 먹는다.
const _GROW_ATTEMPTS := 3


## 목표 지점 둘레에 자리를 만든다. 통행 불가 칸은 건너뛴다.
##
## walkable 은 Vector2 를 받아 bool 을 돌려주는 Callable 이다. 격자를 직접 참조하지 않는 이유는
## 이 계산이 격자가 아닌 다른 지형 표현으로 바뀌어도 그대로 쓰이게 하기 위해서다.
##
## **자리가 모자라면 격자를 넓힌다. 중심에 몰아주지 않는다.**
##
## 예전에는 모자란 인원 전부에게 목표 지점 한 점을 줬다. 그 한 줄이 이 파일에서 가장 나쁜
## 코드였다 - **좁은 곳일수록 걸러지는 자리가 많으니 좁을수록 이 폴백이 커졌고**, 하필
## 우리가 못 푸는 판에서 최악이 됐다. 스무 명이 같은 좌표를 목표로 받으면 그 한 점을 두고
## 영원히 비빈다. 대형 자리를 만든 이유 자체가 그것을 없애기 위해서였는데, 폴백이 그것을
## 되살려 놓고 있었다.
##
## 구석 24 명의 정지 시간이 3.02 초에서 10.02 초로 나빠진 것이 여기서 나왔다 - 목표가
## 방 모서리라 육각 격자의 네 귀퉁이가 통째로 벽에 걸렸다.
##
## 고리를 하나씩 바깥으로 넓히며 필요한 만큼만 모은다. **정렬은 다 모은 뒤 한 번만 한다** -
## 예전처럼 후보 전체를 정렬하면 격자를 넓힐 때마다 정렬 비용이 제곱으로 뛴다(§2 의 교훈).
## **좁은 목에는 자리를 안 놓는다.** `spacious` 가 그 조건이다.
##
## §29 가 짚은 자리다 - 자리를 놓을 때 통행 가능한지만 보고 **그 칸이 유일한 길목인지는
## 안 봤다.** 그래서 문 앞이나 문 안에 자리가 잡히고, 거기 **제대로 도착한** 유닛이 뒤를
## 통째로 막았다. 「제 자리에 선 유닛은 안 밀린다」와 「길을 여는 밀기」가 부딪히던 것이
## 상태 이름 문제가 아니라 여기였다.
##
## **엄한 조건으로 먼저 찾고, 모자라면 푼다.** 세 물음에 이렇게 답한다.
##
## | 물음 | 답 |
## | --- | --- |
## | 좁은 목이 목적지 한가운데면 | 엄한 쪽이 못 채우고 **푼 쪽이 지금과 똑같이 답한다** |
## | 자리를 뒤로 물리면 대열이 늘어진다 | 넓히는 횟수는 그대로다. **엄한 쪽이 실패해도 지금보다 더 넓히지 않는다** |
## | 모든 자리가 좁은 목이면 | 푼 쪽으로 떨어지므로 **최악이 지금과 같다** |
static func build_slots(
	count: int, center: Vector2, spacing: float, walkable: Callable, spacious := Callable()
) -> PackedVector2Array:
	var slots := PackedVector2Array()
	if count <= 0:
		return slots
	var step := maxf(spacing, 1.0)
	var base_radius := int(ceil(sqrt(float(count)))) + 2
	# **먼저 좁은 목을 뺀 자리로만 채워 본다.**
	if not spacious.is_null():
		var radius := base_radius
		for _attempt in _GROW_ATTEMPTS:
			var strict := _gather(count, center, step, spacious, radius)
			if strict.size() >= count:
				return strict
			radius *= 2
	var radius := base_radius
	for _attempt in _GROW_ATTEMPTS:
		slots = _gather(count, center, step, walkable, radius)
		if slots.size() >= count:
			return slots
		radius *= 2
	# 여기까지 와서 모자라면 정말 갈 곳이 없는 판이다. 그때만 목표 지점을 준다 -
	# 갈 곳이 없다고 명령을 버리면 유저에게는 씹힌 것으로 보인다.
	while slots.size() < count:
		slots.append(center)
	return slots


## 이 반지름 안에서 통행 가능한 자리를 중심에서 가까운 순으로 모은다.
##
## 훑는 순서를 **격자 전체 행 우선**으로 둔다. 같은 거리의 자리가 여럿일 때 어느 것이 먼저
## 뽑히느냐가 배정을 바꾸고, 배정이 바뀌면 대열 폭이 바뀐다. 고리 단위로 훑도록 바꿨다가
## 대열 폭이 152 에서 156 으로 벌어지는 것을 보고 되돌렸다 - **넓히는 것과 훑는 순서는
## 따로 두어야 한다.**
static func _gather(
	count: int, center: Vector2, step: float, walkable: Callable, radius: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var keys: Array[float] = []
	for row in range(-radius, radius + 1):
		var offset := step * 0.5 if absi(row) % 2 == 1 else 0.0
		for column in range(-radius, radius + 1):
			var point := center + Vector2(column * step + offset, row * step * _ROW_HEIGHT_RATIO)
			if not walkable.is_null() and not bool(walkable.call(point)):
				continue
			points.append(point)
			keys.append(point.distance_squared_to(center))
	var slots := PackedVector2Array()
	for index in _sorted_indices(keys):
		if slots.size() >= count:
			break
		slots.append(points[index])
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
