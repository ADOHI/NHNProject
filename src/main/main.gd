extends Control
## 부트 씬 겸 진입점. 표본 던전 한 판을 만들어 판 화면에 넘긴다.
##
## 아웃게임(주둔지)이 생기면 이 씬은 "어떤 씬을 띄울지 결정"만 하고 물러난다.
## 플레이 로직은 여기에 쌓지 않는다.

@onready var _board: Control = %DungeonBoard
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_status_label.text = _build_status_text()
	# 시드를 고정해 두면 같은 판이 나온다. 판을 바꿔 보려면 이 값을 바꾼다
	# (docs/design/17-dungeon-generation.md §17.7).
	_board.setup(SampleDungeons.create_run(1))


## 화면 구석에 띄울 런타임 상태 문자열.
## 웹 빌드에서 "브라우저에서 실제로 뭐가 돌고 있는지"를 눈으로 확인하는 용도다.
func _build_status_text() -> String:
	return (
		"%s v%s   ·   Godot %s   ·   %s"
		% [
			GameConfig.title,
			GameConfig.version,
			Engine.get_version_info().string,
			"web" if GameConfig.is_web else OS.get_name(),
		]
	)
