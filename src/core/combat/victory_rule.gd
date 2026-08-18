class_name VictoryRule
extends RefCounted
## **싸움이 언제 끝나는가.** `docs/design/28-combat.md` §28.20.43.
##
## ## 이것이 지금까지 표 전부의 전제였다
##
## §28.20.36 부터 §28.20.41 까지 스무 개 남짓한 표가 전부 **「전원 눕히기」** 위에 서 있다.
## 그런데 **그 조건을 아무도 정한 적이 없다.** 측정 도구가 편의상 고른 것이
## 표 전부의 전제가 됐다.
##
## §28.20.39 의 「우리에게 유리한 가정」보다 **큰 가정이다** — 저것은 표를 낙관적으로
## 읽게 할 뿐이지만, 이것은 **어느 규칙이 이기는지 자체를 바꾼다** (§28.20.41).
##
## ## 그래서 값이 아니라 손잡이다
##
## 넷을 만들어 두고 **아무것도 고르지 않는다.** 어느 조건이냐는 게임의 성격을 정하는
## 물음이고 사용자가 정한다. `tools/survey_victory.gd` 가 조건마다 표를 낸다.
##
## ## 판을 안 바꾼다
##
## 이 클래스는 **끝났는지를 읽을 뿐** `SparringBout` 을 멈추거나 적을 치우지 않는다.
## 「과반이 누우면 나머지는 흩어진다」의 **흩어지는 것**은 아직 안 만들었다 —
## 그건 §28.10 의 제압 · 협상과 이어지는 이야기고 여기서 발명할 것이 아니다.
##
## **다만 승패 판정에는 영향이 없다.** 조건에 먼저 닿은 쪽이 이긴 것이고,
## 진 쪽의 나머지가 흩어지든 말든 그 시각은 같다.

enum Kind {
	ALL_DOWN,  ## 전원 눕히기 (지금까지의 모든 표가 이것이다)
	MAJORITY,  ## 과반이 누우면 나머지는 흩어진다
	ANY_ONE,  ## 하나만 눕히면 끝 — 지휘관 · 우두머리가 있는 판
	TIMED,  ## 시간 안에 얼마나 눕혔나 — 버티기
	LEADER,  ## **우두머리 하나** — 사람 무리는 제압하면 나머지가 물러난다 (§28.10)
}

## **한 판에 조건이 둘이면 어떻게 판정하나** (§28.20.44).
##
## 몬스터와 사람이 같이 나오는 판이다. §28.10 이 둘의 끝을 다르게 확정했으므로
## **조건이 무리마다 달라진다.** 그것을 어떻게 합치느냐가 새 물음이다.
##
## **정하지 않는다.** 둘 다 재고 표를 낸다.
enum Mixed {
	EVERY_GROUP,  ## 무리가 다 정리돼야 끝 — 제일 늦은 무리가 정한다
	ANY_GROUP,  ## 한 무리만 정리되면 끝
}

## `TIMED` 에서 재는 시간. **표본이지 확정이 아니다.**
## 표본 체인 한 바퀴가 3~4초이므로(§28.20.40) 그 두어 배다.
const DEFAULT_TIME_LIMIT := 10.0

const _LABELS := {
	Kind.ALL_DOWN: "전원 눕히기",
	Kind.MAJORITY: "과반",
	Kind.ANY_ONE: "하나만",
	Kind.TIMED: "시간 안에",
	Kind.LEADER: "우두머리",
}


static func label(kind: Kind) -> String:
	return _LABELS[kind]


## **몇이 누워야 그쪽이 진 것인가.**
##
## `TIMED` 는 수가 아니라 시간이 정하므로 여기서는 전원으로 둔다 —
## 그 조건을 쓰는 쪽이 `DEFAULT_TIME_LIMIT` 시점의 머릿수를 직접 견준다.
static func needed(kind: Kind, total: int) -> int:
	if total <= 0:
		return 0
	match kind:
		Kind.ANY_ONE:
			return 1
		Kind.MAJORITY:
			return total / 2 + 1
		_:
			return total


## 무너진 시각들을 받아 **그쪽이 진 시각**을 낸다. 안 졌으면 `INF`.
##
## 받는 것은 정렬 안 된 목록이어도 된다 — 여기서 세운다.
static func decided_at(kind: Kind, down_times: PackedFloat32Array, total: int) -> float:
	var want := needed(kind, total)
	if want <= 0:
		return INF
	var sorted := down_times.duplicate()
	sorted.sort()
	if want > sorted.size():
		return INF
	return sorted[want - 1]


## **우두머리가 누우면 그 무리는 정리된다** (§28.10 — 사람은 제압이다).
##
## `ANY_ONE`(아무나 하나)과 다르다. **특정한 하나**라서 아무 규칙도 그를 안 노리면
## 훨씬 오래 걸린다 — 그것이 §28.20.44 가 잰 것이다.
##
## 우두머리가 없는 무리(몬스터)면 `INF` 다. 그 무리는 다른 조건으로 판정한다.
static func leader_decided_at(down_times: PackedFloat32Array, leader: int) -> float:
	if leader < 0 or leader >= down_times.size():
		return INF
	return down_times[leader]


## 무리마다의 정리된 시각을 합쳐 **판이 끝난 시각**을 낸다.
static func mixed_decided_at(kind: Mixed, group_times: PackedFloat32Array) -> float:
	if group_times.is_empty():
		return INF
	var worst := 0.0
	var best := INF
	for at in group_times:
		worst = maxf(worst, at)
		best = minf(best, at)
	return best if kind == Mixed.ANY_GROUP else worst
