class_name SettlementResult
extends RefCounted
## 정산으로 아지트가 무엇이 얼마나 변했는가.
##
## 변화를 값으로 돌려주는 이유는 **"갔다 오니 아지트가 달라져 있다" 가
## 눈에 보여야 하기 때문이다.** 길드 상태를 조용히 바꾸고 끝내면
## 플레이어는 무엇이 달라졌는지 알 수 없고, 그러면 배치가 결정이었다는 사실도 전달되지 않는다.
##
## docs/design/22-guild-base.md §22.6.

var funds_gained: int = 0
var base_progress_gained: int = 0
var levels_gained: int = 0

## 이번에 접선처가 찾아낸 후보들.
var prospects_found: Array[RecruitProspect] = []

## 정산 시점의 공방 / 접선처 잔류 인원. 왜 이만큼 들어왔는지를 화면이 설명할 수 있게 한다.
var workshop_staff: int = 0
var contact_staff: int = 0


## 화면에 그대로 나가는 줄들.
##
## 문자열을 여기서 만드는 이유는 화면이 둘 이상이기 때문이다 —
## 임시 화면과 나중에 올 조형 화면이 같은 문장을 봐야 설명이 어긋나지 않는다.
func lines() -> Array[String]:
	var result: Array[String] = []
	result.append("전리품 %d" % funds_gained)
	result.append("아지트 진척 %d (공방 잔류 %d명)" % [base_progress_gained, workshop_staff])
	if levels_gained > 0:
		result.append("아지트 레벨 %d 상승" % levels_gained)
	if prospects_found.is_empty():
		result.append("영입 후보 없음 (접선처 잔류 %d명)" % contact_staff)
	else:
		for prospect in prospects_found:
			result.append("영입 후보 발견 - %s" % prospect.summary())
	return result
