extends Node2D
## 부트 씬. 지금은 빌드가 실제로 구동되는지 확인하는 최소 화면만 담당한다.
##
## 게임 콘텐츠가 붙기 시작하면 이 씬은 "어떤 씬을 띄울지 결정하는 진입점"으로만 남기고,
## 실제 플레이 로직은 scenes/ 하위의 별도 씬 + scripts/ 하위의 별도 스크립트로 분리한다.

@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_title_label.text = GameConfig.title
	_status_label.text = _build_status_text()


## 화면 하단에 띄울 런타임 상태 문자열을 만든다.
## 웹 빌드 제출 시 "브라우저에서 실제로 뭐가 돌고 있는지"를 눈으로 확인하는 용도.
func _build_status_text() -> String:
	var lines := [
		"v%s" % GameConfig.version,
		"Godot %s" % Engine.get_version_info().string,
		"renderer: %s" % RenderingServer.get_video_adapter_api_version(),
		"platform: %s" % ("web" if GameConfig.is_web else OS.get_name()),
	]
	return "\n".join(lines)
