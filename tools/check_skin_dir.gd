extends SceneTree
## 파츠 PNG 여섯 장이 **리그에 물리는가**를 검산한다.
##
##     godot --headless --path . -s res://tools/check_skin_dir.gd -- <파츠폴더>
##
## `docs/design/25-character-animation.md` §25.41 이 규약이고 §25.39.1 의 **1 단계**가
## 이것이다.
##
## ## `check_sprite_parts.py` 와 무엇이 다른가
##
## 저쪽은 **가르기 전**의 전신 그림에 건다 — 「팔이 몸에서 떨어져 있어 오려낼 수 있나」.
## 이쪽은 **갈린 뒤**의 여섯 장에 건다 — 「그 여섯으로 리그가 서나」.
## 파이프라인이 바뀌어 파츠가 이미 갈려서 오므로, 그날 돌릴 자가 이쪽이다.
##
## ## 무엇이 진짜 검사이고 무엇이 그냥 읽어 주는 것인가
##
## **`CharRig.from_part_sizes()` 가 쓴 상수로 그 결과를 다시 재면 항등식이다**(§25.13.2).
## 그래서 배치 여섯 줄은 **판정이 아니라 읽기**로 찍는다. 판정하는 것은 셋뿐이다.
##
## | 판정 | 왜 항등식이 아닌가 |
## | --- | --- |
## | **먼 파츠가 더 크지 않은가** | 크기는 **그림**에서 오고 리그는 그것을 안 본다. 먼 것이 크면 앞뒤가 뒤집힌다 (§25.2.2) |
## | **클립이 파고들지 않는가** | 클립 수식은 옛 치수에 맞춰 손으로 잡은 것이라 새 크기에서 깨질 수 있다 |
## | **비례가 리그에서 얼마나 벗어났나** | 시트를 재 보니 손이 작고 발이 컸다 (§25.41.4) |
##
## 나가는 값(exit code)은 **판정 셋**만 본다.

## 이보다 벗어나면 「배치를 리그가 다시 풀어야 한다」고 알린다. 비율이다.
const DRIFT_WARN := 0.30

## 클립을 훑는 간격(초)과 파고듦 한계(유닛).
const STEP := 0.02
const SINK_EPS := 0.001

var _failed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("쓰는 법: godot --headless --path . -s res://tools/check_skin_dir.gd -- <파츠폴더>")
		quit(2)
		return
	for dir in args:
		_check(dir)
	quit(1 if _failed else 0)


func _check(dir: String) -> void:
	print("=== %s" % dir)
	var skin := CharSkin.load_dir(dir)
	if skin.rig == null:
		for problem in skin.problems:
			print("  못 읽음: %s" % problem)
		_failed = true
		return
	for problem in skin.problems:
		print("  못 읽음: %s" % problem)
	var rig := skin.rig
	_print_scales(skin)
	_print_sizes(rig)
	_print_layout(rig)
	_judge_depth(rig)
	_judge_drift(rig)
	_judge_sink(rig)
	_print_reach(rig)
	print("")


## 읽기 — **파츠마다의 배율.** 한 벌이던 것이 여섯 벌이 됐다 (§25.41.8).
##
## 「머리 하나로 맞춘 옛 배율」에 대한 배수로 찍는다 — 그래야 **무엇이 얼마나 줄고
## 늘었는지**가 한눈에 보인다. 덮어쓴 것은 별표로 드러낸다.
func _print_scales(skin: CharSkin) -> void:
	var head := skin.scales[CharPart.Id.HEAD]
	print("  [배율] 파츠마다 제 배율. 옛 균일 배율(머리 기준) 대비 배수")
	for part in CharPart.COUNT:
		var ratio := skin.scales[part] / head
		var mark := ""
		if skin.overrides.has(part):
			mark = "  ★ 손으로 %.3f 곱함" % skin.overrides[part]
		print(
			(
				"    %-10s %8.5f 유닛/px   x%.3f%s"
				% [CharPart.part_name(part), skin.scales[part], ratio, mark]
			)
		)


## 읽기 — 배율을 건 뒤의 크기. **목표는 리그가 안다** — 여기에 숫자를 다시 안 적는다.
func _print_sizes(rig: CharRig) -> void:
	var target := CharRig.new()
	print("  [크기] 키 %.1f  (리그 %.1f)" % [rig.total_height(), target.total_height()])
	for part in CharPart.COUNT:
		var half := rig.half_sizes[part]
		var want := target.half_sizes[part]
		print(
			(
				"    %-10s %6.1f x %6.1f   (리그 %.0f x %.0f)"
				% [
					CharPart.part_name(part),
					half.x * 2.0,
					half.y * 2.0,
					want.x * 2.0,
					want.y * 2.0,
				]
			)
		)


## 읽기 — 배치. **항등식이므로 판정하지 않는다**(§25.13.2).
func _print_layout(rig: CharRig) -> void:
	var height := rig.total_height()
	var near_foot := CharPart.Id.FOOT_NEAR
	var far_foot := CharPart.Id.FOOT_FAR
	var torso := CharPart.Id.TORSO
	var torso_top := rig.rest_positions[torso].y + rig.half_sizes[torso].y * 2.0
	print("  [배치] 키 대비 — 상수로 푼 값이라 검사가 아니라 읽기다")
	print(
		(
			"    뒷발 접지 높이   %5.1f  (%.1f %%)"
			% [rig.rest_positions[far_foot].y, 100.0 * rig.rest_positions[far_foot].y / height]
		)
	)
	print(
		(
			"    두 발 앞뒤 간격  %5.1f  (%.1f %%)"
			% [
				rig.rest_positions[near_foot].x - rig.rest_positions[far_foot].x,
				100.0 * (rig.rest_positions[near_foot].x - rig.rest_positions[far_foot].x) / height,
			]
		)
	)
	print(
		(
			"    목 간격          %5.1f  (%.1f %%)"
			% [
				rig.rest_positions[CharPart.Id.HEAD].y - torso_top,
				100.0 * (rig.rest_positions[CharPart.Id.HEAD].y - torso_top) / height,
			]
		)
	)


## 판정 — **먼 것이 크면 앞뒤가 뒤집힌다**(§25.2.2).
##
## 리그는 크기를 그림에서 그대로 받으므로 이 어긋남을 **아무도 안 본다.**
## 배치 검사는 자리만 보고, 클립은 크기를 안 본다.
func _judge_depth(rig: CharRig) -> void:
	print("  [깊이] 먼 파츠가 가까운 것보다 크면 앞뒤가 뒤집힌다")
	for pair: Array in [
		[CharPart.Id.HAND_FAR, CharPart.Id.HAND_NEAR],
		[CharPart.Id.FOOT_FAR, CharPart.Id.FOOT_NEAR],
	]:
		var far: Vector2 = rig.half_sizes[pair[0]]
		var near: Vector2 = rig.half_sizes[pair[1]]
		for axis: Array in [["가로", far.x, near.x], ["세로", far.y, near.y]]:
			var bad: bool = float(axis[1]) > float(axis[2])
			if bad:
				_failed = true
			print(
				(
					"    %s %s  먼 %.1f  가까운 %.1f   %s"
					% [
						CharPart.part_name(pair[0]),
						axis[0],
						float(axis[1]) * 2.0,
						float(axis[2]) * 2.0,
						"** 뒤집혔다" if bad else "ok",
					]
				)
			)


## 판정 — **넓이는 맞췄으니 남는 것은 가로세로비다.**
##
## 배율이 파츠마다 붙은 뒤로 넓이는 정의상 맞는다. 그래서 이 자가 이제 묻는 것은
## **「그림의 가로세로비가 리그 상자와 얼마나 다른가」** 하나다 — **배율로는 못 고치는
## 유일한 어긋남**이고, 크면 그림 쪽에 넘길 것이다 (§25.41.8).
func _judge_drift(rig: CharRig) -> void:
	var target := CharRig.new()
	print("  [비례] 넓이는 맞췄다. 남는 것은 가로세로비 — 배율로는 못 고친다")
	for part in CharPart.COUNT:
		var got := rig.half_sizes[part]
		var want := target.half_sizes[part]
		var wide := got.x / want.x - 1.0
		var tall := got.y / want.y - 1.0
		var bad := absf(wide) > DRIFT_WARN or absf(tall) > DRIFT_WARN
		if bad:
			_failed = true
		print(
			(
				"    %-10s 가로 %+6.1f %%  세로 %+6.1f %%   %s"
				% [CharPart.part_name(part), wide * 100.0, tall * 100.0, "** 벗어남" if bad else "ok"]
			)
		)


## 판정 — 새 치수에서 클립이 땅을 파고드나. **크기가 바뀌면 여기가 먼저 깨진다.**
func _judge_sink(rig: CharRig) -> void:
	print("  [접지] 클립이 새 치수에서 파고드나")
	var features := AnimFeatures.all_on()
	for clip: CharClip in [CharIdleClip.new(rig), CharWalkClip.new(rig), CharRunClip.new(rig)]:
		var worst := 0.0
		var worst_t := 0.0
		var t := 0.0
		while t <= clip.loop_seconds():
			var sink := clip.sample(t, features).deepest_sink(rig)
			if sink > worst:
				worst = sink
				worst_t = t
			t += STEP
		if worst > SINK_EPS:
			_failed = true
		print(
			(
				"    %-8s 최대 %.3f  (t = %.2f)   %s"
				% [clip.clip_name(), worst, worst_t, "** 파고든다" if worst > SINK_EPS else "ok"]
			)
		)


## 읽기 — 팔 길이 상한의 기준자(§25.29). 어깨가 옮겨지면 기준도 옮겨진다.
func _print_reach(rig: CharRig) -> void:
	print("  [상한] idle 손-어깨 거리가 기준이다 — 어깨가 옮겨지면 같이 옮겨진다")
	for part in [
		CharPart.Id.HAND_NEAR, CharPart.Id.HAND_FAR, CharPart.Id.FOOT_NEAR, CharPart.Id.FOOT_FAR
	]:
		print(
			(
				"    %-10s 기준 %.1f  상한 %.1f"
				% [CharPart.part_name(part), rig.rest_reach(part), rig.reach_limit(part)]
			)
		)
