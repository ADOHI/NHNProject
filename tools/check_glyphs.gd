extends SceneTree
## 화면에 뿌리는 글자 중 폰트에 없는 것을 찾아낸다.
##
##     godot --headless --path . -s res://tools/check_glyphs.gd
##
## **로컬 렌더링은 이 문제를 숨긴다.** 데스크톱에서는 폰트에 없는 글자를
## OS 가 시스템 폰트로 대신 그려 주기 때문에 멀쩡해 보인다.
## 그러나 웹 빌드에는 빌려 올 시스템 폰트가 없어서 전부 두부(□)가 된다.
##
## 실제로 ▲ ▼ · 를 쓰다가 이 함정에 걸렸다. 캡처로는 멀쩡했고
## 브라우저에서만 깨졌다. 그래서 눈이 아니라 폰트에게 직접 물어본다.

const _SCAN_DIRS := ["res://src"]
const _EXTENSIONS := ["gd", "tscn"]

## 문자열 안에 있어도 화면에 나가지 않는 것들. 경로·식별자·서식 지정자.
const _IGNORED := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

var _font: Font
var _missing: Dictionary = {}


func _initialize() -> void:
	var font_path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if font_path.is_empty():
		print("프로젝트에 테마 폰트가 지정되어 있지 않습니다.")
		quit()
		return

	_font = load(font_path)
	if _font == null:
		print("폰트를 불러오지 못했습니다: %s" % font_path)
		quit(1)
		return

	print("폰트: %s" % font_path)
	for directory in _SCAN_DIRS:
		_scan(directory)
	_report()
	quit(1 if not _missing.is_empty() else 0)


func _scan(directory: String) -> void:
	for name in DirAccess.get_directories_at(directory):
		_scan("%s/%s" % [directory, name])
	for name in DirAccess.get_files_at(directory):
		if name.get_extension() in _EXTENSIONS:
			_scan_file("%s/%s" % [directory, name])


func _scan_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var line := file.get_line()
		var trimmed := line.strip_edges()
		# 주석은 화면에 나가지 않는다.
		if trimmed.begins_with("#"):
			continue
		for text in _quoted_parts(line):
			_check(text, path, line_number)


## 한 줄에서 따옴표로 묶인 조각들을 꺼낸다.
func _quoted_parts(line: String) -> Array[String]:
	var parts: Array[String] = []
	var inside := false
	var current := ""
	for i in line.length():
		var character := line[i]
		if character == '"':
			if inside:
				parts.append(current)
				current = ""
			inside = not inside
		elif inside:
			current += character
	return parts


func _check(text: String, path: String, line_number: int) -> void:
	for i in text.length():
		var character := text[i]
		var code := character.unicode_at(0)
		if code < 128 or _IGNORED.contains(character):
			continue
		if _font.has_char(code):
			continue
		var key := character
		if not _missing.has(key):
			_missing[key] = []
		(_missing[key] as Array).append("%s:%d" % [path.get_file(), line_number])


func _report() -> void:
	if _missing.is_empty():
		print("폰트에 없는 글자 없음.")
		return
	print("")
	print("폰트에 없는 글자 %d 종:" % _missing.size())
	for character in _missing:
		var places: Array = _missing[character]
		print("  %s  U+%04X  <- %s" % [character, character.unicode_at(0), ", ".join(places)])
	print("")
	print("데스크톱에서는 시스템 폰트로 대체되어 보이지만 웹에서는 두부가 됩니다.")
