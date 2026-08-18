extends SceneTree
## 글 많은 화면 전용 형태 여섯을 뽑는다.
##
##     godot --path . -s res://tools/capture_ledger.gd -- .renders/31-ledger-forms still
##     godot --path . -s res://tools/capture_ledger.gd -- .renders/led film
##     python tools/make_gif.py .renders/led .renders/31-ledger-forms.gif 0.46
##
## **정지 한 장과 GIF 를 같이 낸다.** 형태가 사건에 변하므로 정지만으로는 절반이다.
##
## ## 왜 `--resolution` 을 안 쓰고 `SubViewport` 를 쓰나
##
## 형태가 여섯이라 판이 1280x1600 은 되어야 한다. 그런데 `--resolution 1280x1620` 을
## 주면 **창이 화면 높이에 잘려** 1280x1181 이 나온다 — 잘린 줄 모르고 GIF 를 뽑을
## 뻔했다. 게다가 이 저장소는 `stretch/mode="canvas_items"` 라 창을 키우면 좌표계가
## 아니라 **배율**이 커진다. 596x428 카드를 실제 크기로 재려던 것이 무너진다.
##
## `SubViewport` 는 창과 무관한 제 좌표계를 갖는다. 배율 1.0 이 보장되고 화면
## 크기에도 안 걸린다.

const FPS: float = 20.0

## 판 전체. 카드는 596x428 그대로라 **배율 1.0 에서 실제 크기다.**
const SHEET := Vector2i(1280, 1600)

## 손이 닿아 층이 벌어진 순간. **평상 정지 화면은 심심할 수 있고 그건 결함이 아니다** —
## 화려함은 사건의 성질이다(§20.9.5).
const STILL_AT: float = 1.62
const SETTLE := 8

var _prefix := "res://.renders/ledger"
var _film := false
var _stage: SubViewport
var _bench: LedgerBench
var _waited := 0
var _saved := 0
var _posed := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = "res://%s" % args[0]
	_film = args.size() > 1 and args[1] == "film"

	_stage = SubViewport.new()
	_stage.size = SHEET
	_stage.transparent_bg = false
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)

	_bench = load("res://src/ui/kit/ledger_bench.tscn").instantiate() as LedgerBench
	_bench.drive_externally()
	_stage.add_child(_bench)
	_bench.size = Vector2(SHEET)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited <= SETTLE:
		_bench.set_clock(STILL_AT if not _film else 0.0)
		return false
	if not _film:
		_bench.set_clock(STILL_AT)
		var path := _prefix if _prefix.ends_with(".png") else _prefix + ".png"
		print("정지: %s (err=%d)" % [path, _stage.get_texture().get_image().save_png(path)])
		return true
	if _posed != _saved:
		_bench.set_clock(float(_saved) / FPS)
		_posed = _saved
		return false
	_stage.get_texture().get_image().save_png("%s_f%03d.png" % [_prefix, _saved])
	_saved += 1
	if _saved < int(LedgerBench.LOOP * FPS):
		return false
	print("프레임 %d 장: %s" % [_saved, _prefix])
	return true
