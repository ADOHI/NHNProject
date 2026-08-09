class_name KoreanJosa
extends RefCounted
## 앞말의 받침에 따라 갈리는 조사를 골라 준다. `"%s 와 겹친다"` 같은 문장을 고치는 데 쓴다.
##
## ## 왜 이것이 필요한가
##
## 이 게임의 글자는 전부 한국어이고, **코어가 문장을 만든다**(conventions.md §3.1).
## 그런데 `"%s 와 겹친다"` 로 박아 두면 "공방 와 겹친다" 가 나온다 — 받침이 있으면 "과" 다.
## 실제로 아지트 화면에서 그렇게 떴고, 그것을 보고 만들었다.
##
## **틀린 조사는 기능이 아니라 완성도의 문제로 보이지만, 문장을 코어가 만드는 이상
## 이것도 코어의 몫이다.** 화면마다 고치면 화면마다 다르게 틀린다.
##
## ## 받침 판정
##
## 한글 음절은 유니코드에서 `가`(0xAC00) 부터 **초성 19 × 중성 21 × 종성 28** 로 규칙적으로
## 늘어선다. 그래서 `(코드 - 0xAC00) % 28` 이 0 이 아니면 받침이 있다. 표가 필요 없다.
##
## ## 한글이 아닌 말
##
## 숫자나 라틴 문자로 끝나면 **받침이 없는 것으로 본다.** 정확히 하려면 읽는 법을 알아야
## 하는데(1 은 "일" 이라 받침이 있고 2 는 "이" 라 없다), 지금 조사가 붙는 것은
## 시설 이름과 대원 이름뿐이라 그 표를 만들 이유가 없다. 필요해지면 여기만 고친다.

const _HANGUL_BASE := 0xAC00
const _HANGUL_LAST := 0xD7A3
const _FINAL_COUNT := 28

## 종성 표에서 ㄹ 의 자리. 받침이 ㄹ 이면 "으로" 가 아니라 "로" 다.
const _RIEUL_FINAL := 8


## 이 말이 받침으로 끝나는가.
static func has_final_consonant(word: String) -> bool:
	if word.is_empty():
		return false
	var code := word.unicode_at(word.length() - 1)
	if code < _HANGUL_BASE or code > _HANGUL_LAST:
		return false
	return (code - _HANGUL_BASE) % _FINAL_COUNT != 0


## 받침 유무로 둘 중 하나를 고른다. 조사만 돌려준다.
static func pick(word: String, after_vowel: String, after_consonant: String) -> String:
	return after_consonant if has_final_consonant(word) else after_vowel


## 앞말에 조사를 붙여서 돌려준다. `attach("공방", "와", "과")` -> `"공방과"`.
static func attach(word: String, after_vowel: String, after_consonant: String) -> String:
	return word + pick(word, after_vowel, after_consonant)


## "공방과" · "접선처와"
static func wa(word: String) -> String:
	return attach(word, "와", "과")


## "공방을" · "접선처를"
static func eul(word: String) -> String:
	return attach(word, "를", "을")


## "공방이" · "접선처가"
static func i(word: String) -> String:
	return attach(word, "가", "이")


## "공방은" · "접선처는"
static func eun(word: String) -> String:
	return attach(word, "는", "은")


## "공방으로" · "접선처로" · "정보실로"
##
## **ㄹ 받침만 다르다.** 받침이 있어도 그것이 ㄹ 이면 "으로" 가 아니라 "로" 다.
## 이 한 줄 때문에 pick 을 그대로 못 쓴다.
static func ro(word: String) -> String:
	if not has_final_consonant(word):
		return word + "로"
	var final_index := (word.unicode_at(word.length() - 1) - _HANGUL_BASE) % _FINAL_COUNT
	return word + ("로" if final_index == _RIEUL_FINAL else "으로")
