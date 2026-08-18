class_name RekkaSlots
extends RefCounted
## 문안의 자리표시를 판의 이름으로 채운다.
##
## ## 왜 자리표시인가
##
## 문안은 미리 만들어 자산으로 싣는다 (docs/design/32-rekka-feed.md §32.3).
## 그런데 **방 이름과 인물 이름은 생성기가 만든다.** 자산에 `회랑` 을 박으면
## 그 방이 없는 판에서 기사가 거짓말이 된다 — 그리고 장소가 틀린 기사는
## 정보로서 무가치하다 (13-information-design.md §13.3.1).
##
## 그래서 자산은 자리만 비워 두고 판이 채운다.
##
##     {주체은} {방에서} 한 건 했다는데 {등급이} 실화냐 ㅋㅋ
##
## ## 조사를 자리표시에 붙여 적는다
##
## 이름 뒤의 조사는 받침에 따라 갈리고, **조사가 틀리면 이름이 이름으로 안 읽힌다**
## (19-rekka-voice.md §19.B.5 — `<웃는 베른>와` 가 실제로 나갔다).
## 받침 계산은 `KoreanParticle` 이 이미 한다. 여기서 다시 만들지 않는다.
##
## ## 채울 것이 없으면 줄을 버린다
##
## `{상대}` 는 얽힌 상대가 있을 때만 있다. 없는데 그 자리를 지우면 주어가 사라지고,
## `누군가` 로 메우면 **없는 인물을 지어낸 것**이 된다. 둘 다 사실을 건드리는 짓이라
## 줄을 통째로 버린다. 버려도 본문이 비지 않는 것은 자산 쪽의 책임이다 (§32.3.3).

## 받침에 따라 갈리는 조사. 값은 `KoreanParticle` 의 함수 이름이다.
##
## 여기 없는 조사(`에서` · `에` · `도` · `만` · `까지`)는 받침과 무관하므로
## 그대로 붙인다. **목록에 없다고 버리면 멀쩡한 문장이 사라진다.**
const VARIABLE_PARTICLES := {
	"은": "topic",
	"는": "topic",
	"이": "subject",
	"가": "subject",
	"을": "object_of",
	"를": "object_of",
	"와": "conjunction",
	"과": "conjunction",
	"으로": "direction",
	"로": "direction",
	"이다": "copula",
	"다": "copula",
}


## 한 줄을 채운다. **채울 수 없는 자리가 하나라도 있으면 빈 문자열이다.**
##
## 빈 문자열을 돌려주는 것이 이 함수의 절반이다 — 부르는 쪽은 그 줄을 버린다.
static func fill_line(line: String, values: Dictionary) -> String:
	var result := ""
	var cursor := 0
	while true:
		var open := line.find("{", cursor)
		if open < 0:
			result += line.substr(cursor)
			break
		var close := line.find("}", open)
		if close < 0:
			result += line.substr(cursor)
			break
		result += line.substr(cursor, open - cursor)
		var filled := _resolve(line.substr(open + 1, close - open - 1), values)
		if filled.is_empty():
			return ""
		result += filled
		cursor = close + 1
	return result


## 여러 줄을 채우고 **못 채운 줄은 버린다.** 빈 줄은 그대로 남긴다.
static func fill(text: String, values: Dictionary) -> Array[String]:
	var kept: Array[String] = []
	for line in text.split("\n"):
		var trimmed := (line as String).strip_edges()
		if trimmed.is_empty():
			kept.append("")
			continue
		var filled := fill_line(trimmed, values)
		if not filled.is_empty():
			kept.append(filled)
	return kept


## 이 문안이 어떤 자리를 쓰는가. 자산 검사에 쓴다.
static func keys_in(text: String) -> Array[String]:
	var found: Array[String] = []
	var cursor := 0
	while true:
		var open := text.find("{", cursor)
		if open < 0:
			break
		var close := text.find("}", open)
		if close < 0:
			break
		var token := text.substr(open + 1, close - open - 1)
		if not token.is_empty() and not found.has(token):
			found.append(token)
		cursor = close + 1
	return found


## 자리표시 하나를 푼다. 이름이 없거나 비어 있으면 빈 문자열이다.
##
## **긴 열쇠부터 맞춘다.** `{등급이}` 를 짧은 쪽부터 맞추면 `등` 이라는 열쇠가
## 있을 때 `급이` 가 조사가 된다. 실제로 그런 열쇠를 둘 일은 없지만,
## 맞추는 순서가 뜻을 바꾸는 규칙은 언제든 사고가 난다.
static func _resolve(token: String, values: Dictionary) -> String:
	var best := ""
	for key in values:
		var name := str(key)
		if token.begins_with(name) and name.length() > best.length():
			best = name
	if best.is_empty():
		return ""
	var value := str(values[best])
	if value.is_empty():
		return ""
	return value + _particle(token.substr(best.length()), value)


## 이름 뒤에 붙는 말. 받침에 따라 갈리는 것만 계산하고 나머지는 그대로 붙인다.
static func _particle(suffix: String, name: String) -> String:
	if suffix.is_empty():
		return ""
	if not VARIABLE_PARTICLES.has(suffix):
		return suffix
	match str(VARIABLE_PARTICLES[suffix]):
		"topic":
			return KoreanParticle.topic(name)
		"subject":
			return KoreanParticle.subject(name)
		"object_of":
			return KoreanParticle.object_of(name)
		"conjunction":
			return KoreanParticle.conjunction(name)
		"direction":
			return KoreanParticle.direction(name)
		_:
			return KoreanParticle.copula(name)
