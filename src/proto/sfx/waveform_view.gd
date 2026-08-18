class_name SfxWaveformView
extends Control
## 파형을 그린다. **소리는 직렬이라 눈으로 볼 수 있으면 판정이 싸진다.**
##
## 무게를 올렸을 때 꼬리가 실제로 길어지는지, 변주가 정말 다른 파형인지는
## 듣기 전에 보인다. 들어야만 아는 것(음색)과 보면 아는 것(길이 · 봉우리)을 가른다.

## 체인 타 간격. 여기 세로선을 그어 두면 꼬리가 다음 타를 넘는지 바로 보인다
## (src/core/combat/break_tuning.gd 의 seconds_per_hit).
const CHAIN_INTERVAL := 0.35

const BACKGROUND := Color(0.07, 0.08, 0.10)
const GRID := Color(0.20, 0.22, 0.27)
const MARKER := Color(0.85, 0.42, 0.32, 0.55)
const WAVE := Color(0.45, 0.78, 0.92)
const MIDLINE := Color(0.30, 0.33, 0.40)

var _samples := PackedFloat32Array()
var _seconds := 0.0


func show_clip(clip: SfxClip) -> void:
	_samples = clip.samples
	_seconds = clip.seconds()
	queue_redraw()


func seconds() -> float:
	return _seconds


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, BACKGROUND)
	draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), MIDLINE, 1.0)
	if _samples.is_empty():
		return

	# 체인 타 간격 눈금. 꼬리가 이 선을 넘으면 다음 타와 뭉갠다.
	var span := maxf(_seconds, CHAIN_INTERVAL * 2.0)
	var tick := CHAIN_INTERVAL
	while tick < span:
		var x := size.x * tick / span
		draw_line(Vector2(x, 0), Vector2(x, size.y), MARKER, 1.0)
		tick += CHAIN_INTERVAL

	# 한 픽셀에 여러 샘플이 들어가므로 그 구간의 최소 최대를 세로선으로 잇는다.
	# 평균을 쓰면 잡음이 사라져 실제보다 얌전해 보인다.
	var columns := int(size.x)
	var per_column := maxi(1, int(_samples.size() / maxf(size.x * span / _seconds, 1.0)))
	for column in columns:
		var start := column * per_column
		if start >= _samples.size():
			break
		var lowest := 1.0
		var highest := -1.0
		for offset in per_column:
			var index := start + offset
			if index >= _samples.size():
				break
			lowest = minf(lowest, _samples[index])
			highest = maxf(highest, _samples[index])
		if highest < lowest:
			continue
		var mid := size.y * 0.5
		draw_line(
			Vector2(column, mid - highest * mid * 0.94),
			Vector2(column, mid - lowest * mid * 0.94),
			WAVE,
			1.0
		)

	draw_rect(box, GRID, false, 1.0)
