class_name SheetTab
extends RefCounted
## 인물 상세의 탭 셋. **나누는 축은 「언제 필요한가」다.**
##
## docs/design/20-ui-kit.md §20.25.4.
##
## ## 왜 분류로 안 나눴나
##
## 「이 사람 자체 / 남과의 관계」로 나누면 **조우 중에 두 탭을 오가게 된다.**
## 그러면 탭이 없느니만 못하다. 그래서 나누는 축을 §20.25.1 의 **물음 순서**와
## 같은 축으로 잡았다 — 지금 정할 것 · 나중에 알 것 · 판정할 것.
##
## ## 셋째 탭이 가림의 단위다
##
## §24.17.2 가 *"개발용을 게임에 그대로 붙이면 게임의 축이 무너진다"* 고 했다.
## 가림이 **필드마다** 걸리면 게임 내 화면은 **구멍 뚫린 개발 화면**이 된다.
## `NUMBERS` 하나를 통째로 잠그면 게임 내 화면은 **탭 둘짜리 화면**이 된다 —
## 구멍이 아니라 없는 것이다. 그리고 **잊을 실수가 하나로 줄어든다.**

enum Kind {
	ENCOUNTER,  ## 조우 — 지금 정해야 할 것
	HISTORY,  ## 내력 — 정하고 나서 더 알고 싶을 때
	NUMBERS,  ## 수치 — 판정할 때. **개발용이고 가림의 단위다**
}

const _LABELS := ["조우", "내력", "수치"]


static func count() -> int:
	return _LABELS.size()


static func label(kind: Kind) -> String:
	return _LABELS[int(kind)]


## 게임 내 화면에서 잠기는 탭인가. 지금은 「수치」 하나다.
static func is_dev_only(kind: Kind) -> bool:
	return kind == Kind.NUMBERS
