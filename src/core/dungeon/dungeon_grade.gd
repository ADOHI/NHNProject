class_name DungeonGrade
extends RefCounted
## 던전을 골라 들어가기 전에 보는 **수치 셋** — 규모 · 복잡 · 험난.
##
## 사용자 요구: "얼마나 큰지, 얼마나 복잡한지, 얼마나 고도차가 심한지" 를 보고 고른다.
## 셋 다 **구조**의 성질이다. 귀중품·위험방 같은 내용물은 여기 들어가지 않는다.
##
## ## 표시는 입력이 아니라 결과다
##
## **생성기가 받은 값이 아니라 만들어진 판을 재서 낸다.** 입력이 5 인데 결과가 3 이면
## 화면이 거짓말한다. 그리고 둘이 크게 어긋나면 그 자체가 버그 신호가 된다.
##
## 그래서 이 클래스는 `DungeonBlueprint` 만 받는다 — 파라미터를 보지 않는다.
##
## ## 등급 수가 축마다 다르다
##
## | 축 | 등급 | 왜 |
## | --- | --- | --- |
## | 규모 | **5단계** | 방 개수는 시드에 거의 안 흔들린다 (다섯 단계 겹침 0/4) |
## | 복잡 | **3단계** | 다섯 단계로 내면 이웃이 겹친다 (2/4) |
## | 험난 | **3단계** | 같음 (3/4) |
##
## **다섯으로 통일하지 않는다.** 안 갈리는 등급을 다섯 개 내놓으면 화면이 거짓말한다
## (docs/design/17-dungeon-generation.md §17.20.4).
##
## ## 읽히는 말과 재는 값이 다르다
##
## 복잡 등급은 **평균 차수**로 매기고 화면에는 **「갈림길」**로 설명한다.
## 둘의 상관이 0.97 이라 같은 것을 말하는데, 갈림길 비율은 시드 편차가 6.59%p 나 되어
## 다섯 단계가 전부 겹친다. 평균 차수는 0.11 이다.
##
## ## 무엇을 축으로 쓰지 않았는가
##
## | 뺀 것 | 이유 (실측, §17.20.2) |
## | --- | --- |
## | 지름 | 규모에 3.94 로 반응한다 — **「판이 길다」는 규모가 말한다** |
## | 막다른 방 비율 | 어느 입력에도 반응하지 않는다. V5 가 14~30% 로 묶어 둔다 |
## | 최고 고도 | 단차(2.25)만큼 **규모(2.41)에도 반응한다.** 높은 것과 험한 것은 다르다 |

## 등급의 최댓값. 축마다 다르다.
const SCALE_MAX := 5
const COMPLEXITY_MAX := 3
const HARDSHIP_MAX := 3

## 규모 경계 — 방 개수. 게이트 등급 다섯이 내는 방 개수(12/17/22/27/32)의 사이를 자른다.
const _SCALE_STEPS := [15, 20, 25, 30]

## 복잡 경계 — 평균 차수. 실측 분포에서 **가운데 등급이 가장 흔하도록** 잡았다
## (25 백분위 2.55, 75 백분위 2.85).
const _COMPLEXITY_STEPS := [2.55, 2.90]

## 험난 경계 — 간선당 평균 상승폭. 같은 방식이다 (25 백분위 0.74, 75 백분위 1.32).
const _HARDSHIP_STEPS := [0.75, 1.40]


## 설계도를 재서 등급과 근거 수치를 함께 돌려준다.
##
## 근거를 같이 내는 이유는 **화면이 「복잡 3」만 보여 주면 왜 3 인지 알 수 없기** 때문이다.
## 정보실 수준이 높을수록 근거까지 보여 줄 수 있다.
static func of(blueprint: DungeonBlueprint) -> Dictionary:
	var rooms := blueprint.room_ids().size()
	var edges := blueprint.connections()
	var degree := 0.0 if rooms == 0 else 2.0 * float(edges.size()) / float(rooms)

	var climb := 0.0
	var junctions := 0.0
	if not edges.is_empty():
		var total := 0.0
		for pair in edges:
			total += float(absi(blueprint.elevation_of(pair[0]) - blueprint.elevation_of(pair[1])))
		climb = total / float(edges.size())
		junctions = _junction_percent(blueprint)

	return {
		"scale": scale_of(rooms),
		"complexity": complexity_of(degree),
		"hardship": hardship_of(climb),
		"rooms": rooms,
		"junction_pct": junctions,
		"average_degree": degree,
		"average_climb": climb,
	}


## 규모 1~5. 방 개수로 매긴다.
static func scale_of(rooms: int) -> int:
	return _step(float(rooms), _SCALE_STEPS)


## 복잡 1~3. **평균 차수**로 매기고 화면에는 「갈림길」로 설명한다 (위 주석 참고).
static func complexity_of(average_degree: float) -> int:
	return _step(average_degree, _COMPLEXITY_STEPS)


## 험난 1~3. 간선 하나당 평균 상승폭이다 — **한 걸음에 얼마나 오르느냐.**
static func hardship_of(average_climb: float) -> int:
	return _step(average_climb, _HARDSHIP_STEPS)


## 갈림길(차수 3 이상) 비율. 복잡 등급이 **뜻하는** 것이라 화면 설명에 쓴다.
static func _junction_percent(blueprint: DungeonBlueprint) -> float:
	var degrees := {}
	for pair in blueprint.connections():
		degrees[pair[0]] = int(degrees.get(pair[0], 0)) + 1
		degrees[pair[1]] = int(degrees.get(pair[1], 0)) + 1

	var ids := blueprint.room_ids()
	var junctions := 0.0
	for id in ids:
		if int(degrees.get(id, 0)) >= 3:
			junctions += 1.0
	return 100.0 * junctions / maxf(float(ids.size()), 1.0)


## 경계 목록에서 몇 번째 칸인가. 1 부터 센다.
static func _step(value: float, steps: Array) -> int:
	var grade := 1
	for edge in steps:
		if value >= float(edge):
			grade += 1
	return grade
