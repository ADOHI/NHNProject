extends GutTest
## GameConfig 의 단위 테스트.
##
## 오토로드로 등록된 인스턴스를 쓰지 않고 스크립트를 직접 인스턴스화한다.
## 오토로드 등록 여부와 무관하게 클래스 자체의 동작을 검증하기 위해서다.

const GameConfigScript := preload("res://src/autoload/game_config.gd")


func _make_config() -> Node:
	var config: Node = GameConfigScript.new()
	autofree(config)
	return config


func test_title_matches_project_setting() -> void:
	var config := _make_config()
	assert_eq(config.title, ProjectSettings.get_setting("application/config/name"))


func test_version_matches_project_setting() -> void:
	var config := _make_config()
	assert_eq(config.version, ProjectSettings.get_setting("application/config/version"))


func test_version_is_not_placeholder() -> void:
	# 기본값 "0.0.0" 이 반환된다면 project.godot 에서 버전을 못 읽은 것이다.
	var config := _make_config()
	assert_ne(config.version, "0.0.0", "project.godot 의 config/version 을 읽지 못했다")


func test_is_web_is_false_on_desktop() -> void:
	# 테스트는 데스크톱/CI 에서 돈다. 여기서 true 가 나오면 플랫폼 판별이 고장난 것이다.
	var config := _make_config()
	assert_false(config.is_web)
