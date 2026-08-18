class_name SfxSequencer
extends RefCounted
## **소리를 낼지 말지, 어느 벌로 낼지 정하는 규칙** (docs/design/29-sound.md §29.7.12, §29.7.13).
##
## `SfxPlayer` 에서 뽑아냈다. **노드가 아니라 순수 규칙이라야 두 곳이 같은 소리를 낸다** —
## 실행 시점(`SfxPlayer`)과 미리 굽는 데모(`tools/render_sfx_battle.gd`)가
## 서로 다른 규칙을 쓰면 **사용자가 들은 것과 게임에서 나는 것이 달라진다.**
##
## 규칙은 둘이고 둘 다 실측에서 나왔다.
##
## 1. **같은 사건은 셋까지만** — 같은 순간에 겹치면 위상이 맞아 그대로 배가 된다 (§29.7.12)
## 2. **벌은 사건마다 따로 돌린다** — 하나로 세면 전투 중에 변주가 죽는다 (§29.7.13)

## 같은 사건이 이 안에 다시 오면 "겹친 것" 으로 본다.
const SAME_EVENT_WINDOW := 0.06

## 같은 사건을 동시에 몇 개까지 낼지.
##
## 셋이 정확히 같은 순간에 시작하면 피크가 1.308 로 넘쳤다. 넷째부터는
## 커지기만 하고 또렷해지지 않으므로 버린다.
const MAX_SAME_EVENT := 3

## 겹칠 때 뒤엣것을 이만큼 **앞에서부터 건너뛴다.**
##
## 늦추는 것이 아니라 건너뛴다 — 늦추면 지연이 늘지만, 앞을 조금 잘라 내면
## 위상만 어긋나고 타이밍은 그대로다. 4 ms 로 여섯 겹침이 0.839 로 떨어졌다.
const STAGGER_SECONDS := 0.0035

var _picks: Dictionary = {}
var _recent: Dictionary = {}


## 이 사건을 지금 내도 되나.
##
## 돌려주는 것 셋 — `allowed`(낼지), `variation`(몇 번째 벌), `stagger`(앞에서 건너뛸 초).
func request(event: SfxEvent.Kind, now: float) -> Dictionary:
	var overlapping := _count_recent(event, now)
	if overlapping >= MAX_SAME_EVENT:
		return {"allowed": false, "variation": 0, "stagger": 0.0}
	return {
		"allowed": true,
		"variation": _next_pick(event),
		"stagger": overlapping * STAGGER_SECONDS,
	}


## 이 사건이 다음에 쓸 벌 번호.
##
## **한때 이 계수기가 사건 전체에 하나였다.** 은행이 `벌번호 % 벌수` 로 고르므로,
## 발소리 사이에 다른 소리가 두 개씩 끼면 보폭이 3이 되고 벌 수도 3이라
## **같은 파일이 스무 번 내리 나왔다.** 전투 중에만 그렇게 된다 — 조용할 때는 멀쩡했다.
func _next_pick(event: SfxEvent.Kind) -> int:
	var next := int(_picks.get(event, -1)) + 1
	_picks[event] = next
	return next


## 이 사건이 방금 몇 번 났나. 창을 벗어난 기록은 버린다.
func _count_recent(event: SfxEvent.Kind, now: float) -> int:
	var times: Array = _recent.get(event, [])
	var kept: Array = []
	for at in times:
		if now - float(at) < SAME_EVENT_WINDOW:
			kept.append(at)
	kept.append(now)
	_recent[event] = kept
	return kept.size() - 1


func reset() -> void:
	_picks.clear()
	_recent.clear()
