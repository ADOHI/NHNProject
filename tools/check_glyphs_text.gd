extends SceneTree
## 표본 기사 텍스트 중 폰트에 없는 글자를 찾아낸다.
##
##     godot --headless --path . -s res://tools/check_glyphs_text.gd
##
## tools/check_glyphs.gd 는 res://src 의 **따옴표 안 문자열**만 훑는다.
## 렉카 기사는 언어 모델이 만들어 화면에 그대로 올라가므로 코드 안에 없고,
## 그래서 그 검사에 걸리지 않는다. 같은 폰트에게 따로 물어보는 것이 이 파일이다.
##
## **언어 모델은 시키지 않으면 이모지를 넣는다.** 데스크톱에서는 시스템 폰트가
## 대신 그려 주어 멀쩡해 보이지만 웹 빌드에서는 전부 두부(□)가 된다
## (docs/conventions.md §5.1).
##
## 검사 대상은 `.txt` 뿐이다. 표본 폴더의 `.md` 는 실패 사례를 일부러 담고 있어서
## 검사하면 항상 실패한다. **화면에 나갈 텍스트만 `.txt` 로 둔다**는 규칙으로 가른다
## (docs/design/19-rekka-voice.md §19.8).

const _SCAN_DIRS := ["res://docs/design/samples"]
const _EXTENSION := "txt"

var _font: Font
var _missing: Dictionary = {}
var _checked := 0


func _initialize() -> void:
	var font_path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if font_path.is_empty():
		print("프로젝트에 테마 폰트가 지정되어 있지 않습니다.")
		quit(1)
		return

	_font = load(font_path)
	if _font == null:
		print("폰트를 불러오지 못했습니다: %s" % font_path)
		quit(1)
		return

	print("폰트: %s" % font_path)
	for directory in _SCAN_DIRS:
		_scan(directory)
	print("검사한 파일: %d" % _checked)
	_report()
	quit(1 if not _missing.is_empty() else 0)


func _scan(directory: String) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for name in DirAccess.get_directories_at(directory):
		_scan("%s/%s" % [directory, name])
	for name in DirAccess.get_files_at(directory):
		if name.get_extension() == _EXTENSION:
			_scan_file("%s/%s" % [directory, name])


func _scan_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("열 수 없음: %s" % path)
		return
	_checked += 1
	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		_check(file.get_line(), path, line_number)


func _check(text: String, path: String, line_number: int) -> void:
	for i in text.length():
		var character := text[i]
		var code := character.unicode_at(0)
		if code < 128:
			continue
		if _font.has_char(code):
			continue
		if not _missing.has(character):
			_missing[character] = []
		(_missing[character] as Array).append("%s:%d" % [path.get_file(), line_number])


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
	print("웹 빌드에서 전부 두부(□)가 됩니다. 프롬프트의 금지 목록에 추가하세요.")
