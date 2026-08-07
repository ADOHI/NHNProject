class_name TurnPhase
extends RefCounted
## 한 턴을 이루는 두 국면. 계획과 행동은 반드시 갈라져 있어야 한다.
##
##     계획 페이즈 — 읽고 정한다. 판은 멈춰 있다.
##       · 렉카 기사를 읽는다 (docs/design/08-ui-ux.md §8.3)
##       · 인접 위험도 합을 본다 (docs/design/07-level-design.md §7.2)
##       · 이번 턴에 할 일을 제출한다
##
##     행동 페이즈 — 제출된 의도가 **동시에** 풀린다. 조작은 받지 않는다.
##       · 모든 주체가 같은 순간에 움직인다 (docs/design/03-core-loop.md §3.6)
##       · 그 결과가 사건으로 기록되고, 다음 계획 페이즈의 기사가 된다
##
## 두 국면을 나누지 않으면 먼저 움직인 쪽이 남의 결과를 보고 정하게 되어
## 동시성이 무너진다. 그 순간 "정보를 읽고 건다"는 이 게임의 축이 사라진다.

enum Kind {
	PLANNING,  ## 읽고 정한다. 조작을 받는 유일한 국면이다
	ACTION,  ## 제출된 의도가 동시에 풀린다. 조작을 받지 않는다
}


## 화면에 띄우는 이름.
static func label(phase: Kind) -> String:
	match phase:
		Kind.PLANNING:
			return "계획"
		Kind.ACTION:
			return "행동"
	return "알 수 없음"


## 이 국면에서 플레이어의 조작을 받는가.
##
## 화면은 이 함수 하나만 보고 입력을 막는다. 국면마다 개별로 판단하게 두면
## 새 조작을 붙일 때 한 곳을 빠뜨려 행동 페이즈에 개입할 수 있게 된다.
static func accepts_input(phase: Kind) -> bool:
	return phase == Kind.PLANNING
