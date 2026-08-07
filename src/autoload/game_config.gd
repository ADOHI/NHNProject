extends Node
## 전역 설정/빌드 정보. 자동 로드(Autoload)로 등록되어 어디서든 GameConfig 로 접근한다.
##
## 게임 로직은 여기에 넣지 않는다. 여기에 두는 것은
## "빌드 전체에서 변하지 않는 값"과 "런타임 환경 판별"뿐이다.

## 프로젝트 표시 이름. project.godot 의 application/config/name 을 그대로 읽는다.
var title: String:
	get:
		return String(ProjectSettings.get_setting("application/config/name", "NHNProject"))

## 빌드 버전. project.godot 의 application/config/version 을 그대로 읽는다.
var version: String:
	get:
		return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## 웹(HTML5)에서 실행 중인지 여부. 웹 전용 분기(파일 저장, 커서, 오디오 시작 조건 등)에 쓴다.
var is_web: bool:
	get:
		return OS.has_feature("web")


func _ready() -> void:
	print("[%s] v%s / platform=%s" % [title, version, OS.get_name()])
