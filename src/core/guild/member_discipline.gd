class_name MemberDiscipline
extends RefCounted
## 대원의 직업 계열. **잠정 5계열이다.**
##
## docs/design/14-squad.md §14.4.1 은 "최소 5계열" 만 확정하고 이름을 미정으로 두었다.
## 그런데 §14.4.3 의 **"스쿼드 정원 < 계열 수"** 를 코드로 옮기려면
## 계열이 실체를 가져야 한다. 그래서 다섯을 잠정으로 잡았다 —
## 이름도 성향도 언제든 갈린다 (docs/design/22-guild-base.md §22.3).
##
## ## "눈" 은 문구뿐이고 효과가 없다
##
## §14.4.2 는 계열마다 **다른 각도의 눈**을 하나씩 주라고 요구한다.
## 그러나 인게임 정보 시스템이 아직 스킬 형태가 아니다.
## 지금 효과를 지어내면 실제 시스템이 붙을 때 전부 버려지므로,
## **문구만 남기고 자리를 비워 둔다** (§22.7).

## ## 계열 이름이 다른 뜻으로 읽힌다 — LLM 에 그냥 넘기지 마라
##
## 초상 레인이 겪었다. **"기공" 두 글자가 氣功으로 읽혀 인물 서술이 통째로
## 기맥과 호흡 이야기가 됐다.** 여기서 기공은 機工(기계 · 공학) 쪽이다.
##
## "감식" 도 鑑識(감정)과 監視 사이에서 흔들리고 "교섭" 은 협상 담당이다.
##
## **이름만 넘기지 말고 무엇을 하는 계열인지 함께 넘겨라** — eye_note() 가 그 문구다.
enum Kind {
	COMBAT,  ## 전투계
	SCOUT,  ## 정찰계
	ENGINEER,  ## 기공계
	BROKER,  ## 교섭계
	APPRAISER,  ## 감식계
}

const _LABELS := ["전투", "정찰", "기공", "교섭", "감식"]

## 계열이 준다고 **예고된** 정보. 아직 아무 효과도 없다 (§22.7).
const _EYES := [
	"이길 수 있는 방인지 감이 온다",
	"인접 방의 개체 수가 보인다",
	"고도 차이와 통로 상태를 읽는다",
	"상대의 성향 단서를 얻는다",
	"고가치 방의 위치를 좁힌다",
]

## 계열별 기본 전투력. 합산되어 스쿼드 전투력이 된다 (SquadStats.threat_of).
const _THREATS := [4, 2, 3, 2, 3]

## 계열별 기본 민첩. 평균되어 스쿼드 민첩이 된다 (SquadStats.agility_of).
##
## 전투계가 가장 무겁고 정찰계가 가장 가볍다 —
## "털러 가려면 가볍게 가야 하는데, 가벼우면 못 싸운다" (§14.3.1) 를 만드는 배치다.
const _AGILITIES := [1, 4, 2, 2, 3]


static func count() -> int:
	return _LABELS.size()


static func label(kind: Kind) -> String:
	return _LABELS[clampi(int(kind), 0, _LABELS.size() - 1)]


## 이 계열이 준다고 예고된 정보. 표시용 문구다.
static func eye_note(kind: Kind) -> String:
	return _EYES[clampi(int(kind), 0, _EYES.size() - 1)]


static func base_threat(kind: Kind) -> int:
	return _THREATS[clampi(int(kind), 0, _THREATS.size() - 1)]


static func base_agility(kind: Kind) -> int:
	return _AGILITIES[clampi(int(kind), 0, _AGILITIES.size() - 1)]
