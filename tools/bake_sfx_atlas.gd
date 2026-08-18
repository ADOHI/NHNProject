extends SceneTree
## **층 쌓기를 미리 해 둔다** (docs/design/29-sound.md §29.7.11).
##
## 웹에서 시작 오디오 비용이 652 ms 였고 그중 굽기가 412 ms 다.
## 단계별로 재 보니 필터 하나하나는 싼데(리샘플 0.195 · 저역통과 0.112 · 정규화 0.139 ms)
## **타격 하나를 통째로 만드는 데 2.641 ms** 가 든다. UI 딸깍은 0.281 ms 다.
## 차이가 **층 쌓기**다 — 저역 몸통 파일을 따로 읽어 처리하고 두 번 섞는 GDScript 루프.
##
## 카탈로그는 정적이다. 게임이 쓸 조합은 빌드 시점에 전부 안다.
## **그래서 미리 섞어 파일로 굽는다.** 실행 시점에는 읽어서 볼륨만 곱하면 된다.
##
##     godot --headless --path . -s res://tools/bake_sfx_atlas.gd

const OUT_DIR := "res://assets/audio/sfx_baked"
const ATLAS_PATH := "res://src/core/sfx/sfx_atlas.gd"

## 무기 칸 수에서 무게를 받는 사건은 이 넷을 미리 구워 둔다.
const CELL_WEIGHTS: Array[float] = [1.0, 2.0, 3.0, 4.0]

var _keys: Array[String] = []
var _rows: Array[Dictionary] = []


func _init() -> void:
	_clear_out_dir()

	var seen := {}
	for event in SfxEvent.all():
		var base := SfxCatalog.request_for(event)
		var weights: Array[float] = []
		if SfxCatalog.is_weight_driven(event):
			weights.assign(CELL_WEIGHTS)
		# 표가 가진 무게도 반드시 넣는다. 배치 층이 칸 수를 안 넘기면 이 값이 쓰인다 —
		# 빼먹었더니 "띄우기"(무게 2.5)만 표에 없어 혼자 실행 시점에 섞이고 있었다.
		if not weights.has(base.weight):
			weights.append(base.weight)
		var variations := SfxBank.VARIATION_COUNT if SfxBank.REPEATING.has(event) else 1
		for weight in weights:
			var request := base.with_weight(weight)
			var available := SfxLibrary.paths_for(request).size()
			var count := mini(variations, maxi(available, 1))
			for variation in count:
				var key := "%s#%d" % [request.bake_key(), variation]
				if seen.has(key):
					continue
				seen[key] = true
				_write(key, request, variation)

	_write_atlas()
	_report()
	quit()


func _clear_out_dir() -> void:
	var dir := DirAccess.open(OUT_DIR)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
		return
	# 큐레이션이 바뀌면 안 쓰는 파일이 남는다. 남으면 팩에 딸려 들어가고 출처도 없다.
	for name in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, name]))


func _write(key: String, request: SfxRequest, variation: int) -> void:
	var clip := SfxRender.render(request, variation)
	if clip.is_empty():
		return
	var index := _keys.size()
	var path := "%s/baked_%03d.wav" % [OUT_DIR, index]
	var error := clip.to_stream().save_to_wav(path)
	if error != OK:
		push_error("굽기 실패 %s (%d)" % [path, error])
		return
	_keys.append(key)
	(
		_rows
		. append(
			{
				"index": index,
				"key": key,
				"seconds": clip.seconds(),
				"rate": clip.rate,
				"bytes": clip.samples.size() * 2,
			}
		)
	)


## 실행 시점이 읽을 표를 코드로 뽑는다. 파일 이름을 런타임에 조립하지 않으려는 것이다 —
## 조립하면 오타가 조용한 무음으로 나타난다.
func _write_atlas() -> void:
	var lines := PackedStringArray()
	lines.append("class_name SfxAtlas")
	lines.append("extends RefCounted")
	lines.append("## **미리 섞어 둔 소리의 표** (docs/design/29-sound.md §29.7.11).")
	lines.append("##")
	lines.append("## `tools/bake_sfx_atlas.gd` 가 생성한다. **손으로 고치지 마라** — 다시 구우면 덮인다.")
	lines.append("##")
	lines.append("## 층 쌓기와 필터를 빌드 시점에 끝내 두었으므로 실행 시점에는 읽기만 한다.")
	lines.append("## 웹에서 굽기가 412 ms 였던 것이 이 표 때문에 사라진다.")
	lines.append("")
	lines.append('const DIR := "%s"' % OUT_DIR)
	lines.append("")
	lines.append("## 요청 열쇠 + 변주 번호 -> 파일 번호.")
	lines.append("const KEYS := {")
	for row in _rows:
		lines.append('\t"%s": %d,' % [row["key"], row["index"]])
	lines.append("}")
	lines.append("")
	lines.append("")
	lines.append("## 미리 구워 둔 것이 있으면 그 경로. 없으면 빈 문자열.")
	lines.append("static func path_for(request: SfxRequest, variation: int) -> String:")
	lines.append('\tvar key := "%s#%d" % [request.bake_key(), variation]')
	lines.append("\tif not KEYS.has(key):")
	lines.append('\t\treturn ""')
	lines.append('\treturn "%s/baked_%03d.wav" % [DIR, KEYS[key]]')
	lines.append("")
	lines.append("")
	lines.append("static func size() -> int:")
	lines.append("\treturn KEYS.size()")
	lines.append("")
	var file := FileAccess.open(ATLAS_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


func _report() -> void:
	var bytes := 0
	var seconds := 0.0
	for row in _rows:
		bytes += int(row["bytes"])
		seconds += float(row["seconds"])
	print("")
	print("=== 미리 섞기 ===")
	print("구운 소리      %d 개" % _rows.size())
	print("오디오 길이    %.2f 초" % seconds)
	print("용량           %.0f KB" % (bytes / 1024.0))
	print("표             %s" % ATLAS_PATH)
	print("파일           %s" % OUT_DIR)
