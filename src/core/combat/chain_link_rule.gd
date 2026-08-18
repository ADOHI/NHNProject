class_name ChainLinkRule
extends RefCounted
## 「이 아이템에서 저 아이템으로 이어져도 되는가」를 판정한다.
##
## **지금은 항상 참이다. 그것이 이 클래스의 요점이다.**
##
## `docs/design/28-combat.md` §28.2.2 가 연결 조건을 **미정**으로 남겼다. 사용자 발언:
##
## > *"모두 연결시키도록 하고 상승/하강 시너지를 줄지, 깐깐하게 이런 조건에서만
## > 연결되게 할지는 잘 모르겠어서 이건 후순위로 정해도 될 것 같아."*
##
## 그래서 지금 규칙은 「방향이 맞으면 연결된다」 하나뿐이고, 방향은 격자가 이미
## 판정했다. 여기는 **나중에 깐깐한 조건이 들어올 자리**로만 존재한다.
##
## ## 갈아 끼우는 법
##
## 이 클래스를 상속해 `can_link` 만 덮어쓰고 `ChainResolver` 에 넘긴다.
## **해석기는 안 고친다.** 해석기는 조건을 모르고 물어보기만 한다.
##
## [codeblock]
## class HeavyAfterLight extends ChainLinkRule:
##     func can_link(from: BackpackPlacement, to: BackpackPlacement) -> bool:
##         return ...
## [/codeblock]
##
## > **정하지 마라.** 지금 여기에 시너지 수치나 태그 조합을 넣는 것은 §28.2.2 위반이다.


## 이어져도 되는가. 기본 구현은 **항상 참**이다.
##
## `from` 의 출력 방향이 `to` 를 실제로 가리킨다는 것은 호출 전에 이미 확인됐다.
## 그래서 여기서 위치를 다시 볼 필요는 없다 — 볼 것은 「무엇과 무엇인가」다.
func can_link(_from: BackpackPlacement, _to: BackpackPlacement) -> bool:
	return true
