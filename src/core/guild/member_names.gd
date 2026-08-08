class_name MemberNames
extends RefCounted
## 대원 · 영입 후보 · 세계의 인물 이름을 뽑는다.
##
## 이름을 따로 떼어 둔 이유는 **이름이 이 게임에서 기능이기 때문이다.**
## docs/design/08-ui-ux.md §8.3.2 — NPC 가 이름으로 불리고 행적이 서술되어야
## 화면에 안 나와도 살아 있는 경쟁자가 된다. 영입의 감흥도 거기서 나온다
## (docs/design/14-squad.md §14.5).
##
## ## 왜 이름 두 글자를 음절로 쪼갰는가 (docs/design/24-npc-relations.md §24.16.4)
##
## 원래는 성 12 × 이름 12 = 144개였다. 대원 몇 명에는 충분하지만
## 세계 인구는 1000~3000명이다(§24.8). 144개 풀에서 3000명을 뽑으면
## 이름이 스무 번씩 겹치고, **겹치는 순간 렉카 기사가 누구 얘기인지 말할 수 없다.**
##
## 그래서 이름 두 글자를 **음절 풀 둘의 조합**으로 바꿨다. 용량이 2만을 넘어
## 3000명이 13% 미만이 되고, 거절 표집이 시도를 다 태우는 일이 없어진다.
##
## **원래 144개는 새 풀의 부분집합이다** — 그때 나오던 이름은 지금도 나온다.

## 성. 원래 열둘을 포함한다.
const _SURNAMES := [
	"김",
	"이",
	"박",
	"최",
	"정",
	"강",
	"조",
	"윤",
	"장",
	"임",
	"오",
	"한",
	"신",
	"서",
	"권",
	"황",
	"안",
	"송",
	"전",
	"홍",
	"유",
	"고",
	"문",
	"양",
	"손",
	"배",
	"백",
	"허",
	"남",
	"심",
	"노",
	"하",
	"곽",
	"성",
	"차",
	"주",
	"우",
	"구",
	"라",
	"민",
	"표",
]

## 이름 앞 음절.
const _GIVEN_FIRST := [
	"지",
	"민",
	"서",
	"현",
	"예",
	"하",
	"유",
	"도",
	"시",
	"준",
	"은",
	"태",
	"소",
	"재",
	"승",
	"세",
	"강",
	"나",
	"다",
	"라",
	"미",
	"보",
	"수",
	"영",
	"건",
	"규",
	"동",
	"명",
	"상",
	"연",
	"우",
	"진",
]

## 이름 뒤 음절.
const _GIVEN_SECOND := [
	"호",
	"우",
	"연",
	"아",
	"준",
	"원",
	"진",
	"서",
	"현",
	"빈",
	"영",
	"하",
	"리",
	"민",
	"재",
	"경",
	"성",
	"규",
	"찬",
	"한",
	"결",
	"람",
	"온",
	"일",
	"래",
	"산",
	"겸",
	"담",
	"록",
	"별",
	"솔",
	"훈",
	"희",
	"윤",
]

## 성 분포의 지프 지수. **균등하게 뿌리면 어색하다** — 한국은 몇 개 성이 압도적이다.
##
## 0.9 면 가장 흔한 성이 인구의 18% 안팎이 된다(3000명 중 약 540명).
## **흔한 성이 있어야 "같은 성인데 가족이 아닌 사람" 이 많아진다** —
## 성만 보고 가족을 짐작할 수 없는 것이 현실이고 정보 게임과도 맞는다
## (docs/design/05-rules.md §5.7). 성이 3000개면 성이 같은 순간 가족이 확정되어
## 정보가 공짜가 된다.
##
## _SURNAMES 의 앞쪽이 흔한 성이므로 **배열 순서가 곧 빈도 순위다.**
const SURNAME_ZIPF := 0.9

## 한 이름을 뽑을 때 최대 몇 번 다시 굴리나.
##
## 용량의 절반 아래로만 쓰면 이 횟수를 태울 확률이 사실상 0 이다.
## 인구가 용량에 가까워지면 그때는 시도를 늘리는 게 아니라 **풀을 늘려야** 한다.
const _ATTEMPTS := 48


## 아직 쓰지 않은 이름을 하나 뽑는다. 성도 같이 고른다.
##
## used 는 호출자가 들고 있는 이름 집합이다. 중복된 이름이 두 명 있으면
## 기사에서 누구 얘기인지 알 수 없게 되고, 그 순간 이름이 기능을 잃는다.
static func pick(rng: RandomNumberGenerator, used: Dictionary) -> String:
	return pick_with_surname(rng, used, pick_surname(rng))


## 성을 정해 놓고 이름만 뽑는다. **가족이 성을 나눠 갖는 통로다.**
##
## docs/design/24-npc-relations.md §24.22.7 — 성을 먼저 정하고 가족을 그 안에서 맺는다.
## 가족을 먼저 짜고 성을 물려주려면 이미 뽑아 둔 이름을 갈아야 하는데,
## 그러면 이름 장부가 흔들리고 조각 생성(§24.16.2)도 깨진다.
static func pick_with_surname(
	rng: RandomNumberGenerator, used: Dictionary, surname: String
) -> String:
	for _attempt in _ATTEMPTS:
		var given := _compose_given(rng)
		if given.is_empty():
			continue
		var name := "%s%s" % [surname, given]
		if used.has(name):
			continue
		used[name] = true
		return name
	var fallback := "무명 %d" % (used.size() + 1)
	used[fallback] = true
	return fallback


## 빈도에 따라 성을 하나. 앞쪽 성이 흔하다.
static func pick_surname(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for slot in _SURNAMES.size():
		total += 1.0 / pow(float(slot + 1), SURNAME_ZIPF)
	var roll := rng.randf() * total
	var running := 0.0
	for slot in _SURNAMES.size():
		running += 1.0 / pow(float(slot + 1), SURNAME_ZIPF)
		if roll < running:
			return _SURNAMES[slot]
	return _SURNAMES[_SURNAMES.size() - 1]


## 이름에서 성을 읽는다. **성을 따로 저장하지 않는다** —
## 열을 두면 이름과 성이 어긋날 수 있는 두 진실이 생긴다 (§24.22.7).
static func surname_of(name: String) -> String:
	return name.left(1)


## 성의 개수. 성이 얼마나 흔한지를 도구가 셀 때 분모로 쓴다.
static func surname_count() -> int:
	return _SURNAMES.size()


## 겹치지 않게 낼 수 있는 이름의 총수.
##
## 상수를 베껴 적지 않고 세어서 돌려준다. 풀을 늘렸을 때 도구와 테스트가
## 옛 수치로 조용히 거짓말하는 것을 막는다.
static func capacity() -> int:
	var pairs := 0
	for first in _GIVEN_FIRST:
		for second in _GIVEN_SECOND:
			if first != second:
				pairs += 1
	return _SURNAMES.size() * pairs


## 성 하나가 쓸 수 있는 이름의 수. **흔한 성이 이 수를 다 쓰면 중복이 난다.**
static func given_capacity() -> int:
	var pairs := 0
	for first in _GIVEN_FIRST:
		for second in _GIVEN_SECOND:
			if first != second:
				pairs += 1
	return pairs


## 이름 두 글자를 조합한다. 같은 음절이 겹치면(예: "민민") 버린다 — 사람 이름으로 읽히지 않는다.
static func _compose_given(rng: RandomNumberGenerator) -> String:
	var first: String = _GIVEN_FIRST[rng.randi() % _GIVEN_FIRST.size()]
	var second: String = _GIVEN_SECOND[rng.randi() % _GIVEN_SECOND.size()]
	if first == second:
		return ""
	return "%s%s" % [first, second]
