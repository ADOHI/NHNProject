class_name SfxCatalog
extends RefCounted
## 사건 → 요청 표 (docs/design/29-sound.md §29.3).
##
## **이 표가 배치 층과 계약 층을 잇는 유일한 지점이다.**
## 전투 코드는 `SfxEvent.Kind.HIT_LANDED` 까지만 알고, 그게 금속인지 살인지는 여기서 정한다.
##
## 재질을 바꾸고 싶으면 여기 한 줄만 고친다. 사건을 부르는 쪽은 안 건드린다.

## 무기 칸 수(1..4)가 무게를 결정하는 사건들. 배치 층이 `with_weight()` 로 덮어쓴다.
##
## 나머지 사건은 표의 무게를 그대로 쓴다 — UI 팝업에 "칸 수" 같은 것은 없다.
const WEIGHT_DRIVEN: Array = [
	SfxEvent.Kind.HIT_LANDED,
	SfxEvent.Kind.SWING_WHOOSH,
	SfxEvent.Kind.SWING_IMPACT,
	SfxEvent.Kind.HIT_REACTION,
	SfxEvent.Kind.HIT_BOUNCE,
	SfxEvent.Kind.BREAK_STAGGER,
	SfxEvent.Kind.BREAK_LAUNCH,
	SfxEvent.Kind.BREAK_KNOCKDOWN,
]

static var _table: Dictionary = {}


## 사건 하나의 기준 요청. 씨는 0 이라 항상 같은 소리다 — 변주는 재생 쪽이 넣는다.
static func request_for(event: SfxEvent.Kind) -> SfxRequest:
	if _table.is_empty():
		_build()
	return _table.get(event, SfxRequest.impact(SfxMaterial.Kind.WOOD, 1.0))


## 이 사건의 무게가 게임 쪽 숫자(무기 칸 수)에서 오는가.
static func is_weight_driven(event: SfxEvent.Kind) -> bool:
	return WEIGHT_DRIVEN.has(event)


static func _build() -> void:
	var metal := SfxMaterial.Kind.METAL
	var wood := SfxMaterial.Kind.WOOD
	var flesh := SfxMaterial.Kind.FLESH
	var stone := SfxMaterial.Kind.STONE
	var cloth := SfxMaterial.Kind.CLOTH
	var dirt := SfxMaterial.Kind.DIRT
	var up := SfxRequest.Bend.UP
	var down := SfxRequest.Bend.DOWN
	var k := SfxEvent.Kind

	_table = {
		# ── 전투 ─────────────────────────────────────────────────
		# 때리는 쪽은 금속, 맞는 쪽은 살. 둘이 같은 순간에 겹쳐 난다.
		k.HIT_LANDED: SfxRequest.impact(metal, 2.0),
		k.SWING_WHOOSH: SfxRequest.whoosh(cloth, 2.0),
		k.SWING_IMPACT: SfxRequest.impact(flesh, 2.0),
		k.HIT_REACTION: SfxRequest.impact(flesh, 2.0),
		k.HIT_BOUNCE: SfxRequest.impact(dirt, 2.0),
		# 무너짐 문턱 셋은 **같은 재질로 무게만 올린다.** 셋이 한 계단으로 들려야 하므로.
		k.BREAK_STAGGER: SfxRequest.impact(wood, 1.5),
		k.BREAK_LAUNCH: SfxRequest.impact(wood, 2.5),
		k.BREAK_KNOCKDOWN: SfxRequest.impact(wood, 4.0),
		k.DEATH_COLLAPSE: SfxRequest.impact(cloth, 3.0),
		# ── 체인 ─────────────────────────────────────────────────
		k.CHAIN_FIRED: SfxRequest.tone(metal, 2.0, up),
		k.CHAIN_LINK: SfxRequest.tick(metal, 1.0),
		# 일곱 이유 중 NO_OUTPUT 만 정상 종료다. 올라가고, 나머지 여섯은 내려간다.
		k.CHAIN_ENDED: SfxRequest.tone(metal, 2.5, up),
		k.CHAIN_BROKE: SfxRequest.tone(wood, 2.0, down),
		# ── 백팩 ─────────────────────────────────────────────────
		k.PACK_PICKED: SfxRequest.tick(cloth, 1.5),
		k.PACK_PLACED: SfxRequest.impact(wood, 1.5),
		k.PACK_REJECTED: SfxRequest.tone(wood, 1.5, down),
		k.PACK_ROTATED: SfxRequest.tick(metal, 1.0),
		k.PACK_ROTATE_BLOCKED: SfxRequest.tone(wood, 1.0, down),
		k.PACK_TO_TRAY: SfxRequest.tick(cloth, 1.0),
		# ── 발과 몸 ──────────────────────────────────────────────
		# 걷기 1.2초에 2보, 뛰기 0.72초에 2보. 뛰는 쪽이 무겁게 들려야 한다.
		k.FOOT_WALK: SfxRequest.impact(dirt, 1.6).with_gain(0.55),
		k.FOOT_RUN: SfxRequest.impact(dirt, 2.2).with_gain(0.75),
		k.FOOT_SCUFF: SfxRequest.impact(cloth, 1.0).with_gain(0.35),
		k.JUMP_TAKEOFF: SfxRequest.impact(dirt, 2.0).with_gain(0.65),
		k.JUMP_LAND: SfxRequest.impact(dirt, 3.0).with_gain(0.85),
		# ── 이동 지시 ────────────────────────────────────────────
		k.MOVE_ORDERED: SfxRequest.tick(metal, 1.5).with_gain(0.55),
		k.MOVE_ARRIVED: SfxRequest.tick(wood, 1.0).with_gain(0.40),
		k.MOVE_HOLDING: SfxRequest.tick(cloth, 1.0).with_gain(0.30),
		k.MOVE_RESUMED: SfxRequest.tick(wood, 1.0).with_gain(0.30),
		k.MOVE_BLOCKED: SfxRequest.tone(stone, 1.5, down).with_gain(0.50),
		k.MOVE_BACKOFF: SfxRequest.tick(dirt, 1.5).with_gain(0.35),
		k.MOVE_YIELD: SfxRequest.tick(cloth, 1.2).with_gain(0.30),
		k.MOVE_REPATH: SfxRequest.tick(metal, 1.2).with_gain(0.30),
		# ── 단추 ─────────────────────────────────────────────────
		# UI 는 TICK/TONE 이라 SfxVoice 가 한 옥타브 위로 올린다. 전투와 자리를 나눈다.
		k.UI_HOVER: SfxRequest.tick(wood, 1.0).with_gain(0.30),
		k.UI_PRESS: SfxRequest.tick(wood, 1.4).with_gain(0.70),
		k.UI_RELEASE: SfxRequest.tick(wood, 1.1).with_gain(0.42),
		k.UI_DISABLED: SfxRequest.tone(cloth, 1.0, down).with_gain(0.45),
		k.UI_CONFIRM: SfxRequest.tone(metal, 2.0, up).with_gain(0.70),
		k.UI_CANCEL: SfxRequest.tone(wood, 2.0, down).with_gain(0.60),
		# ── 팝업. 뒤 · 판 · 내용 순서가 소리에도 그대로 간다 ────────
		k.UI_VEIL_IN: SfxRequest.whoosh(cloth, 2.0).with_gain(0.40),
		k.UI_PIECE_IN: SfxRequest.tick(wood, 1.2).with_gain(0.28),
		k.UI_CONTENT_IN: SfxRequest.tone(metal, 1.5, up).with_gain(0.40),
		k.UI_CONTENT_OUT: SfxRequest.tone(metal, 1.5, down).with_gain(0.34),
		k.UI_PIECE_OUT: SfxRequest.tick(wood, 1.2).with_gain(0.28),
		k.UI_VEIL_OUT: SfxRequest.whoosh(cloth, 2.5).with_gain(0.34),
		# ── 던전과 게이트 ────────────────────────────────────────
		k.ROOM_ENTERED: SfxRequest.impact(stone, 2.5).with_gain(0.70),
		k.ROOM_REFUSED: SfxRequest.tone(stone, 1.5, down).with_gain(0.55),
		k.ROOM_SHRUG: SfxRequest.tick(cloth, 1.0).with_gain(0.30),
		k.BOARD_STRUCK: SfxRequest.impact(metal, 2.0).with_gain(0.60),
		k.GATE_SELECTED: SfxRequest.tone(metal, 2.0, up).with_gain(0.65),
		k.GATE_ENTERED: SfxRequest.impact(stone, 4.0).with_gain(0.90),
	}
