class_name RelationKind
extends RefCounted
## 관계의 유형. **딱지다** — 수치만 있으면 렉카가 「사이 나쁨」밖에 못 쓴다 (설계 24.2).
##
## ## 두 갈래로 나뉜다 (설계 24.18)
##
## **가족은 사건에서 나오지 않는다.** 아무 일도 없이 처음부터 있다.
## 설계 24.2 의 유형 목록에 혈연과 사제가 있는데 **어디서 생기는지가 적혀 있지 않았다.**
##
## | 갈래 | 언제 | 유대 |
## | --- | --- | --- |
## | **태생** (혈연 · 사제) | 인구 생성 시점 | **사건이 못 깎는다** |
## | **얻은 것** (생사고락 · 배신당함 …) | 사건에서 | 사건이 올리고 내린다 |
##
## **배신해도 혈연은 혈연이다.** 그래서 태생 관계는 유형도 안 바뀐다 —
## 유형이 갈리면 "원수가 된 가족" 이 "남이 된 가족" 으로 납작해진다.

## 유형은 **보는 사람 기준**이다. `A→B` 가 PARENT 면 **B 가 A 의 부모**다.
## 관계가 비대칭이므로(설계 24.21.2) 반대 슬롯은 CHILD 가 된다.
enum Kind {
	NONE,  ## 관계 없음
	PARENT,  ## 상대가 내 부모 — 태생
	CHILD,  ## 상대가 내 자식 — 태생
	SIBLING,  ## 형제 — 태생. 양쪽이 같은 유형이다
	MASTER,  ## 상대가 내 스승 — 태생
	STUDENT,  ## 상대가 내 제자 — 태생
	COMRADESHIP,  ## 생사고락 — 협력과 전멸이 남긴다
	BETRAYED,  ## 배신당함 — 배신의 대상 쪽
	BETRAYER,  ## 배신함 — 배신의 행위자 쪽
	TRUST,  ## 신뢰 — 사건을 보고 편이 된 목격자
	GRUDGE,  ## 원한 — 사건을 보고 등을 돌린 목격자
	GRATITUDE,  ## 은혜 — 구조가 남긴다
	DEAL,  ## 거래 — 협상 성립이 남긴다
	ABANDONED,  ## 유기당함 — 두고 간 쪽에서 본 것
	ABANDONER,  ## 유기함 — 두고 온 쪽
}

const _LABELS := [
	"없음",
	"부모",
	"자식",
	"형제",
	"스승",
	"제자",
	"생사고락",
	"배신당함",
	"배신함",
	"신뢰",
	"원한",
	"은혜",
	"거래",
	"유기당함",
	"유기함",
]

## 태생 유형. 사건이 이것들의 유대와 유형을 못 건드린다 (설계 24.18).
const _INBORN := [Kind.PARENT, Kind.CHILD, Kind.SIBLING, Kind.MASTER, Kind.STUDENT]

## 성을 나눠 갖는 유형. **부계로만 물려준다** —
## 어머니와 혼인 관계는 아직 없다 (설계 24.22.7).
const _SHARES_SURNAME := [Kind.PARENT, Kind.CHILD, Kind.SIBLING]


static func label(kind: Kind) -> String:
	return _LABELS[clampi(int(kind), 0, _LABELS.size() - 1)]


## 태어난 것인가. **사건이 유대를 못 깎는 유일한 조건이다.**
static func is_inborn(kind: Kind) -> bool:
	return _INBORN.has(kind)


## 이 유형이 성을 나눠 갖는가. 가족 생성이 후보를 성으로 거르는 근거다.
static func shares_surname(kind: Kind) -> bool:
	return _SHARES_SURNAME.has(kind)


## 반대편 슬롯이 가질 유형. 형제 · 생사고락은 자기 자신이다.
##
## **배신에도 짝이 있다.** 당한 쪽 화면에는 「배신당함」, 한 쪽 화면에는 「배신함」이 뜬다 —
## 유형을 한쪽에만 두면 **같은 사건이 가해자의 화면에서 사라진다.**
static func opposite(kind: Kind) -> Kind:
	match kind:
		Kind.PARENT:
			return Kind.CHILD
		Kind.CHILD:
			return Kind.PARENT
		Kind.MASTER:
			return Kind.STUDENT
		Kind.STUDENT:
			return Kind.MASTER
		Kind.BETRAYED:
			return Kind.BETRAYER
		Kind.BETRAYER:
			return Kind.BETRAYED
		Kind.ABANDONED:
			return Kind.ABANDONER
		Kind.ABANDONER:
			return Kind.ABANDONED
		_:
			return kind


## 성별을 아는 라벨. `부모` 가 아니라 `아버지`, `형제` 가 아니라 `남매` 가 된다.
##
## **유형을 늘리지 않고 라벨만 갈라 낸다.** 아버지/어머니를 enum 으로 나누면
## 태생 유형이 배로 늘고 is_inborn · opposite 가 전부 길어진다 —
## 성별은 이미 레코드에 있으므로 **읽을 때 합치는 것이 맞다** (설계 24.23).
static func label_for(
	kind: Kind, self_gender: PersonGender.Kind, other_gender: PersonGender.Kind
) -> String:
	match kind:
		Kind.PARENT:
			return "아버지" if other_gender == PersonGender.Kind.MALE else "어머니"
		Kind.CHILD:
			return "아들" if other_gender == PersonGender.Kind.MALE else "딸"
		Kind.SIBLING:
			if self_gender != other_gender:
				return "남매"
			return "형제" if other_gender == PersonGender.Kind.MALE else "자매"
		_:
			return label(kind)


static func count() -> int:
	return _LABELS.size()
