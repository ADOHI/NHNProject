extends SceneTree
## 렉카 문안 원문을 자산으로 굽는다.
##
##     godot --headless --path . -s res://tools/build_rekka_library.gd
##
##     docs/design/samples/rekka/stock-library.txt   원문. 사람이 읽고 고친다
##             |
##             v
##     assets/rekka/rekka_library.tres               게임이 load() 한다
##
## ## 왜 원문을 따로 두는가
##
## 자산은 `res://` 에서 `load()` 로 열리는 자원이어야 한다. `FileAccess` 로 원본을
## 읽으면 로컬은 되고 **웹 내보내기에서 깨진다** — 내보내기 필터에 안 걸린 원본은
## `.pck` 에 들어가지 않는다 (docs/design/32-rekka-feed.md §32.3.1).
##
## 그런데 `.tres` 안의 여러 줄 문자열은 줄바꿈이 접혀서 사람이 읽고 고칠 수가 없다.
## 그래서 **읽고 고치는 것은 `.txt`, 싣는 것은 `.tres`** 로 가른다.
##
## 원문이 `docs/design/samples` 아래 `.txt` 라 `tools/check_glyphs_text.gd` 가
## 고치지 않아도 그대로 훑는다. **모델이 쓴 문장은 코드 검사에 안 걸리고,**
## 폰트에 없는 글자는 웹 빌드에서 전부 두부(□)가 된다 (19-rekka-voice.md §19.12).
##
## ## 굽기 전에 검사한다
##
## 자산이 조용히 틀리면 그 조합에서만 이상한 글이 나가고, 그것을 발견하는 것은
## 스무 판 뒤다. 그래서 여기서 막는다 — 모르는 열쇠 · 모르는 자리표시 ·
## 제목 없는 편 · 한 편 안에서 겹친 댓글 자리표시.

const SOURCE_PATH := "res://docs/design/samples/rekka/stock-library.txt"
const OUT_DIR := "res://assets/rekka"

## 자리표시로 쓸 수 있는 이름. 여기 없는 것을 쓰면 그 줄은 런타임에 통째로 버려진다.
const ALLOWED_SLOTS: Array[String] = ["주체", "상대", "방", "등급"]

var _errors: Array[String] = []
var _keys := PackedStringArray()
var _posts := PackedStringArray()


func _initialize() -> void:
	var text := _read(SOURCE_PATH)
	if text.is_empty():
		print("원문을 읽지 못했습니다: %s" % SOURCE_PATH)
		quit(1)
		return

	_parse(text)
	if not _errors.is_empty():
		print("문안 원문에 문제가 있습니다.")
		for line in _errors:
			print("  %s" % line)
		quit(1)
		return

	var library := RekkaLibrary.new()
	library.keys = _keys
	library.posts = _posts
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var error := ResourceSaver.save(library, RekkaLibrary.DEFAULT_PATH)
	if error != OK:
		print("자산을 쓰지 못했습니다: %d" % error)
		quit(1)
		return

	print("문안 %d 편을 실었습니다: %s" % [_keys.size(), RekkaLibrary.DEFAULT_PATH])
	_report()
	quit(0)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


## 원문을 편 단위로 가른다.
##
## **`==` 는 첫 칸에서만 열쇠다.** 파일 머리의 형식 설명이 들여쓴 `==` 를 쓰고 있어서,
## 다듬은 뒤에 판정하면 그 설명 줄이 편으로 잡힌다.
func _parse(text: String) -> void:
	var key := ""
	var lines: Array[String] = []
	for raw in text.split("\n"):
		var line: String = (raw as String).strip_edges(false, true)
		if line.begins_with("== "):
			_flush(key, lines)
			key = line.substr(3).strip_edges()
			lines = []
			continue
		if key.is_empty():
			continue
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		lines.append(trimmed)
	_flush(key, lines)


## 한 편을 검사하고 담는다.
func _flush(key: String, lines: Array[String]) -> void:
	if key.is_empty():
		return
	if lines.is_empty():
		_errors.append("%s — 내용이 없습니다" % key)
		return
	if not _known_key(key):
		_errors.append("%s — 모르는 열쇠입니다" % key)
	if lines[0].begins_with("["):
		_errors.append("%s — 첫 줄이 제목이어야 하는데 댓글입니다" % key)
	_check_slots(key, lines)
	_check_marks(key, lines)
	_keys.append(key)
	_posts.append("\n".join(lines))


## 열쇠가 실제로 만들어질 수 있는 것인가.
##
## `RekkaLibrary.key_for()` 가 만드는 것과 같은 꼴이어야 한다. 등급은 그 종류의
## 축에 있는 것만 쓸 수 있고, 인원이 기록되지 않은 사건은 등급이 빈다.
func _known_key(key: String) -> bool:
	if key == RekkaLibrary.QUIET_KEY:
		return true
	var parts := key.split(":")
	if parts.size() != 2:
		return false
	var kind := _kind_named(parts[0])
	if kind < 0:
		return false
	var grade: String = parts[1]
	if grade.is_empty():
		return true
	match RekkaPrompt.axis_of(kind):
		RekkaPrompt.Axis.HAUL:
			return RekkaPrompt.HAUL_GRADES.has(grade)
		RekkaPrompt.Axis.CROWD:
			return RekkaPrompt.CROWD_GRADES.has(grade)
		_:
			return false


func _kind_named(name: String) -> int:
	for kind in RekkaLibrary.KIND_NAMES:
		if RekkaLibrary.KIND_NAMES[kind] == name:
			return kind
	return -1


## 모르는 자리표시를 막는다. 런타임에는 그 줄이 조용히 사라질 뿐이라 안 보인다.
func _check_slots(key: String, lines: Array[String]) -> void:
	for line in lines:
		for token in RekkaSlots.keys_in(line):
			var matched := false
			for slot in ALLOWED_SLOTS:
				if token.begins_with(slot):
					matched = true
					break
			if not matched:
				_errors.append("%s — 모르는 자리표시 {%s}" % [key, token])


## 한 편 안에서 댓글 자리표시가 겹치면 안 된다.
##
## `RekkaPost.apply_handles()` 는 **원래 닉이 같으면 같은 사람**으로 본다.
## 겹쳐 두면 댓글 넷이 통째로 한 사람이 되고, 그것은 편을 이어서 읽을 때 드러난다.
func _check_marks(key: String, lines: Array[String]) -> void:
	var seen: Dictionary = {}
	for i in range(1, lines.size()):
		var line: String = lines[i]
		if not line.begins_with("["):
			continue
		var close := line.find("]")
		if close < 0:
			_errors.append("%s — 닫히지 않은 댓글 자리표시: %s" % [key, line])
			continue
		var mark := line.substr(1, close - 1)
		if seen.has(mark):
			_errors.append("%s — 댓글 자리표시가 겹칩니다: [%s]" % [key, mark])
		seen[mark] = true


## 어느 열쇠에 몇 편이 실렸는가. **빈칸이 어디인지 보이는 것이 이 표의 목적이다.**
##
## 빈칸에서는 예비 문안이 나가므로 피드가 비지는 않는다. 다만 어디가 밋밋한지는
## 알고 있어야 다음 사람이 그 자리부터 채운다.
func _report() -> void:
	var counts: Dictionary = {}
	for key in _keys:
		counts[key] = int(counts.get(key, 0)) + 1
	var listed: Array[String] = []
	for key in counts:
		listed.append("%s x%d" % [key, counts[key]])
	listed.sort()
	print("열쇠 %d 종: %s" % [counts.size(), ", ".join(listed)])
