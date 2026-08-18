extends SceneTree
## 방 하나의 소품 컷아웃에서 **가림 폴리곤을 통째로 뽑고, 줄이는 값을 재서 표로 낸다.**
##
##     godot --headless --path . -s res://tools/make_occluders.gd -- <방 폴더> [출력.json]
##
## `<방 폴더>` 는 방 시각화 레인의 산출물이다. 예:
##
##     C:/Users/adohi/2dAnim/room-studio/out/the_sunken_keep/gallery_of_the_warden
##
## 그 안의 `<room_id>.manifest.json` 과 `cutout/*.png` 를 읽는다.
##
## # 이 도구가 답하는 것
##
## 「알파에서 폴리곤을 뽑을 수 있나」가 아니다. 그건 뽑아 보면 된다.
## **「몇 점까지 줄여도 모양이 남나」** 다. `26-2d-lighting.md` §26.3.2 에서
## 가림 물체가 라이팅 비용의 최대 항목이었고 그 비용은 CPU 였다 — 단일 스레드 웹에서는
## 그게 곧 프레임이다. 그래서 `epsilon` 을 훑으면서 **점 수와 벗어난 거리를 같이** 적는다.
## 점 수만 적으면 「줄였다」와 「뭉갰다」가 구분되지 않는다.

## **화면 픽셀** 기준으로 훑는다. 컷아웃 픽셀이 아니다 — 아래 §「자를 바꿨다」 참고.
const _SCREEN_EPSILONS: Array[float] = [0.5, 1.0, 2.0, 3.0, 4.0]

## 이 값으로 구운다. 화면에서 1 픽셀까지는 어긋나도 된다는 뜻이다.
const _CHOSEN_SCREEN_EPSILON := 1.0

const _WORK_SIZE := 256
const _ALPHA := 0.5

## 매니페스트가 `depth_scale` 을 안 싣는다 (2026-08-09 확인). 레시피에는 있다.
## **여기 적은 것은 임시값이고, 매니페스트가 실으면 이 상수를 지운다.**
const _FALLBACK_DEPTH_SCALE := 0.24


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("사용법: <방 폴더> [출력.json]")
		quit(1)
		return
	var room_dir: String = args[0].trim_suffix("/")
	var room_id := room_dir.get_file()
	var manifest_path := "%s/%s.manifest.json" % [room_dir, room_id]
	var manifest := _read_json(manifest_path)
	if manifest.is_empty():
		push_error("매니페스트를 못 읽었다: %s" % manifest_path)
		quit(1)
		return

	print("방: %s" % room_id)
	print("")
	var baked := _report(room_dir, manifest)
	if args.size() > 1:
		_write_json(args[1], {"room_id": room_id, "work_size": _WORK_SIZE, "props": baked})
		print("\n적었다: %s" % args[1])
	quit(0)


## # 자를 바꿨다 — **컷아웃 픽셀로 재면 열 배 과하게 딴다**
##
## 처음엔 `epsilon` 을 컷아웃 픽셀로 훑었다. 그런데 컷아웃은 원본 그림이고
## **화면에 그려질 때는 훨씬 작다.** `p_shards` 는 523×313 짜리 그림이 화면에서
## 세로 52px 이다 — 컷아웃 6 픽셀이 화면 1 픽셀이다. 컷아웃 기준 3px 로 자르면
## 화면에서는 **0.5px 을 지키자고 점을 46 개나 들고 있는 것**이 된다.
##
## 그래서 소품마다 화면 크기를 계산해 **화면 픽셀로 환산한 `epsilon`** 을 쓴다.
## 화면 크기는 `h = actor_h × height × (1 − depth_scale × (1 − v))` 다
## (방 시각화 `floorplane.scale_at`).
func _report(room_dir: String, manifest: Dictionary) -> Dictionary:
	var props: Array = manifest.get("props", [])
	var actor_h := float(manifest.get("actor_h", 330))
	var depth_scale := float(manifest.get("depth_scale", _FALLBACK_DEPTH_SCALE))
	var heads := PackedStringArray()
	for eps in _SCREEN_EPSILONS:
		heads.append("%.1f" % eps)
	print("| 소품 | 컷아웃 | 화면 | 배 | 덩어리 | 원본 | 화면px %s | 고른 점 | 면적비 |" % " / ".join(heads))
	print("| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: |")
	var out := {}
	var total_dense := 0
	var total_chosen := 0
	for entry in props:
		var asset: String = entry.get("asset", "")
		var path := "%s/cutout/%s.png" % [room_dir, asset]
		var image := Image.load_from_file(path)
		if image == null:
			print("| %s | **없다** | | | | | | | |" % asset)
			continue

		var loops := ProtoAlphaOccluder.trace_all(image, _ALPHA, _WORK_SIZE)
		if loops.is_empty():
			print("| %s | %dx%d | | | 0 | | | | |" % [asset, image.get_width(), image.get_height()])
			continue
		var dense := _largest(loops)
		var dense_area := ProtoAlphaOccluder.polygon_area(dense)

		# 화면에서의 세로 크기와, 컷아웃 픽셀 ÷ 화면 픽셀 배율
		var v := float(entry.get("v", 0.5))
		var screen_h := actor_h * float(entry.get("height", 1.0)) * (1.0 - depth_scale * (1.0 - v))
		var per_screen_px := float(image.get_height()) / maxf(1.0, screen_h)

		var counts := PackedStringArray()
		var chosen := dense
		for eps in _SCREEN_EPSILONS:
			var simple := ProtoAlphaOccluder.simplify(dense, eps * per_screen_px)
			counts.append(str(simple.size()))
			if is_equal_approx(eps, _CHOSEN_SCREEN_EPSILON):
				chosen = simple
		var area_ratio := (
			ProtoAlphaOccluder.polygon_area(chosen) / dense_area if dense_area > 0.0 else 0.0
		)
		total_dense += dense.size()
		total_chosen += chosen.size()
		print(
			(
				"| %s | %dx%d | %.0f | %.1f | %d | %d | %s | **%d** | %.3f |"
				% [
					asset,
					image.get_width(),
					image.get_height(),
					screen_h,
					per_screen_px,
					loops.size(),
					dense.size(),
					" / ".join(counts),
					chosen.size(),
					area_ratio,
				]
			)
		)
		out[asset] = {
			"size": [image.get_width(), image.get_height()],
			"loops": loops.size(),
			"polygon": _flat(chosen),
		}
	print("| **합** | | | | | **%d** | | **%d** | |" % [total_dense, total_chosen])
	return out


func _largest(loops: Array[PackedVector2Array]) -> PackedVector2Array:
	var best: PackedVector2Array = loops[0]
	var best_area := ProtoAlphaOccluder.polygon_area(best)
	for i in range(1, loops.size()):
		var area := ProtoAlphaOccluder.polygon_area(loops[i])
		if area > best_area:
			best_area = area
			best = loops[i]
	return best


func _flat(points: PackedVector2Array) -> Array:
	var out := []
	for p in points:
		out.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	return out


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("못 적었다: %s" % path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
