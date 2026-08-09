class_name NpcAxis
extends RefCounted
## 성향 6축의 정의. **축의 이름과 범위가 여기 한 곳에만 있다.**
##
## docs/design/24-npc-relations.md §24.3 이 축 여섯을 확정했다.
## docs/design/05-rules.md §5.4 가 "축의 개수 · 이름 미정" 으로 비워 둔 자리다.
##
## ## 왜 따로 뗐는가
##
## 사건 벡터(§24.5)와 인물의 성향(§24.16)이 **같은 축 위에 있어야** §24.4 의
## 내적 하나로 반응이 계산된다. 두 곳이 축 순서를 따로 정하면 내적이 조용히 틀리고,
## 틀린 것이 수치라서 화면에서 눈치챌 수 없다. **순서의 원본은 이 enum 하나다.**
##
## 값의 부호는 항상 **(+) 극 기준**이다 — RECKLESS 가 +100 이면 무모, -100 이면 신중.

enum Kind {
	RECKLESS,  ## 무모 ↔ 신중 — 던전 · 위험
	GOOD,  ## 선 ↔ 악 — 모르는 사람
	LOYAL,  ## 의리 ↔ 실리 — 내 사람
	HIERARCHY,  ## 위계 ↔ 자유 — 소속
	HONEST,  ## 정직 ↔ 기만 — 말 · 정보
	SHOWY,  ## 과시 ↔ 은둔 — 평판
}

## 축값의 하한 · 상한. 연속값이지만 정수로 들고 다닌다 (§24.3 "인물당 정수 여섯").
const MIN_VALUE := -100
const MAX_VALUE := 100

## (+) 극의 이름. 축을 부를 때 쓰는 짧은 이름이다.
const _POSITIVE := ["무모", "선", "의리", "위계", "정직", "과시"]

## (−) 극의 이름.
const _NEGATIVE := ["신중", "악", "실리", "자유", "기만", "은둔"]


## 축의 개수. 성향 배열의 stride 이기도 하다.
static func count() -> int:
	return _POSITIVE.size()


## "무모/신중" 형태의 축 이름.
##
## 화살표(↔)를 쓰지 않는다. 테마 폰트에 없는 글자는 웹 빌드에서 두부가 되고
## 데스크톱에서는 그것이 보이지 않는다 (docs/conventions.md §5.1).
static func label(kind: Kind) -> String:
	return "%s/%s" % [positive_label(kind), negative_label(kind)]


static func positive_label(kind: Kind) -> String:
	return _POSITIVE[_slot(kind)]


static func negative_label(kind: Kind) -> String:
	return _NEGATIVE[_slot(kind)]


## 값이 가리키는 쪽의 이름. 0 이면 (+) 쪽으로 읽는다 — 표시용이라 경계는 중요하지 않다.
static func pole_label(kind: Kind, value: int) -> String:
	return positive_label(kind) if value >= 0 else negative_label(kind)


## 축값을 허용 범위로 자른다. 사건이 값을 움직일 때 쓴다 (§24.4).
static func clamp_value(value: int) -> int:
	return clampi(value, MIN_VALUE, MAX_VALUE)


static func _slot(kind: Kind) -> int:
	return clampi(int(kind), 0, _POSITIVE.size() - 1)
