extends SceneTree
## 앵커가 클립마다 **얼마나 흔들리는지** 훑는다. 눈금을 손으로 잡을 때 쓴다.
##
##     godot --headless --path . -s res://tools/survey_soft_body.gd
##
## `docs/design/31-soft-body.md` §31.4 의 진폭 상한(파츠 반크기의 12 %)이
## **상한으로만 걸리고 있는지, 아니면 눈금이 실제로 그 안에 있는지**를 가른다.
##
## 상한이 일을 하고 있으면 흔들림이 그 지점에서 **평평해진다** — 빠르게 움직일수록
## 더 흔들려야 하는데 안 그렇게 된다. 그래서 날것을 재서 눈금을 먼저 맞춘다.

const STEPS := 200


func _initialize() -> void:
	var rig := CharRig.new()
	var morph := MorphRig.default_for(rig)
	var f := AnimFeatures.all_on()
	print("앵커       클립     최대(날것)  상한   비율")
	for anchor in morph.anchors:
		print("--- %s  (%.2f Hz, z=%.2f, gain=%.2f)" % [
			anchor.anchor_name, anchor.hz, anchor.damping, anchor.gain
		])
	for name: String in ["idle", "walk", "run", "jump", "swing", "hit", "die"]:
		var clip := _clip(rig, name)
		var drives := morph.drives_for(clip, f)
		var worst := PackedFloat32Array()
		worst.resize(morph.anchors.size())
		for i in STEPS:
			var at := clip.loop_seconds() * float(i) / float(STEPS)
			var state := MorphState.solve(morph, drives, at)
			for k in worst.size():
				worst[k] = maxf(worst[k], state.raw_lengths[k])
		for k in worst.size():
			var anchor := morph.anchors[k]
			print(
				"%-9s %-8s %7.3f  %6.3f  %5.2f"
				% [anchor.anchor_name, name, worst[k], anchor.limit, worst[k] / anchor.limit]
			)
	quit()


func _clip(rig: CharRig, name: String) -> CharClip:
	match name:
		"walk":
			return CharWalkClip.new(rig)
		"run":
			return CharRunClip.new(rig)
		"jump":
			return CharJumpClip.new(rig)
		"swing":
			return CharSwingClip.new(rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW)
		"hit":
			return CharHitClip.new(rig)
		"die":
			return CharDieClip.new(rig)
		_:
			return CharIdleClip.new(rig)
