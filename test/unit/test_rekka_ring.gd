extends GutTest
## RekkaRing 테스트 — **행진 없이 한 바퀴 돈다.**
##
## 이 계산이 지켜야 하는 것은 셋이다 (docs/design/19-rekka-voice.md §19.B.4, §19.B.9).
##
##   1. 한 바퀴 안에 모든 자리가 한 번씩 나온다 (겹치지 않는다)
##   2. 목록 순서대로 행진하지 않는다 (심사자가 다음 편을 미리 적어 냈다)
##   3. 소금이 다르면 배열 자체가 다르다 (한 칸 밀린 같은 고리가 아니다)
##
## 접두어와 닉네임이 이미 이 계산을 쓰고 있으므로 `test_rekka_handles.gd` 와
## 겹치는 것처럼 보이지만, 저쪽은 **그 목록**을 지키고 이쪽은 **계산 자체**를 지킨다.
## 예비 문안의 어미 · 논평 · 댓글도 여기에 얹혀 있다.

const RingScript := preload("res://src/core/rekka/rekka_ring.gd")


func _cycle(size: int, salt: int) -> Array[int]:
	var seen: Array[int] = []
	for index in size:
		seen.append(RingScript.slot(index, salt, size))
	return seen


# ---------------------------------------------------------------- 한 바퀴


func test_every_slot_appears_exactly_once_per_cycle() -> void:
	# 걸음이 목록 길이와 서로소가 아니면 어떤 자리는 영영 안 나오고 어떤 것은 두 배로 나온다.
	for size in [2, 3, 4, 5, 6, 7, 12, 36]:
		for salt in [0, 1, 771, 20260808, 31337]:
			var seen := _cycle(size, salt)
			seen.sort()
			var wanted: Array[int] = []
			for i in size:
				wanted.append(i)
			assert_eq(seen, wanted, "크기 %d 소금 %d" % [size, salt])


func test_slot_never_leaves_the_list() -> void:
	# 음수 번호는 실수로 들어오기 쉬운 값이다. 목록 밖으로 나가면 그 자리에서 터진다.
	for index in [-7, -1, 0, 1, 999]:
		var slot := RingScript.slot(index, 12345, 9)
		assert_between(slot, 0, 8, "번호 %d" % index)


func test_empty_list_does_not_crash() -> void:
	assert_eq(RingScript.slot(3, 1, 0), 0)


# ---------------------------------------------------------------- 행진하지 않는다


func test_the_ring_never_walks_the_list_in_order() -> void:
	# 걸음이 1 이거나 **크기로 나눈 나머지가 1** 이면 목록 순서 그대로 나온다.
	# 뒤쪽이 이 시험이 잡아낸 것이다 — 크기 12 에 걸음 13 은 걸음 1 과 결과가 같다.
	#
	# 크기가 넷 이하인 목록은 넣지 않는다. 서로소이면서 행진 아닌 걸음이 **존재하지 않는다** —
	# 크기 4 에 쓸 수 있는 걸음은 나머지가 1 아니면 3 뿐이다.
	for size in [5, 7, 12, 36]:
		for salt in [0, 3, 771, 20260808]:
			var walked := true
			for index in size - 1:
				var here := RingScript.slot(index, salt, size)
				if RingScript.slot(index + 1, salt, size) != posmod(here + 1, size):
					walked = false
					break
			assert_false(walked, "크기 %d 소금 %d 가 목록 순서대로 행진한다" % [size, salt])


func test_salts_change_the_order_not_just_the_starting_point() -> void:
	# 시작점만 옮기면 순서가 그대로다 — 심사자가 서른여섯 개짜리 고리를 통째로 복원했다.
	var rotations := 0
	var base := _cycle(36, 20260808)
	for salt in [771, 31337, 9042]:
		var other := _cycle(36, salt)
		for shift in 36:
			var rotated := true
			for i in 36:
				if other[i] != base[(i + shift) % 36]:
					rotated = false
					break
			if rotated:
				rotations += 1
				break
	assert_eq(rotations, 0, "다른 시드가 같은 배열의 회전일 뿐이다")


# ---------------------------------------------------------------- 걸음 고르기


func test_stride_is_always_coprime_with_the_list() -> void:
	# 서로소가 아닌 걸음을 고르면 고리가 짧아진다 — 걸음 5 에 크기 5 면 언제나 같은 자리다.
	for size in range(1, 40):
		for mixed in [0, 1, 5, 77, 1234]:
			var stride := RingScript.stride_for(mixed, size)
			assert_eq(_gcd(stride, size), 1, "크기 %d 에 걸음 %d" % [size, stride])


func test_the_chosen_stride_never_marches() -> void:
	# 나머지가 1 이면 걸음 1 과 같고, 크기-1 이면 거꾸로 행진한다. 뒤집힌 목록도 목록이다.
	#
	# 여섯을 뺀 이유는 **그 크기에 행진 아닌 걸음이 존재하지 않기** 때문이다 —
	# 6 과 서로소인 값의 나머지는 1 아니면 5 뿐이다. 없는 것을 요구하는 시험은 시험이 아니다.
	for size in range(5, 40):
		if size == 6:
			continue
		for mixed in [0, 1, 5, 77, 1234, 99991]:
			var stride := RingScript.stride_for(mixed, size)
			assert_ne(posmod(stride, size), 1, "크기 %d 섞은값 %d 가 행진한다" % [size, mixed])
			assert_ne(posmod(stride, size), size - 1, "크기 %d 섞은값 %d 가 거꾸로 행진한다" % [size, mixed])


func test_tiny_lists_fall_back_instead_of_dropping_to_one() -> void:
	# 크기 넷 이하에는 행진 아닌 걸음이 없다. 찾다 못 찾고 걸음 1 로 떨어지는 것이 제일 나쁘다 —
	# 그러면 한 바퀴가 온전히 돈다는 보장까지 함께 잃는다.
	for size in [2, 3, 4, 6]:
		for mixed in [0, 7, 1234]:
			assert_eq(_gcd(RingScript.stride_for(mixed, size), size), 1, "크기 %d" % size)


func _gcd(a: int, b: int) -> int:
	var left := absi(a)
	var right := absi(b)
	while right != 0:
		var next := left % right
		left = right
		right = next
	return left
