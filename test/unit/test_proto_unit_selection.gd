extends GutTest
## 선택 상태의 단위 테스트.
##
## 선택 규칙은 눈으로 확인하기 가장 어려운 부분이다. 클릭 한 번이 교체인지 추가인지 토글인지가
## 어긋나도 화면은 멀쩡해 보이고, 다음 우클릭에서야 엉뚱한 유닛이 움직인다. 여기서 못 박는다.


func test_replace_swaps_whole_selection() -> void:
	var selection := ProtoUnitSelection.new()
	selection.replace(PackedInt32Array([1, 2, 3]))
	selection.replace(PackedInt32Array([4]))
	assert_eq(selection.ids(), PackedInt32Array([4]))
	assert_eq(selection.size(), 1)


func test_replace_keeps_order_of_first_selection() -> void:
	# 부대 저장이 이 순서를 그대로 받는다. 순서가 흔들리면 저장된 부대도 흔들린다.
	var selection := ProtoUnitSelection.new()
	selection.replace(PackedInt32Array([7, 3, 5]))
	assert_eq(selection.ids(), PackedInt32Array([7, 3, 5]))


func test_replace_with_same_set_is_silent() -> void:
	# 같은 결과를 다시 넣는 것은 변화가 아니다. 신호가 나가면 화면이 헛돈다.
	var selection := ProtoUnitSelection.new()
	selection.replace(PackedInt32Array([1, 2]))
	watch_signals(selection)
	selection.replace(PackedInt32Array([2, 1]))
	assert_signal_emit_count(selection, "changed", 0)


func test_toggle_adds_then_removes() -> void:
	var selection := ProtoUnitSelection.new()
	selection.toggle(9)
	assert_true(selection.has(9))
	selection.toggle(9)
	assert_false(selection.has(9), "Shift 클릭은 이미 있는 것을 빼야 한다")


func test_box_add_never_removes() -> void:
	# 드래그에 토글을 적용하면 박스가 기존 선택을 스칠 때마다 절반이 빠진다.
	var selection := ProtoUnitSelection.new()
	selection.replace(PackedInt32Array([1, 2]))
	selection.add_from_box(PackedInt32Array([2, 3]))
	assert_eq(selection.size(), 3)
	assert_true(selection.has(1) and selection.has(2) and selection.has(3))


func test_remove_drops_only_listed() -> void:
	var selection := ProtoUnitSelection.new()
	selection.replace(PackedInt32Array([1, 2, 3]))
	selection.remove(PackedInt32Array([2, 99]))
	assert_eq(selection.ids(), PackedInt32Array([1, 3]))


func test_retain_drops_missing_units() -> void:
	var selection := ProtoUnitSelection.new()
	selection.replace(PackedInt32Array([1, 2, 3]))
	selection.retain(PackedInt32Array([1, 3]))
	assert_eq(selection.ids(), PackedInt32Array([1, 3]))


func test_clear_on_empty_is_silent() -> void:
	var selection := ProtoUnitSelection.new()
	watch_signals(selection)
	selection.clear()
	assert_signal_emit_count(selection, "changed", 0)
	assert_true(selection.is_empty())
