extends SceneTree
## **턴이 도는 것을 눈으로 본다.** 한 번 띄워 여러 턴을 몰아 찍는다.
##
##     godot --path . -s res://tools/capture_turn_loop.gd -- .renders-turn-loop
##
## 창을 띄우는 실행을 아끼는 규칙(CLAUDE.md GPU 절 3)을 따른다 — 턴마다 띄우고 닫지 않고
## **한 창에서 여덟 턴을 걸어** 프레임을 차례로 뽑는다.
##
## ## 교정쇄를 켜고 찍는다
##
## 플레이 화면은 방 안을 숨기는 것이 곧 재미라서, 숨긴 채로 찍으면
## **NPC 가 움직였는지 화면으로 확인할 수 없다.** 교정쇄(F1)를 켜면 방마다
## 실제 위험도와 개체 수가 드러나므로, 몬스터는 그대로인데 어느 방의 수가
## 옮겨 다니는 것이 그대로 보인다 — 그것이 §13.5 가 말한 「사람의 흔적」이다.
##
## ## 조작을 흉내 내지 않고 **화면의 경로로** 건다
##
## `DungeonRun` 을 직접 부르면 화면·피드·지면이 이어져 있는지는 검증되지 않는다.
## 그래서 `DungeonBoard._on_room_selected()` 를 부른다 — 사람이 방을 누른 것과 같은 길이다.

## 몇 턴을 걸을 것인가.
const TURNS := 8

## 판 크기. 작으면 NPC 가 금방 나가 버리고, 크면 한 화면에 안 담긴다.
const BOARD_SIZE := 2

## 시드. **박아 둔다** — 캡처는 몇 번을 돌려도 같은 편이 나와야 판정에 쓸 수 있다.
const SEED := 4242

## 화면이 자리를 잡을 때까지 기다릴 프레임.
##
## **넉넉해야 한다.** 턴이 넘어갈 때마다 지면이 다시 찍히는 연출(`PressPlate`)이 돌고,
## 14 프레임에서는 **굵은 점 덩어리가 지나가는 중간이 찍혔다** — 판도 기사도 안 읽혔다.
## 연출을 끄지 않고 기다리는 이유는, 캡처가 **사람이 보는 화면**이어야 하기 때문이다.
const SETTLE := 100

var _prefix := ".renders-turn-loop"
var _main: Node
var _turn := 0
var _wait := SETTLE
var _installed := false
var _shot := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://%s" % _prefix))
	_main = load("res://src/ui/dungeon_board/dungeon_screen.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if not _installed:
		_install()
		return false
	if not _shot:
		_save()
		return false
	if _turn >= TURNS:
		print("턴 %d 개: %s" % [TURNS, ProjectSettings.globalize_path("res://%s" % _prefix)])
		return true
	_step()
	return false


## 판을 세우고 숨김을 걷는다.
func _install() -> void:
	var slider := _main.find_child("SizeSlider", true, false)
	if slider != null:
		(slider as Range).value = float(BOARD_SIZE)
	_main.set("_seed", SEED)
	_main.call("_build_run")
	_main.call("_update_size_label")
	var board := _board()
	if board != null:
		board.set("reveal_everything", true)
		board.call("redraw")
	_installed = true
	_wait = SETTLE


## 한 턴 건다. **갈 수 있는 방 중 아직 안 가 본 곳을 고른다.**
##
## 무작위로 고르면 두 방 사이를 오가느라 판이 안 열리고, 그러면 NPC 와 마주칠 일도 없다.
func _step() -> void:
	var board := _board()
	var run := _run()
	if board == null or run == null or run.finished:
		_turn = TURNS
		return
	var target := _pick(run)
	if target.is_empty():
		_turn = TURNS
		return
	board.call("_on_room_selected", target)
	_turn += 1
	_shot = false
	_wait = SETTLE


## 갈 곳. 안 가 본 방이 우선이고, 없으면 첫 번째 방이다.
func _pick(run: DungeonRun) -> String:
	var reachable := run.reachable_room_ids()
	if reachable.is_empty():
		return ""
	for room_id in reachable:
		if not run.memory.has_visited(room_id):
			return room_id
	return reachable[0]


## 이 턴의 화면과 **숫자를 함께 남긴다.**
##
## 그림만 남기면 나중에 "이때 위험도가 몇이었나"를 다시 세어야 한다.
## 문서가 인용할 수 있게 한 줄로 적어 둔다 (docs/conventions.md §6.3).
func _save() -> void:
	var run := _run()
	var path := "res://%s/turn_%02d.png" % [_prefix, _turn]
	var error := root.get_texture().get_image().save_png(path)
	print(
		(
			"턴 %d — 스쿼드 %s · 인접 %d %s · %s · 사건 %d · 편 %d (err=%d)"
			% [
				run.turn,
				run.blueprint.display_name_of(run.player_room_id()),
				run.adjacent_threat(),
				run.threat_change_text if not run.threat_change_text.is_empty() else "변화 없음",
				_rivals_text(run),
				run.event_log.count(),
				_feed_count(),
				error,
			]
		)
	)
	_shot = true
	_wait = 2


## 경쟁자가 지금 어느 방에 있는가.
##
## **이 줄이 이 캡처의 핵심이다.** 몬스터는 안 움직이므로, 여기 적힌 방이 턴마다
## 달라지는 것이 곧 위험도 변화량의 정체다 (docs/design/13-information-design.md §13.5).
func _rivals_text(run: DungeonRun) -> String:
	var parts: Array[String] = []
	for room_id in run.graph.room_ids():
		var where := run.blueprint.display_name_of(room_id)
		for actor in run.graph.get_room(room_id).occupants():
			if actor.kind != Actor.Kind.NPC_EXPLORER:
				continue
			var carried := run.haul.carried_by(actor.id)
			parts.append("%s %s(짐 %d)" % [actor.display_name, where, carried])
	return "경쟁자 없음" if parts.is_empty() else " ".join(parts)


func _feed_count() -> int:
	var feed: RekkaFeed = _main.get("_feed")
	return 0 if feed == null else feed.count()


func _run() -> DungeonRun:
	return _main.get("_run") as DungeonRun


## 화면 위의 판. 이름으로 먼저 찾는다 — 타입으로 찾으면 인스턴스된 씬에서 빗나간다.
func _board() -> Node:
	var named := _main.find_child("DungeonBoard", true, false)
	if named != null:
		return named
	var found := root.find_children("*", "DungeonBoard", true, false)
	return found[0] if not found.is_empty() else null
