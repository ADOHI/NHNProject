class_name SheetSection
extends RefCounted
## 상세 화면의 한 칸. 제목과 필드들, 그리고 **어떤 모양으로 자라는가.**
##
## docs/design/24-npc-relations.md §24.17.3.
##
## ## 왜 「모양」을 자료가 들고 있나
##
## 픽셀은 뷰의 일이지만 **무엇이 들어올 것인지는 자료의 일이다.**
## 열전은 문장 여러 줄이 들어올 자리고(§24.19 · §24.20.2) 소속은 한 줄이다.
## 뷰가 그것을 짐작하면 **비어 있을 때 예뻐 보이는 배치**가 되고, 채워지면 터진다.
##
## 그래서 칸이 `Shape` 하나를 들고 있다. 픽셀은 아니고 **자라는 방향과 예상 분량**이다.

enum Shape {
	LINES,  ## 이름-값 줄이 몇 개. 소속 · 머리
	GAUGES,  ## 이름-값-막대 줄이 몇 개. 성향 6축
	FRAME,  ## 규격 정사각 액자. 초상 (§24.20.5)
	PARAGRAPHS,  ## 문장 여러 줄이 세로로 자란다. 열전 (§24.19)
	ENTRIES,  ## 항목 목록이 세로로 자란다. 관계 (§24.2 인물당 2~4개)
}

## 칸 제목. 화면에 그대로 나간다.
var title: String

var shape: Shape

var fields: Array[SheetField] = []

## 이 칸이 나중에 얼마나 자랄 것인가. **비어 있을 때 자리를 잡는 근거다.**
##
## 채워졌을 때의 예상 줄 수다. 열전은 문장 여러 줄, 관계는 §24.2 가 못 박은 2~4개.
## 뷰가 이 값으로 빈칸의 높이를 잡으므로 **자료가 들어와도 배치가 안 밀린다.**
var expected_lines: int


func _init(section_title: String, section_shape: Shape, lines: int = 1) -> void:
	title = section_title
	shape = section_shape
	expected_lines = maxi(lines, 1)


func add(field: SheetField) -> SheetSection:
	fields.append(field)
	return self


## 이 칸에 보여줄 값이 하나라도 있는가. 없으면 뷰가 「아직 없다」 쪽으로 그린다.
func has_content() -> bool:
	for field in fields:
		if field.is_filled():
			return true
	return false
