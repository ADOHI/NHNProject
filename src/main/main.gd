extends Control
## 부팅. **어떤 화면을 띄울지 고르고 물러난다.**
##
## docs/architecture.md 가 이 씬에 대해 처음부터 적어 둔 것이 이것이다 —
## *"콘텐츠가 생기면 이 씬은 진입점 역할만 남긴다. 플레이 로직을 여기에 쌓지 않는다."*
## 한동안은 이것이 던전 화면 그 자체였고(310줄), 그 로직은
## `src/ui/dungeon_board/dungeon_screen.tscn` 으로 내려갔다
## (docs/design/34-systems.md §34.5).
##
## `project.godot` 의 `run/main_scene` 은 **그대로 여기다.** 부팅 경로를 바꾸지 않는다 —
## 바꾸면 웹 셸과 벤치 도구들이 같이 흔들린다.
##
## ## 여기서 무엇을 하는가
##
## 테마를 물리고, 첫 화면으로 넘긴다. 그게 전부다.
## **씬을 직접 부르지 않는다** — 어디로 갈지는 `Router` 가 안다.

## 부팅이 닿는 첫 화면. 흐름의 시작은 타이틀이다 (docs/design/08-ui-ux.md §8.1).
const FIRST_SCREEN := SceneRoutes.Screen.TITLE

var _notice: Label


func _ready() -> void:
	# Theme 은 루트에 한 번만 물린다. 넘어간 화면은 자기 루트에서 다시 문다 —
	# 씬을 갈아 끼우면 이 노드는 트리에서 빠지므로 여기 물린 것은 따라가지 않는다.
	theme = UiTheme.get_theme()
	_build()
	Router.route_failed.connect(_on_route_failed)
	# 한 프레임 뒤에 넘긴다. `change_scene_to_file` 은 프레임 끝에 처리되므로
	# 부팅 프레임에 흰 화면이 스치지 않도록 종이색을 먼저 깔아 둔다.
	Router.go_to(FIRST_SCREEN)


## 부팅 한 프레임 동안 보이는 것. 종이 한 장과 한 줄이 전부다.
func _build() -> void:
	var paper := ColorRect.new()
	paper.color = UiTokens.PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)

	_notice = Label.new()
	_notice.set_anchors_preset(Control.PRESET_CENTER)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice.grow_vertical = Control.GROW_DIRECTION_BOTH
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.text = "%s v%s" % [GameConfig.title, GameConfig.version]
	add_child(_notice)


## 첫 화면으로 못 갔다. **부팅이 조용히 멈추면 아무도 이유를 모른다** —
## 흰 화면이 아니라 사유를 띄운다.
func _on_route_failed(screen: int, reason: String) -> void:
	_notice.text = "첫 화면을 열지 못했다 — %s (%s)" % [SceneRoutes.label(screen), reason]
	push_error("부팅 실패: %s — %s" % [SceneRoutes.path_of(screen), reason])
