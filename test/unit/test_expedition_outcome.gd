extends GutTest
## 판이 스스로 끝났을 때 **어떤 끝인가**를 가르는 자리.
##
## docs/design/35-encounter.md §35.2.3 · docs/design/36-settlement.md.
##
## ## 왜 이것만 따로 시험하나
##
## **끝나는 길이 둘인데 둘 다 `DungeonRun.finished` 를 세운다.**
## 탈출해서 나가거나, 조우에서 제압당하거나. 안 가르면
## **털리고 나온 판이 탈출 성공으로 정산되고, 빈손이어야 할 판이 전리품을 준다.**
##
## 이 자리는 실제로 한 번 비어 있었다 — 정산 레인이 전투 판정을 기다리며
## 비워 뒀고, 조우 레인이 채웠다. **그 사이에는 아무 시험도 이 갈림을 안 봤다.**
## 화면 안에 두면 `Router.go_to()` 가 씬을 갈아 끼워 헤드리스로 못 덮으므로
## 판단만 코어로 내렸다.

const ReportScript := preload("res://src/core/guild/expedition_report.gd")


func test_defeat_is_not_an_escape() -> void:
	# 이 한 줄이 이 파일의 이유다.
	assert_eq(
		ReportScript.outcome_for(true),
		ReportScript.Outcome.DOWNED,
		"제압당한 판이 탈출 성공으로 정산되면 빈손이어야 할 판이 전리품을 준다"
	)


func test_surviving_is_an_escape() -> void:
	assert_eq(ReportScript.outcome_for(false), ReportScript.Outcome.ESCAPED)


func test_recall_never_comes_from_here() -> void:
	# 중도 회수는 판이 끝난 것이 아니라 사람이 그만둔 것이다.
	# 이 함수가 그것을 내면 「그만뒀는데 탈출로 적히는」 길이 생긴다.
	for defeated in [true, false]:
		assert_ne(ReportScript.outcome_for(defeated), ReportScript.Outcome.RECALLED)
