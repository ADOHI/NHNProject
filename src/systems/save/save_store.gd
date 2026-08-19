class_name SaveStore
extends RefCounted
## 세이브를 **파일에 쓰고 읽는 곳.** `src/systems/` 가 맡는 「어떻게」가 여기다.
##
##     var store := SaveStore.new()
##     store.write(guild, CAMPAIGN_SEED)
##     var result := store.read()
##     if not result.is_ok():
##         print(result.message())     # 왜 못 읽었는지 사람에게 말한다
##
## ## `user://` 인 이유
##
## `res://` 는 내보낸 빌드에서 읽기 전용이다. 거기에 쓰려고 하면 개발 중에는 되고
## 배포본에서만 안 된다 — 가장 늦게 발견되는 종류의 결함이다.
##
## ## ⚠ 웹에서는 사라질 수 있다
##
## 웹에서 `user://` 는 브라우저의 IndexedDB 로 간다. 동작하지만 사용자가 저장소를
## 지우거나 시크릿 창을 닫으면 같이 사라지고, 배포 도메인이 바뀌면 다른 저장소가 된다.
## **본판은 PC 다** — 웹 빌드에서 진행이 남는 것을 보장하지 않는다
## (docs/design/34-systems.md §34.4.6).
##
## ## 오토로드가 아니다
##
## 게임 전체에서 하나여야 할 이유도, 씬 전환에 살아남아야 할 이유도 없다.
## 저장할 때 만들어 쓰고 버린다 (docs/conventions.md §3.3).

const DEFAULT_PATH := "user://save/guild.json"

## 사람이 읽을 수 있게 들여쓴다. 디버깅이 이 빌드의 용도 중 하나다.
const _INDENT := "  "

var _path: String


## 시험과 도구는 자기 경로를 준다. 그러지 않으면 시험이 진짜 세이브를 덮어쓴다.
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func path() -> String:
	return _path


func exists() -> bool:
	return FileAccess.file_exists(_path)


## 지금 상태를 쓴다. 성공하면 `OK` 다.
func write(guild: Guild, campaign_seed: int) -> Error:
	var data := GameSave.capture(guild, campaign_seed)
	if data.is_empty():
		return ERR_INVALID_DATA
	var folder := _path.get_base_dir()
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		push_warning("세이브를 쓰지 못했다 (%d): %s" % [FileAccess.get_open_error(), _path])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, _INDENT))
	file.close()
	return OK


## 읽는다. **못 읽어도 예외를 던지지 않는다** — 사유를 든 결과를 돌려준다.
##
## **깨진 파일을 지우지 않는다.** 그 자리에 그대로 두고 새 게임으로 떨어진다 —
## 사용자가 나중에 그 파일을 열어 볼 수 있어야 한다 (§34.4.4).
func read(build_world: bool = true, npc_world: NpcWorld = null) -> SaveResult:
	if not exists():
		return SaveResult.failed(SaveResult.Status.MISSING)
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return SaveResult.failed(
			SaveResult.Status.UNREADABLE, "오류 %d" % FileAccess.get_open_error()
		)
	var text := file.get_as_text()
	file.close()
	# `JSON.parse_string()` 이 아니라 인스턴스를 쓴다. 정적 쪽은 깨진 입력에
	# **엔진 오류를 밀어 넣고** null 만 돌려줘서, 사용자에게 어디가 깨졌는지 말할 수 없다.
	# 이쪽은 줄 번호를 준다 — 손으로 고치다 깨뜨린 파일이 그 자리를 알려 준다.
	var json := JSON.new()
	if json.parse(text) != OK:
		return SaveResult.failed(
			SaveResult.Status.NOT_JSON, "%d행 %s" % [json.get_error_line(), json.get_error_message()]
		)
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return SaveResult.failed(SaveResult.Status.BAD_SHAPE, "최상위가 사전이 아니다")
	return GameSave.restore(parsed as Dictionary, build_world, npc_world)


## 파일을 지운다. **자동 불러오기는 이것을 부르지 않는다** —
## 새 게임을 사용자가 직접 고르는 자리에서만 쓴다.
func erase() -> Error:
	if not exists():
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
