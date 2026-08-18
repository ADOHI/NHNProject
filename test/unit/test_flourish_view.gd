extends GutTest
## **잔상과 호가 한 바퀴를 넘어갈 때** — 뷰가 만드는 장식의 계약 (§25.23).
##
## **여기가 비어 있어서 조용히 틀렸다.** 잔상은 `sample(t - Δ)` 로 만드는데(§25.3),
## `t` 가 0 근처면 `Δ` 를 뺀 시각이 **음수**가 된다. 루프 클립이면 한 바퀴 뒤로 접어야
## 하는데 그 자리에서 **없는 함수를 부르고 있었다** (`wrapat` — 진짜 이름은 `wrap_time`).
##
## 화면에서는 걸음 · idle 에 잔상을 안 켜서 안 보였고, 테스트는 **뷰를 아예 안 만들어서**
## 그 줄을 한 번도 안 밟았다. **잔상을 켜고 인원을 세는 벤치가 처음으로 밟았다.**
##
## > 순수 함수만 테스트하면 **노드 층의 한 줄이 통째로 안 돈다.**
## > 그 줄이 「지나간 것을 어떻게 접는가」처럼 **경계에서만 도는 줄**이면 특히 그렇다.


func _view(preset: String) -> CharPartsView:
	var view := CharPartsView.new()
	add_child_autofree(view)
	view.flourish = CharFlourish.preset(preset)
	view.setup(CharRig.new())
	return view


func test_the_trail_folds_around_a_looping_clip() -> void:
	# **시작 언저리에서도 잔상이 다 나와야 한다.** 접는 자리가 깨져 있으면 여기서 걸린다.
	var view := _view("trail_hard")
	var clip := CharIdleClip.new(view.rig)
	var want := view.flourish.trail_count
	assert_gt(want, 0, "잔상이 꺼져 있으면 아무것도 안 재는 것이다")
	for at: float in [0.0, 0.005, 0.02, 1.0, clip.loop_seconds()]:
		var past := view.past_poses(clip, at, AnimFeatures.all_on())
		assert_eq(past.size(), want, "t = %.3f 에서 잔상이 %d 장이 아니다" % [at, want])


func test_the_trail_at_zero_comes_from_the_end_of_the_loop() -> void:
	# 접기는 하는데 **엉뚱한 데서 뽑으면** 잔상이 제자리에 겹쳐 안 보인다.
	# 한 바퀴 뒤의 자세와 같아야 한다.
	var view := _view("trail_hard")
	var clip := CharIdleClip.new(view.rig)
	var f := AnimFeatures.all_on()
	var first := view.past_poses(clip, 0.0, f)[0]
	var gap := view.flourish.trail_gap
	var want := clip.sample(clip.loop_seconds() - gap, f)
	assert_almost_eq(
		first.positions[CharPart.Id.HEAD].y,
		want.positions[CharPart.Id.HEAD].y,
		0.001,
		"시작의 잔상이 한 바퀴 뒤에서 안 온다"
	)


func test_a_one_shot_clip_stops_instead_of_folding() -> void:
	# **루프가 아닌 것을 접으면 안 된다.** 휘두르기의 시작에 마무리 자세가 잔상으로
	# 남으면 「방금 지나갔다」가 거짓말이 된다.
	var view := _view("trail_hard")
	var clip := CharSwingClip.new(view.rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW)
	var past := view.past_poses(clip, 0.0, AnimFeatures.all_on())
	assert_eq(past.size(), 0, "아직 지나간 것이 없는데 잔상이 있다")


func test_the_arc_also_folds_and_stays_a_valid_polygon() -> void:
	# 호도 같은 자리에서 접는다. **그리고 넓이가 0 이면 삼각분할이 깨진다** —
	# 멈춤 구간이 일부러 있는 클립이라 그 자리가 반드시 생긴다 (§25.19).
	var view := _view("arc_hard")
	var clip := CharIdleClip.new(view.rig)
	var sweep := view.blade_sweep(clip, 0.0, AnimFeatures.all_on())
	assert_gte(sweep.size(), 6, "루프 클립이면 시작에서도 호가 나와야 한다")
	for i in sweep.size():
		var next: Vector2 = sweep[(i + 1) % sweep.size()]
		assert_gt(sweep[i].distance_to(next), 0.0001, "호에 겹친 점이 있으면 폴리곤이 깨진다")


func test_turning_the_devices_off_costs_nothing() -> void:
	# **끈 것은 정말 아무것도 안 해야** 나란히 놓은 「없음」 칸이 비교의 바닥이 된다.
	var view := _view("none")
	var clip := CharIdleClip.new(view.rig)
	var f := AnimFeatures.all_on()
	assert_eq(view.past_poses(clip, 1.0, f).size(), 0, "껐는데 잔상이 나온다")
	assert_eq(view.blade_sweep(clip, 1.0, f).size(), 0, "껐는데 호가 나온다")


func test_merging_changes_the_nodes_not_the_pose() -> void:
	# **합침은 그림도 자세도 안 바꾼다 — 찍는 곳만 바꾼다.** 안 그러면 실측이
	# 두 가지 다른 것을 견주는 것이 되어 「파츠 수가 손잡이인가」에 답을 못 한다 (§25.32).
	var rig := CharRig.new()
	var plain := CharPartsView.new()
	add_child_autofree(plain)
	plain.setup(rig)
	var merged := CharPartsView.new()
	merged.merged = true
	add_child_autofree(merged)
	merged.setup(rig)
	assert_eq(plain.get_child_count(), CharPart.COUNT, "안 합쳤으면 파츠마다 노드가 있어야 한다")
	assert_eq(merged.get_child_count(), 0, "합쳤는데 노드가 남아 있다")
	var clip := CharIdleClip.new(rig)
	for at: float in [0.0, 0.4, 1.7]:
		plain.show_at(clip, at)
		merged.show_at(clip, at)
		for part in CharPart.COUNT:
			assert_eq(
				plain.part_node(part).transform,
				merged.part_node(part).transform,
				"t = %.2f 에서 %s 의 자리가 갈렸다" % [at, CharPart.part_name(part)]
			)
