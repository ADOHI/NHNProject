class_name SfxEvent
extends RefCounted
## **배치 층** — 소리가 나는 순간의 목록 (docs/design/29-sound.md §29.3).
##
## 여기 있는 것은 새로 정의한 것이 아니다. **다른 레인이 이미 코드로 만들어 둔 순간**을
## 뽑은 것이다. 근거 파일은 §29.3 표의 출처 열에 있다.
##
## 이 enum 은 나중에 안 바뀐다. 원천(합성 → 샘플 → 생성물)이 바뀌어도
## "타격이 들어갔다" 는 사건은 그대로다.

enum Kind {
	# ── 전투 · 타격 ─────────────────────────────────────────────
	HIT_LANDED,  ## SparringBout.hit_landed — 체인 한 타가 들어감
	SWING_WHOOSH,  ## CharSwingClip t=0 — 예비 시작, 공기를 가름
	SWING_IMPACT,  ## CharSwingClip.progress() 가 1.0 을 넘는 순간
	HIT_REACTION,  ## CharHitClip t=0 — 맞은 쪽
	HIT_BOUNCE,  ## CharHitClip t=FREEZE+FLIGHT(0.43) — 바닥에 튐
	# ── 전투 · 무너짐 문턱 셋 ────────────────────────────────────
	BREAK_STAGGER,  ## BreakState.Kind.STAGGER — 30
	BREAK_LAUNCH,  ## BreakState.Kind.LAUNCH — 60
	BREAK_KNOCKDOWN,  ## BreakState.Kind.KNOCKDOWN — 100
	DEATH_COLLAPSE,  ## CharDieClip — 무너져 내림
	# ── 전투 · 체인 ─────────────────────────────────────────────
	CHAIN_FIRED,  ## backpack_board.fire_requested — 발사
	CHAIN_LINK,  ## 체인이 한 칸 진행
	CHAIN_ENDED,  ## StopReason.NO_OUTPUT — 유일한 정상 종료
	CHAIN_BROKE,  ## 나머지 여섯 이유 — 실패로 끝남
	# ── 전투 · 백팩 ─────────────────────────────────────────────
	PACK_PICKED,  ## _begin_drag — 집어 듦
	PACK_PLACED,  ## _end_drag 성공 — 격자에 놓임
	PACK_REJECTED,  ## _end_drag 실패 — 원위치 복귀
	PACK_ROTATED,  ## _rotate 성공
	PACK_ROTATE_BLOCKED,  ## _rotate 실패 — can_place 가 막음
	PACK_TO_TRAY,  ## _send_to_tray_under_mouse — 대기줄로
	# ── 이동 · 발 ───────────────────────────────────────────────
	FOOT_WALK,  ## CharWalkClip.is_planted() 상승 — 한 걸음 (주기당 2회)
	FOOT_RUN,  ## CharRunClip — 뛰는 걸음 (주기당 2회)
	FOOT_SCUFF,  ## CharIdleClip 흔들림 끝 — 제자리에서 발을 끈다
	JUMP_TAKEOFF,  ## CharJumpClip t=CROUCH(0.16)
	JUMP_LAND,  ## CharJumpClip t=0.68
	# ── 이동 · 지시 ─────────────────────────────────────────────
	MOVE_ORDERED,  ## ProtoUnitField.order_issued — 명령 발령
	MOVE_ARRIVED,  ## State.ARRIVED
	MOVE_HOLDING,  ## agent.hold() — 대기
	MOVE_RESUMED,  ## agent.resume()
	MOVE_BLOCKED,  ## State.BLOCKED — 포기
	MOVE_BACKOFF,  ## _BACKOFF_ANGLES 진입 — 물러남
	MOVE_YIELD,  ## ProtoUnitYield.begin() — 비켜섬
	MOVE_REPATH,  ## ProtoUnitJam 재굽기 — 길 다시 찾기
	# ── UI · 단추 ───────────────────────────────────────────────
	UI_HOVER,  ## ActionButtonMotion.enter_hover()
	UI_PRESS,  ## ActionButtonMotion.press()
	UI_RELEASE,  ## ActionButtonMotion.release()
	UI_DISABLED,  ## ActionButtonMotion.disable()
	UI_CONFIRM,  ## 확인 단추
	UI_CANCEL,  ## 취소 단추
	# ── UI · 팝업. 뒤 · 판 · 내용 순서 셋 (20-ui-kit.md §20.11.2) ──
	UI_VEIL_IN,  ## 열림 1 — 뒤가 먼저 온다
	UI_PIECE_IN,  ## 열림 2 — 판 조각이 가운데부터 도착
	UI_CONTENT_IN,  ## 열림 3 — 내용이 마지막에 든다
	UI_CONTENT_OUT,  ## 닫힘 1 — 내용이 먼저 꺼진다
	UI_PIECE_OUT,  ## 닫힘 2 — 판이 바깥부터 접힌다
	UI_VEIL_OUT,  ## 닫힘 3 — 뒤가 마지막에 걷힌다
	# ── 던전 · 게이트 ───────────────────────────────────────────
	ROOM_ENTERED,  ## DungeonRun.player_moved — 방 진입
	ROOM_REFUSED,  ## _on_room_selected 조기 반환 — 못 가는 방을 누름
	ROOM_SHRUG,  ## RoomNode._shrug() — 못 가는 방에 커서
	BOARD_STRUCK,  ## DungeonBoard.struck(at) — 판이 울림
	GATE_SELECTED,  ## GatePanel.gate_selected(index)
	GATE_ENTERED,  ## Expedition.enter() — 입장
}

## 프로토 화면에서 묶어 보여 줄 단위. 소리는 직렬이라 한 번에 한 묶음만 듣는다.
enum Group { COMBAT, CHAIN, PACK, LOCOMOTION, ORDERS, UI_BUTTON, UI_POPUP, WORLD }

## 화면에 쓸 이름. 프로토 화면이 한국어이므로 한글이다.
##
## 가운뎃점(U+00B7) 과 화살표(U+2192) 는 게임 폰트 SongMyung 에 없다. 쓰지 않는다.
const LABELS: Dictionary = {
	Kind.HIT_LANDED: "타격",
	Kind.SWING_WHOOSH: "휘두르기",
	Kind.SWING_IMPACT: "맞음",
	Kind.HIT_REACTION: "피격",
	Kind.HIT_BOUNCE: "바닥 튐",
	Kind.BREAK_STAGGER: "경직",
	Kind.BREAK_LAUNCH: "띄우기",
	Kind.BREAK_KNOCKDOWN: "쓰러짐",
	Kind.DEATH_COLLAPSE: "무너짐",
	Kind.CHAIN_FIRED: "체인 발사",
	Kind.CHAIN_LINK: "체인 진행",
	Kind.CHAIN_ENDED: "체인 정상 종료",
	Kind.CHAIN_BROKE: "체인 끊김",
	Kind.PACK_PICKED: "집어 듦",
	Kind.PACK_PLACED: "놓음",
	Kind.PACK_REJECTED: "놓기 실패",
	Kind.PACK_ROTATED: "회전",
	Kind.PACK_ROTATE_BLOCKED: "회전 막힘",
	Kind.PACK_TO_TRAY: "대기줄로",
	Kind.FOOT_WALK: "걸음",
	Kind.FOOT_RUN: "달리는 걸음",
	Kind.FOOT_SCUFF: "발 끌기",
	Kind.JUMP_TAKEOFF: "도약",
	Kind.JUMP_LAND: "착지",
	Kind.MOVE_ORDERED: "이동 명령",
	Kind.MOVE_ARRIVED: "도착",
	Kind.MOVE_HOLDING: "대기",
	Kind.MOVE_RESUMED: "재개",
	Kind.MOVE_BLOCKED: "막힘",
	Kind.MOVE_BACKOFF: "물러남",
	Kind.MOVE_YIELD: "비켜섬",
	Kind.MOVE_REPATH: "길 다시 찾기",
	Kind.UI_HOVER: "커서 올림",
	Kind.UI_PRESS: "눌림",
	Kind.UI_RELEASE: "뗌",
	Kind.UI_DISABLED: "비활성",
	Kind.UI_CONFIRM: "확인",
	Kind.UI_CANCEL: "취소",
	Kind.UI_VEIL_IN: "뒤 덮임",
	Kind.UI_PIECE_IN: "판 도착",
	Kind.UI_CONTENT_IN: "내용 들어옴",
	Kind.UI_CONTENT_OUT: "내용 나감",
	Kind.UI_PIECE_OUT: "판 접힘",
	Kind.UI_VEIL_OUT: "뒤 걷힘",
	Kind.ROOM_ENTERED: "방 진입",
	Kind.ROOM_REFUSED: "못 가는 방",
	Kind.ROOM_SHRUG: "못 가는 방 커서",
	Kind.BOARD_STRUCK: "판 울림",
	Kind.GATE_SELECTED: "게이트 선택",
	Kind.GATE_ENTERED: "게이트 입장",
}

const GROUP_LABELS: Dictionary = {
	Group.COMBAT: "전투",
	Group.CHAIN: "체인",
	Group.PACK: "백팩",
	Group.LOCOMOTION: "발과 몸",
	Group.ORDERS: "이동 지시",
	Group.UI_BUTTON: "단추",
	Group.UI_POPUP: "팝업",
	Group.WORLD: "던전과 게이트",
}


static func label(kind: Kind) -> String:
	return LABELS.get(kind, "알 수 없음")


## 이 사건이 어느 묶음에 속하는가.
static func group_of(kind: Kind) -> Group:
	if kind <= Kind.DEATH_COLLAPSE:
		return Group.COMBAT
	if kind <= Kind.CHAIN_BROKE:
		return Group.CHAIN
	if kind <= Kind.PACK_TO_TRAY:
		return Group.PACK
	if kind <= Kind.JUMP_LAND:
		return Group.LOCOMOTION
	if kind <= Kind.MOVE_REPATH:
		return Group.ORDERS
	if kind <= Kind.UI_CANCEL:
		return Group.UI_BUTTON
	if kind <= Kind.UI_VEIL_OUT:
		return Group.UI_POPUP
	return Group.WORLD


## 한 묶음에 속한 사건들. 프로토 화면이 목록을 그릴 때 쓴다.
static func of_group(group: Group) -> Array[Kind]:
	var found: Array[Kind] = []
	for value in Kind.values():
		if group_of(value) == group:
			found.append(value)
	return found


## 모든 사건. 실측 도구가 전수 검사할 때 쓴다.
static func all() -> Array[Kind]:
	var found: Array[Kind] = []
	for value in Kind.values():
		found.append(value)
	return found
