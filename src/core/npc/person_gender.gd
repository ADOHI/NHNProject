class_name PersonGender
extends RefCounted
## 인물의 성별. **레코드가 정한다 — 초상 생성 모델이 정하게 두지 않는다.**
##
## docs/design/24-npc-relations.md §24.23.
##
## ## 왜 넣는가
##
## 초상 레인이 프롬프트에 성별을 안 썼는데 **계열마다 쏠렸다** —
## 전투 7장 전부 남자, 감식 3장 전부 여자. **모델이 마음대로 정하고 있었다.**
## 레코드에 성별이 없으면 초상 레인이 따로 뽑게 되고,
## 그러면 **상세 화면과 초상이 어긋난다.**
##
## ## 왜 둘인가
##
## 성이 부계로 이어지고(§24.22.7) 형제·자매가 성별로 갈린다.
## **가족 구조가 이진을 요구한다.** 나중에 혼인이 붙으면 더 걸린다.

enum Kind {
	MALE,
	FEMALE,
}

const _LABELS := ["남", "여"]


static func count() -> int:
	return _LABELS.size()


static func label(kind: Kind) -> String:
	return _LABELS[clampi(int(kind), 0, _LABELS.size() - 1)]


## 초상 프롬프트에 그대로 들어갈 말. 화면 표시와 갈라 두는 이유는
## 화면은 한 글자면 되고 프롬프트는 문장이어야 하기 때문이다.
static func portrait_word(kind: Kind) -> String:
	return "남성" if kind == Kind.MALE else "여성"
