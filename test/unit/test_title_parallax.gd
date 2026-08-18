extends GutTest
## **시차 예산의 분배** 검증. 배치(`test_title_layers.gd`)와 따로 두는 이유가 있다 —
## 배치는 *무엇이 어디에 있는가*이고 여기는 *무엇이 얼마나 흐르는가*다.
##
## 첫 판정에서 심사자 둘이 만장일치로 졌다 — *"다 같이 움직인다 · 그림 한 장이
## 밀린다"* (docs/design/21-title.md §21.14.3). `drift_of` 는 제대로 돌고 있었고
## **진 것은 진폭이 아니라 분배였다.** 예산이 안 보이는 두 겹(배경 · 전경)에
## 몰려 있었고 눈이 머무는 것들 사이에서 가장 작았다.
##
## 그래서 여기서 지키는 것은 하나다 — **깊이로 읽히는 것은 절대 이동량이 아니라
## 겹 사이의 차이다.**

const SCREEN := Vector2(1280.0, 720.0)


func _plan() -> Array:
	return TitleLayers.plan()


func test_depth_share_spans_the_whole_budget() -> void:
	assert_almost_eq(TitleLayers.depth_share(0.0), 0.0, 0.0001, "가장 뒤는 0 이다")
	assert_almost_eq(TitleLayers.depth_share(1.0), 1.0, 0.0001, "가장 앞은 예산을 다 쓴다")


func test_depth_share_never_goes_backwards() -> void:
	# **앞의 것이 언제나 더 빨라야 한다.** 이것이 깨지면 시차가 아니라 뒤엉킴이다.
	# 굽히는 것은 순서가 아니라 구간마다의 기울기다.
	var previous := -1.0
	for step in 101:
		var depth := float(step) / 100.0
		var share := TitleLayers.depth_share(depth)
		assert_gte(share, previous, "몫은 줄어들면 안 된다: depth=%.2f" % depth)
		previous = share


func test_depth_share_stays_inside_the_budget() -> void:
	for step in 101:
		var share := TitleLayers.depth_share(float(step) / 100.0)
		assert_between(share, 0.0, 1.0, "몫이 예산을 넘거나 음수가 되면 안 된다")


func test_most_of_the_budget_goes_where_the_eye_is() -> void:
	var band := (
		TitleLayers.depth_share(TitleLayers.EYE_FAR) - TitleLayers.depth_share(TitleLayers.EYE_NEAR)
	)
	assert_gt(band, 0.6, "눈이 머무는 구간이 예산의 절반보다 훨씬 많이 가져가야 한다")


func test_the_visible_layers_pull_apart_more_than_plain_depth_would() -> void:
	# 옛 방식은 깊이에 그대로 비례했다. 같은 구간에서 새 방식이 더 벌어져야
	# 고친 값이 있다. 금과 가장 가까운 사람이 그 구간의 양 끝이다.
	var specs := _plan()
	var gold := TitleLayers.find(specs, "hoard")
	var near := TitleLayers.find(specs, "hunter_back")
	var was := absf(near.depth - gold.depth)
	var now := absf(TitleLayers.depth_share(near.depth) - TitleLayers.depth_share(gold.depth))
	assert_gt(now, was, "금과 가장 가까운 사람 사이가 전보다 벌어져야 한다")


func test_the_invisible_layers_give_up_budget() -> void:
	# 배경은 화면의 대부분인데 안 움직이고, 전경은 가장 어두워서 아무도 못 본다.
	# **둘이 먹던 몫을 게워 내야 가운데가 벌어진다.**
	var specs := _plan()
	var foreground := TitleLayers.find(specs, "foreground")
	var nearest_seen := TitleLayers.find(specs, "hunter_back")
	var was := foreground.depth - nearest_seen.depth
	var now := (
		TitleLayers.depth_share(foreground.depth) - TitleLayers.depth_share(nearest_seen.depth)
	)
	assert_lt(now, was, "전경이 혼자 먹던 예산이 줄어야 한다")


func test_every_layer_stays_inside_the_overscan_at_full_sway() -> void:
	# **진폭을 키웠으면 여백을 다시 재야 한다.** 화면 밖으로 밀려나갈 여유보다
	# 많이 흐르면 배경 가장자리가 드러나고, 그 순간 판이 종이 한 장으로 보인다.
	var margin := SCREEN.x * (TitleLayers.OVERSCAN - 1.0) * 0.5
	# 무대가 줄 수 있는 최대 밀림 = 커서 최대 + 자동 표류 최대.
	var most := Vector2(TitleStage.max_sway(), 0.0)
	for spec in _plan():
		if spec.span > 0.0:
			continue  # 꽉 채우는 겹만 가장자리가 드러날 수 있다
		var pushed := absf(TitleLayers.drift_of(spec, most).x)
		assert_lt(pushed, margin, "%s 가 여백보다 많이 흐르면 가장자리가 드러난다" % spec.id)
