class_name BreakState
extends RefCounted
## 무너짐 눈금이 지금 어느 단계인가.
##
## `docs/design/28-combat.md` §28.5 — 사용자 구술로 **경직 · 띄우기 · 바닥 쓰러짐** 셋이 확정됐다.
## *"묵직한 액션 — 경직 · 띄우기 · 바닥 쓰러짐 · 콤보"* (§28.1 확정 14번).
##
## **단계는 확정이고 눈금 값은 미정이다.** 어느 수치에서 무엇이 되는지는
## `BreakTuning` 이 들고 있고, 그것은 아직 정해진 것이 아니다.

enum Kind {
	NONE,  ## 아직 견디고 있다
	STAGGER,  ## 경직 — 잠깐 굳는다
	LAUNCH,  ## 띄우기 — 떠오른다
	KNOCKDOWN,  ## 바닥 쓰러짐 — 넘어진다
}

const _LABELS := {
	Kind.NONE: "멀쩡",
	Kind.STAGGER: "경직",
	Kind.LAUNCH: "띄우기",
	Kind.KNOCKDOWN: "바닥 쓰러짐",
}


static func label(kind: Kind) -> String:
	return _LABELS[kind]


## 단계가 더 심한 쪽인가. enum 값의 크기에 기대지 않고 뜻으로 묻는다.
static func is_worse(kind: Kind, than: Kind) -> bool:
	return int(kind) > int(than)
