class_name CharSilhouette
extends RefCounted
## **실루엣 검사** — 애니메이터들의 고전 검사를 수치로 만든 것.
##
## > 프레임을 전부 **검게 칠했을 때, 어느 프레임인지 구분되나.**
##
## 역동적인 모션은 실루엣이 프레임마다 **완전히 다르다.** 검게 칠해도 어느 순간인지
## 알 수 있다. 정적인 모션은 검게 칠하면 다 비슷한 사람 모양이다.
##
## **이 자가 있어야 「더 크게」가 판정된다.** 없으면 「크게 했다」와 「충분히 크다」를
## 못 가른다 (`docs/design/25-character-animation.md` §25.22.1).
##
## 그림을 안 그린다 — **파츠 여섯의 회전·배율된 상자**를 격자에 찍어서 겹침을 센다.
## 순수 계산이라 GPU 도 뷰포트도 안 쓰고, `sample()` 이 순수 함수라 그냥 된다.

## 격자 칸의 크기(px). 캐릭터가 141 이므로 2 면 70 칸 남짓이라 충분히 곱다.
const CELL := 2.0

## 격자가 덮는 범위 (캐릭터 공간). 크게 움직여도 밖으로 안 나가게 넉넉히 잡는다.
const MIN_X := -90.0
const MAX_X := 130.0
const MIN_Y := -10.0
const MAX_Y := 175.0


## 그 포즈의 실루엣을 격자 비트로 만든다.
##
## **무기를 빼면 안 된다.** 검이 실루엣의 절반이라, 빼고 재면 「검이 머리 위에서
## 발밑까지 지나가는 것」이 자에 안 잡힌다 — 실제로 무거운 무기가 **덜** 역동적이라는
## 거꾸로 된 답이 나왔다.
static func mask(pose: CharPose, rig: CharRig, weapon: CharWeapon = null) -> PackedByteArray:
	var columns := int((MAX_X - MIN_X) / CELL)
	var rows := int((MAX_Y - MIN_Y) / CELL)
	var bits := PackedByteArray()
	bits.resize(columns * rows)
	var inverses: Array[Transform2D] = []
	for part in CharPart.COUNT:
		inverses.append(pose.core_transform(part).affine_inverse())
	# 무기는 든 손의 자식이라 손의 트랜스폼에 자루 오프셋과 쉬는 각을 얹으면 나온다.
	var blade := Transform2D()
	var blade_half := Vector2.ZERO
	var blade_span := Vector2.ZERO
	if weapon != null:
		var mount := Transform2D(weapon.rest_angle(rig), weapon.grip_offset(rig))
		blade = (pose.core_transform(CharWeapon.HOLDER) * mount).affine_inverse()
		blade_half = Vector2(0.0, weapon.blade_half_width())
		blade_span = Vector2(weapon.butt_offset().x, weapon.tip_offset().x)
	for row in rows:
		var y := MIN_Y + (float(row) + 0.5) * CELL
		for column in columns:
			var at := Vector2(MIN_X + (float(column) + 0.5) * CELL, y)
			var filled := false
			for part in CharPart.COUNT:
				var local: Vector2 = inverses[part] * at - rig.local_centers[part]
				var half := rig.half_sizes[part]
				if absf(local.x) <= half.x and absf(local.y) <= half.y:
					filled = true
					break
			if not filled and weapon != null:
				var on_blade: Vector2 = blade * at
				filled = (
					on_blade.x >= blade_span.x
					and on_blade.x <= blade_span.y
					and absf(on_blade.y) <= blade_half.y
				)
			if filled:
				bits[row * columns + column] = 1
	return bits


## 두 실루엣이 얼마나 겹치나 (`0` … `1`). **낮을수록 다르게 생겼다.**
static func overlap(a: PackedByteArray, b: PackedByteArray) -> float:
	var both := 0
	var either := 0
	for i in a.size():
		var left := a[i]
		var right := b[i]
		if left == 1 or right == 1:
			either += 1
			if left == 1 and right == 1:
				both += 1
	if either == 0:
		return 1.0
	return float(both) / float(either)


## 한 바퀴에서 **가장 다른 두 프레임의 겹침.** 이 값이 낮아야 역동적이다.
##
## 모든 쌍을 보므로 표본을 적게 잡는다 — 24 개면 576 쌍이고 충분히 촘촘하다.
static func widest_change(clip: CharClip, samples := 24) -> float:
	var masks: Array[PackedByteArray] = []
	var rig := clip.rig
	var f := AnimFeatures.all_on()
	var swing := clip as CharSwingClip
	var weapon := swing.weapon if swing != null else CharWeapon.new(1)
	for i in samples:
		var t := clip.loop_seconds() * float(i) / float(samples)
		masks.append(mask(clip.sample(t, f), rig, weapon))
	var lowest := 1.0
	for i in masks.size():
		for j in range(i + 1, masks.size()):
			lowest = minf(lowest, overlap(masks[i], masks[j]))
	return lowest
