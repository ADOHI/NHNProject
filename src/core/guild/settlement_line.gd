class_name SettlementLine
extends RefCounted
## 정산 화면에 나가는 **한 줄**과 그 줄의 성격.
##
## 색을 여기서 정하지 않는 이유가 있다. 화면이 둘 이상이고
## (`SettlementResult.lines()` 주석과 같은 사정), 색은 `UiTokens` 가 한 곳에서 정한다
## (docs/design/20-ui-kit.md §20.32.4 — *"글자색을 화면이 눈으로 고르면 안 된다"*).
##
## 그래서 코어는 **무슨 성격의 줄인가**까지만 말하고, 그 성격을 색으로 옮기는 것은
## 화면의 일이다. 색을 코어가 들면 `Color` 를 위해 순수 클래스가 화면 쪽을 알게 된다.
##
## docs/design/36-settlement.md §36.3.1.

## 줄의 성격. **네 가지뿐이다** — 늘리기 전에 이 넷으로 안 되는지 먼저 본다.
enum Tone {
	PLAIN,  ## 그냥 사실. 이번 판이 어땠는지
	GAIN,  ## 들어온 것. 자금 · 진척 · 후보
	LOSS,  ## 나간 것. 전리품 · 장비 · 후유증
	DIM,  ## 곁들이는 말. 없어도 판단이 서는 것
}

var text: String
var tone: Tone


func _init(line_text: String = "", line_tone: Tone = Tone.PLAIN) -> void:
	text = line_text
	tone = line_tone


## 이 줄이 손실을 말하는가. 화면이 강조를 걸 때 쓴다.
func is_loss() -> bool:
	return tone == Tone.LOSS
