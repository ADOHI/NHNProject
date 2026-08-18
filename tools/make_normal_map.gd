extends SceneTree
## 그림 한 장에서 노멀맵을 만든다. **게임에 들어가는 그 코드로 만든다** —
## 파이썬으로 따로 짜면 「도구가 만든 것」과 「엔진이 쓰는 것」이 갈려서
## 비교가 무의미해진다.
##
##     godot --headless --path . -s res://tools/make_normal_map.gd -- <in> <out> luma 2.0
##     godot --headless --path . -s res://tools/make_normal_map.gd -- <in> <out> plane 62
##     godot --headless --path . -s res://tools/make_normal_map.gd -- <in> <out> plane_luma 62 1.5
##
## | 방식 | 무엇 | 어디에 쓰나 |
## | --- | --- | --- |
## | `luma` | 휘도 기울기(Sobel) | 벽 · 소품. **AI 추정의 대조군** |
## | `plane` | **기울어진 평면의 법선 하나로 채운다** | **바닥.** 추정할 것이 없다 |
## | `plane_luma` | 평면 법선 위에 휘도 결을 얹는다 | 바닥에 줄눈 결까지 주고 싶을 때 |
##
## `plane` 이 있는 이유가 중요하다. 방 시각화의 바닥은 **정사영 평면을 워프한 것**이라
## 그 법선이 기하에서 곧바로 나온다. **바닥에는 AI 추정도 휘도 근사도 필요 없다.**


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("사용법: <in> <out> <luma|plane|plane_luma> [값...]")
		quit(1)
		return
	var source := Image.load_from_file(args[0])
	if source == null:
		push_error("그림을 못 읽었다: %s" % args[0])
		quit(1)
		return
	var mode: String = args[2]
	var out: Image
	match mode:
		"luma":
			out = ProtoNormalFromLuminance.build(source, float(args[3]) if args.size() > 3 else 2.0)
		"plane":
			out = ProtoNormalFromLuminance.build_plane(
				source.get_width(), source.get_height(), float(args[3]) if args.size() > 3 else 60.0
			)
		"plane_luma":
			out = ProtoNormalFromLuminance.build_plane_with_detail(
				source,
				float(args[3]) if args.size() > 3 else 60.0,
				float(args[4]) if args.size() > 4 else 1.5
			)
		_:
			push_error("모르는 방식: %s" % mode)
			quit(1)
			return
	var err := out.save_png(args[1])
	# **기울기 RMS 를 같이 찍는다.** 0 이면 평평한 노멀이고, 그 상태로 "노멀을 켰다"고
	# 재면 아무것도 확인하지 않는 검사가 된다.
	print(
		(
			"%s -> %s (%s, err=%d, 기울기RMS=%.4f)"
			% [args[0], args[1], mode, err, ProtoNormalFromLuminance.tilt_rms(out)]
		)
	)
	quit(0)
