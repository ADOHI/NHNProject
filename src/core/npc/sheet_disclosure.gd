class_name SheetDisclosure
extends RefCounted
## 상세 화면을 **얼마나 보여줄지.** 문맥 하나가 이것 하나다.
##
## docs/design/24-npc-relations.md §24.17.2.
##
## ## 왜 화면 둘을 짜지 않고 층으로 두나
##
## 개발용은 전부 보이고 게임 내는 단서만 보인다 — §5.4 의
## *"단서는 보이지만 확신은 못 한다"*. 화면 둘을 따로 짜면 둘이 갈라져서
## 한쪽에 칸을 더할 때 다른 쪽을 잊는다.
##
## **같은 자료에 가림을 얹는다.** 그래서 문맥마다 얼마나 가릴지만 바꾸면 된다 —
## 영입 후보 · 길드 대원 · 던전 조우 · 렉카 기사가 §24.17.1 의 네 문맥이다.
##
## ## 가림은 내리는 것만 한다
##
## `FILLED` 을 `HIDDEN` 으로 내릴 수만 있고 **`MISSING` 은 못 건드린다.**
## 없는 자료를 가리는 것은 뜻이 없고, 뭉개면 화면이
## *"아직 안 만들었다"* 와 *"당신이 모른다"* 를 같은 말로 하게 된다 (SheetField).

enum Level {
	DEV,  ## 전부 보인다. **개발용.** 생성 판정이 목적이다
	CLUE,  ## 단서만. 게임 내 화면이 쓸 자리 — 아직 아무도 쓰지 않는다
}

## `CLUE` 에서 가려지는 칸의 제목들.
##
## **성향은 게임 내에 그대로 나가면 완전 공개다** (§24.17.2).
## 단서는 성향 수치가 아니라 행동 이력 · 렉카 기사 · 관계 유형이어야 한다.
const CLUE_HIDDEN_TITLES := ["성향"]


## 이 층에서 이 칸의 필드들을 가린 사본을 돌려준다. 원본은 건드리지 않는다.
##
## 사본을 주는 이유는 같은 레코드를 여러 문맥이 동시에 볼 수 있어서다 —
## 개발 화면과 게임 화면이 한 판에 같이 떠 있을 수 있다.
static func apply(section: SheetSection, level: Level) -> SheetSection:
	if not hides(section.title, level):
		return section

	var veiled := SheetSection.new(section.title, section.shape, section.expected_lines)
	for field in section.fields:
		veiled.add(SheetField.hidden(field.label) if field.is_filled() else field)
	return veiled


## 이 층이 이 제목의 칸을 가리는가.
static func hides(title: String, level: Level) -> bool:
	return level == Level.CLUE and CLUE_HIDDEN_TITLES.has(title)


static func label(level: Level) -> String:
	return "개발용 (전부 보임)" if level == Level.DEV else "게임 내 (단서만)"
