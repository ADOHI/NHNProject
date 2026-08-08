class_name KoreanParticle
extends RefCounted
## 이름 뒤에 붙는 조사를 받침으로 고른다.
##
## 렉카 프롬프트의 입력은 칸이 아니라 **문장**이다
## (docs/design/19-rekka-voice.md §19.A.5). 문장으로 넘기면 조사가 필요하고,
## 조사가 틀리면 모델이 이름을 이름으로 안 읽는다.
## `요한가 제압했다` 같은 줄을 주면 어디까지가 이름인지 모델이 다시 추측한다.
##
## 방 이름과 인물 이름은 생성기가 만들어 내므로 목록으로 못 박을 수 없다
## (`room_kind_planner.gd` 의 이름표는 후보일 뿐이고 스쿼드 이름은 플레이어가 정한다).
## 그래서 표를 두지 않고 **글자에서 계산한다.**

## 한글 음절 영역의 시작과 끝. 이 밖의 글자는 받침 판정을 할 수 없다.
const _SYLLABLE_FIRST := 0xAC00
const _SYLLABLE_LAST := 0xD7A3

## 한 초성 · 중성 조합당 종성 가짓수. 유니코드 한글 음절의 배열 규칙이다.
const _FINAL_COUNT := 28

## 종성 ㄹ 의 첨자. `으로` 와 `로` 를 가르는 유일한 예외다.
const _FINAL_RIEUL := 8

## 숫자로 끝나는 이름의 종성. 생성기가 같은 이름을 두 번 쓰면 번호를 붙인다
## (`room_kind_planner.gd` pick_name) — `중정 3` 은 "중정 삼" 으로 읽히므로 받침이 있다.
##
## 값은 그 자리의 한자음이 가진 종성 첨자다. ㄹ 로 끝나는 하나 · 일곱 · 여덟은
## `로` 를 받으므로 `_FINAL_RIEUL` 과 같은 값이어야 한다.
const _DIGIT_FINALS: Array[int] = [21, 8, 0, 16, 0, 0, 1, 8, 8, 0]


## 받침이 있는가. 숫자는 한자음으로 읽고, 그 밖의 비한글은 없는 것으로 본다.
##
## 라틴 문자로 끝나는 이름은 읽는 사람마다 조사가 갈리므로 어느 쪽을 골라도 틀린다.
## 받침 없는 쪽이 덜 어색해서 그쪽으로 고정한다.
static func has_final(word: String) -> bool:
	return _final_index(word) > 0


## 이/가.
static func subject(word: String) -> String:
	return "이" if has_final(word) else "가"


## 은/는.
static func topic(word: String) -> String:
	return "은" if has_final(word) else "는"


## 을/를.
static func object_of(word: String) -> String:
	return "을" if has_final(word) else "를"


## 과/와.
static func conjunction(word: String) -> String:
	return "과" if has_final(word) else "와"


## 으로/로. **ㄹ 받침은 받침이 없는 것처럼 붙는다.**
static func direction(word: String) -> String:
	var final_index := _final_index(word)
	if final_index == 0 or final_index == _FINAL_RIEUL:
		return "로"
	return "으로"


## 이다/다. `<이름>다` 처럼 서술어로 끝낼 때 쓴다.
static func copula(word: String) -> String:
	return "이다" if has_final(word) else "다"


## 마지막 글자의 종성 첨자. 한글이 아니거나 빈 문자열이면 0.
static func _final_index(word: String) -> int:
	if word.is_empty():
		return 0
	var code := word[word.length() - 1].unicode_at(0)
	if code >= 48 and code <= 57:
		return _DIGIT_FINALS[code - 48]
	if code < _SYLLABLE_FIRST or code > _SYLLABLE_LAST:
		return 0
	return (code - _SYLLABLE_FIRST) % _FINAL_COUNT
