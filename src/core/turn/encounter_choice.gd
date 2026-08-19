class_name EncounterChoice
extends RefCounted
## 조우에서 고를 수 있는 것과, 고른 뒤에 그것이 얼마나 무거운가.
##
## docs/design/05-rules.md §5.8 의 흐름도가 넷을 적었다 —
## 전투 · 협상 · 도주 · (몬스터방) 협력.
## docs/design/35-encounter.md §35.1 · §35.3.
##
## ## 다섯째가 있다 — **대치**
##
## §5.8 의 넷은 **고른** 것들이다. 아무것도 안 고른 주체가 반드시 생긴다 —
## 마주칠 줄 모르고 걸어 들어간 자, 화면이 아직 물어보지 못한 자.
## 그것을 빈 값으로 두면 판정마다 "선택이 없으면" 분기가 붙고,
## **그 분기는 반드시 한 곳에서 빠진다** (`TurnIntent.stay()` 가 같은 이유로 있다).
##
## 그래서 안 고른 것도 선택으로 둔다. 그 대가는 아래 계수가 문다.
##
## ## 계수가 E3 의 답이다
##
## docs/design/05-rules.md §5.6 E3 은 *"서로를 동시에 공격"* 을 보류로 남기며
## *"전투는 주고받기식이 아니다"* 라고 적었다. 그것이 그대로 답이다 —
## **동시 공격에 보정을 얹지 않고, 치지 않은 쪽에 벌점을 준다.**
##
## 반대로 만들었다면 서로 치는 것이 특별한 사건이 되고 **안 치는 쪽이 기본**이 되어
## 아무도 안 치는 판이 됐을 것이다 (docs/design/35-encounter.md §35.3.1).

enum Kind {
	STAND,  ## 대치. **아무것도 안 골랐다.** 눈앞의 상대를 보고 있을 뿐이다
	FIGHT,  ## 전투
	NEGOTIATE,  ## 협상. **양쪽이 다 골라야 성립한다** (§35.2.1)
	FLEE,  ## 도주 시도
	COOPERATE,  ## 협력해서 몬스터와 싸움. **몬스터가 있을 때만 열린다** (E9)
}

## 태세 계수 백분율. 정수로 든다 — 실수로 재면 같은 판이 기계마다 다르게 기운다.
##
## docs/design/35-encounter.md §35.3.1 의 표다. **잠정이다.**
const WEIGHT_FULL := 100  ## 칠 뜻이 있다. 전투 · 협력
const WEIGHT_STANDING := 60  ## 준비가 덜 됐다
const WEIGHT_EXPOSED := 50  ## 말을 걸다 맞았다 · 등을 보였다

const _LABELS := ["대치", "전투", "협상", "도주", "협력"]


## 선택지의 개수. 점수 배열의 길이이기도 하다.
static func count() -> int:
	return _LABELS.size()


## 화면과 개발 도구가 쓰는 이름. 장식 기호를 안 쓴다 (docs/conventions.md §5.1).
static func label(kind: Kind) -> String:
	return _LABELS[clampi(int(kind), 0, _LABELS.size() - 1)]


## 그 조우에서 그 선택이 열려 있는가.
##
## **「협력」을 여는 것은 방이 아니라 몬스터다** (§35.3.2). 방 종류로 열면
## 몬스터가 이미 죽은 몬스터방에서도 열리고, 그러면 무엇과 협력한다는 말인가.
## §5.8 의 넷째 분기는 *"협력해서 **몬스터와** 싸움"* 이므로 조건은 몬스터의 존재다.
static func is_open(kind: Kind, has_monsters: bool) -> bool:
	if kind == Kind.COOPERATE:
		return has_monsters
	return true


## 열려 있지 않은 선택을 무엇으로 읽는가.
##
## 거절하지 않고 **가장 가까운 것으로 내린다.** 거절하면 화면이 "왜 안 됐지"를
## 설명해야 하는데, 조우 선택은 상황을 모르는 채로 내는 것이라
## (§35.1.2 — *"금고로 간다. 거기서 누굴 만나면 협력한다"*)
## 낼 때는 몬스터가 있을지 알 수 없다. 협력할 상대가 없으면 그냥 싸우는 것이 맞다.
static func settle(kind: Kind, has_monsters: bool) -> Kind:
	if is_open(kind, has_monsters):
		return kind
	return Kind.FIGHT


## 칠 뜻이 있는 태세인가. **도주 판정이 이것 하나만 본다** —
## 쫓는 자가 하나도 없으면 도주는 무조건 성공한다 (§35.2.2).
static func means_harm(kind: Kind) -> bool:
	return kind == Kind.FIGHT or kind == Kind.COOPERATE


## 그 태세로 싸움에 끌려 들어갔을 때의 힘 계수(백분율).
##
## `NEGOTIATE` 와 `FLEE` 는 **성립·성공한 경우 이 값을 쓰지 않는다** —
## 성립한 협상과 성공한 도주는 애초에 싸움에 끼지 않는다.
## 여기 있는 값은 결렬과 실패의 값이다.
static func weight_of(kind: Kind) -> int:
	match kind:
		Kind.FIGHT, Kind.COOPERATE:
			return WEIGHT_FULL
		Kind.STAND:
			return WEIGHT_STANDING
		_:
			return WEIGHT_EXPOSED
