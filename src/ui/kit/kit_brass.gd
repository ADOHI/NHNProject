class_name KitBrass
extends Control
## 겹 5 — 황동 실선. 이 키트에서 **선으로 그린 유일한 것**이다.
##
## 그래서 이 선은 두 가지를 지킨다.
##
## 1. **닫히지 않는다.** 왼쪽으로 판 밖까지 넘어가고 오른쪽에서는 못 미친다.
##    사방을 두르면 그 순간 액자가 되고, 액자는 어느 UI 에나 있다.
## 2. **포커스는 테를 두르지 않는다.** 밝은 한 마디가 판 둘레를 **돈다.**
##    둘레 전체가 동시에 밝아지면 그것은 `ring-2 ring-offset-2` 와 구별되지 않는다.

## 도는 마디의 길이 (둘레에 대한 비율).
const RUNNER_LENGTH: float = 0.13

## 0 평상 ~ 1 호버. 실선이 자라는 정도.
var lift: float = 0.0

## 0 ~ 1. 포커스가 붙은 정도.
var focus_amount: float = 0.0

## 도는 마디의 자리. 판 둘레를 한 바퀴 도는 0~1 값이다.
var runner: float = 0.0

var dead: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cham := KitMetrics.CHAMFER
	var grow := KitMetrics.BRASS_OVERSHOOT_LEFT * lift
	var base := KitPalette.BRASS
	base.a = lerpf(0.50, 0.85, lift) * (1.0 - dead * 0.75)

	# 위 모서리. 왼쪽으로 넘어가고 오른쪽에서는 잘린 모서리 앞에 못 미쳐 멈춘다.
	var top_from := -KitMetrics.BRASS_OVERSHOOT_LEFT - grow
	var top_to := w - cham - KitMetrics.BRASS_SHORTFALL_RIGHT
	draw_line(Vector2(top_from, 0.5), Vector2(top_to, 0.5), base, 1.0)

	# 잘린 모서리 자체. 짧은 사선 하나가 자른 자리를 증언한다.
	var corner := base
	corner.a *= 0.8
	draw_line(Vector2(w - cham, 0.5), Vector2(w - 0.5, cham), corner, 1.0)

	# 아래 모서리. 오른쪽에서 시작해 왼쪽으로 가다 이음매 앞에서 그친다.
	# 왼쪽 모서리는 자개가 차지했으므로 황동이 거기까지 가면 둘 다 죽는다.
	var under := base
	under.a *= 0.42
	draw_line(Vector2(w - 0.5, h - 0.5), Vector2(w * 0.38, h - 0.5), under, 1.0)

	if focus_amount > 0.004:
		_draw_runner(w, h, cham)


## 판 둘레를 도는 밝은 마디. 둘레를 길이로 매개변수화해서 한 마디만 그린다.
func _draw_runner(w: float, h: float, cham: float) -> void:
	var path := _perimeter(w, h, cham)
	var total := 0.0
	var seg_len := PackedFloat32Array()
	for i in range(path.size() - 1):
		var d := path[i].distance_to(path[i + 1])
		seg_len.append(d)
		total += d
	if total <= 0.0:
		return

	var head := fposmod(runner, 1.0) * total
	var tail := head - RUNNER_LENGTH * total
	var walked := 0.0
	for i in range(seg_len.size()):
		var a := path[i]
		var b := path[i + 1]
		var seg := seg_len[i]
		if seg <= 0.0:
			continue
		# 마디는 둘레를 넘어가며 이어지므로 -total 만큼 옮긴 사본도 함께 본다.
		for shift in [0.0, -total, total]:
			var lo: float = maxf(walked, tail + shift)
			var hi: float = minf(walked + seg, head + shift)
			if hi <= lo:
				continue
			var t0 := (lo - walked) / seg
			var t1 := (hi - walked) / seg
			# 꼬리로 갈수록 흐려진다. 균일한 막대는 진행 막대로 보인다.
			var fade: float = clampf(
				(lo - (tail + shift)) / maxf(RUNNER_LENGTH * total, 1.0), 0.0, 1.0
			)
			var col := KitPalette.BRASS
			col.a = focus_amount * fade * fade * 0.95 * (1.0 - dead)
			draw_line(a.lerp(b, t0), a.lerp(b, t1), col, 1.4)
		walked += seg


## 잘린 모서리를 포함한 판의 둘레. 시작점은 왼쪽 위다.
func _perimeter(w: float, h: float, cham: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(0.5, 0.5),
			Vector2(w - cham, 0.5),
			Vector2(w - 0.5, cham),
			Vector2(w - 0.5, h - 0.5),
			Vector2(0.5, h - 0.5),
			Vector2(0.5, 0.5),
		]
	)
