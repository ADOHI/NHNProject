class_name SquadStats
extends RefCounted
## 대원들의 능력치를 스쿼드 하나의 값으로 합치는 규칙.
##
## 스쿼드는 판 위에서 말 하나로 움직이므로(docs/design/14-squad.md §14.2),
## 대원 여러 명의 수치를 하나로 접어야 한다. **그 접는 방식이 곧 편성의 재미다.**
##
## 편성 시스템은 구현 5단계에 붙지만, 규칙은 여기서 먼저 못 박는다.
## 전투력과 민첩의 집계 방식이 다르다는 것이 이 게임 편성의 핵심이라
## 나중에 정하면 그때 가서 흔들린다.


## 전투력은 **합**이다. 인원을 늘리면 무조건 강해진다.
##
## 그리고 이 값이 그대로 판 위 위험도 기여가 된다 —
## 강해지는 것과 눈에 띄는 것이 분리되지 않는다 (§14.3).
static func threat_of(member_threats: Array[int]) -> int:
	var total := 0
	for value in member_threats:
		total += maxi(0, value)
	return total


## 민첩은 **평균**(내림)이다.
##
## 최솟값(가장 느린 대원이 병목)이 현실적이지만, 그러면 민첩 특화 대원을 넣어도
## 이득이 0 이라 그 직업 계열이 존재할 이유가 사라진다 (§14.3.1).
##
## 평균이면 양방향으로 작동한다 —
## 날랜 대원을 넣으면 도달 범위가 늘고, 무거운 대원을 넣으면 줄어든다.
##
## **잠정 규칙이다.** 인원 수에 둔감해서 1인 스쿼드가 가장 유연해지는 문제가 있다.
static func agility_of(member_agilities: Array[int]) -> int:
	if member_agilities.is_empty():
		return 0
	var total := 0
	for value in member_agilities:
		total += maxi(0, value)
	return total / member_agilities.size()
