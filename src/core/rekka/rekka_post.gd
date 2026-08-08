class_name RekkaPost
extends RefCounted
## 모델이 뱉은 게시글에서 규칙 위반을 걷어낸다.
##
## ## 왜 프롬프트가 아니라 코드가 하는가
##
## **프롬프트에 적으면 산출이 나빠진다.** 시스템 프롬프트가 188자일 때 합니다체가
## 8회, 330자일 때 26회였다 (docs/design/19-rekka-voice.md §19.A.2 발견 1).
## 글자 제약 · 숫자 제약 · 접두어 제약을 전부 적으면 그만큼 길어지고,
## 길어진 만큼 모델이 몸을 사려 문어체로 도망간다.
##
## 그래서 **프롬프트에서 뺀 것을 여기서 보장한다** (§19.A.2 발견 4).
##
## | 처리 | 실측 근거 |
## | --- | --- |
## | 홑화살괄호 제거 | 입력 표시가 그대로 새어 나온다 |
## | 허용 문자 외 제거 | 매 호출에서 별표 · 말줄임표 · 곡선따옴표가 걸린다. 구자라트 문자가 나온 적도 있다 |
## | `제목:` 접두어 제거 | 5편 중 1편에서 "제목: ..." 이 그대로 나왔다 |
## | 수치화된 규모 제거 | 이 게임의 전투는 피해가 오가는 방식이 아니다 (05-rules.md §5.8) |
## | 접두어 · 닉네임 배정 | `RekkaHandles` 참고 |
##
## 웹 빌드에는 빌려 올 시스템 폰트가 없어서 폰트에 없는 글자가 그대로 두부가 된다
## (docs/conventions.md §5.1). 데스크톱 캡처로는 못 잡는 종류의 사고다.

## 그대로 써도 되는 문장부호. §19.4 의 목록과 같다.
##
## 대괄호가 들어 있는 이유는 댓글 닉네임 표시이기 때문이다.
const ALLOWED_PUNCTUATION := " .,?!~()\"':/%+-[]"

## 모양만 다른 글자를 폰트에 있는 것으로 옮긴다. **지우기 전에 옮긴다.**
##
## 곡선 따옴표를 그냥 지우면 인용부호가 통째로 사라져 문장이 달라진다.
## 옮기면 뜻이 남는다.
##
## **글자로 적지 않고 부호값으로 적는다.** 이 목록에는 폰트에 없는 글자가 들어 있어서
## 그대로 적으면 `tools/check_glyphs.gd` 가 목록 자체를 위반으로 잡는다
## (docs/design/19-rekka-voice.md §19.4.1 이 5차에서 이미 밟은 함정이다).
const _SUBSTITUTES := {
	"\u201c": '"',  # 여는 곡선 쌍따옴표
	"\u201d": '"',  # 닫는 곡선 쌍따옴표
	"\u2018": "'",  # 여는 곡선 홑따옴표
	"\u2019": "'",  # 닫는 곡선 홑따옴표
	"\u2026": "...",  # 말줄임표
	"\u2014": "-",  # 긴 가로줄
	"\u2013": "-",  # 짧은 가로줄
	"\uff1a": ":",  # 전각 콜론
	"\u00b7": " ",  # 가운뎃점
}

## 줄 앞에 붙어 나오는 서식 표시. 프롬프트에 없는데도 모델이 붙인다.
const _LABELS: Array[String] = ["제목", "본문", "내용", "댓글", "글", "제목줄"]

## 사람 수를 세는 단위. 인원은 등급으로만 말한다 (§19.3.3 규모 축).
##
## **`인` 은 뺐다.** 실측에서 `수확 0인데` 가 `수확 하나데` 로 망가졌다.
## 지키려던 바로 그 숫자(허탕도 정보다)를 지우는 규칙이면 규칙이 틀린 것이다.
## `3인 파티` 같은 것이 새어 나가는 쪽이 훨씬 싸다 — 못 잡은 것은 어색할 뿐이지만
## 잘못 잡은 것은 문장을 부순다.
const _HEADCOUNT_UNITS := "명|마리"

## 값어치와 피해를 세는 단위. 이 게임에는 피해량이라는 것 자체가 없다.
const _VALUE_UNITS := "골드|원|냥|피해|데미지|대미지|딜|뎀|체력|가치|값어치|코인|크레딧|실버|HP|hp"

## 한글 음절 영역.
const _SYLLABLE_FIRST := 0xAC00
const _SYLLABLE_LAST := 0xD7A3

## 반복 검출에서 훑는 음절 수. 넷이면 어미가 갈라져도 앞쪽이 남는다.
const _GRAM := 4

## 한글 호환 자모 영역. `ㅋㅋ` `ㄹㅇ` `ㅠㅠ` 가 여기 있다. 커뮤니티 말투의 절반이다.
const _JAMO_FIRST := 0x3131
const _JAMO_LAST := 0x3163

static var _headcount_re: RegEx = null
static var _value_re: RegEx = null
static var _handle_re: RegEx = null
static var _label_re: RegEx = null


## 후처리 전부를 순서대로 건다.
##
## `post_index` 는 판이 시작한 뒤로 몇 번째 게시글인가이고,
## `handle_start` 는 그때까지 쓴 댓글 수의 누계다. 둘 다 반복을 없애는 데 쓴다.
static func clean(
	raw: String,
	post_index: int = 0,
	handle_start: int = 0,
	names: Array[String] = [] as Array[String],
	salt: int = 0
) -> String:
	var text := _substitute(raw)
	text = strip_labels(text)
	text = strip_brackets(text)
	text = keep_allowed(text)
	text = scrub_magnitudes(text)
	text = normalize_names(text, names)
	text = apply_tag(text, post_index, salt)
	text = apply_handles(text, handle_start, salt)
	return _tidy(text)


## 띄어쓰기가 흔들린 이름을 판이 쓰는 표기로 되돌린다.
##
## 생성기는 같은 이름이 두 번 나오면 번호를 붙인다 — `중정 3`
## (`room_kind_planner.pick_name`). 모델은 그 사이 공백을 자주 빼먹어 `중정3` 으로 쓴다.
##
## **같은 방이 두 표기로 돌아다니면 플레이어가 다른 방으로 읽는다.**
## 방 이름은 과장 대상이 아니라 사실이고, 여기가 틀리면 기사가 판과 연결되지 않아
## 정보로서 무가치해진다 (13-information-design.md §13.3.1).
##
## 긴 이름부터 고친다. `중정 1` 을 먼저 고치면 `중정 12` 가 `중정 1` + `2` 로 쪼개진다.
static func normalize_names(text: String, names: Array[String]) -> String:
	var spaced: Array[String] = []
	for name in names:
		if name.contains(" "):
			spaced.append(name)
	spaced.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var result := text
	for name in spaced:
		result = result.replace(name.replace(" ", ""), name)
	return result


## 입력 표시로 쓴 홑화살괄호를 지운다.
##
## 이름을 감싸지 않으면 모델이 이름을 서술로 읽는다(§19.A.5). 감싸는 것은
## 입력에서만 필요하고 화면에 나가면 안 되므로 여기서 지운다.
static func strip_brackets(text: String) -> String:
	return text.replace("<", "").replace(">", "")


## 줄 앞의 `제목:` 같은 서식 표시를 지운다.
##
## **실측 결함이다.** 시스템 프롬프트에 "제목은 한 줄로" 라고만 적혀 있는데도
## 5편 중 1편이 "제목: ..." 으로 시작했다. 화면에 그대로 올라가면 게시글이 아니라 양식이 된다.
## **콜론이 없어도 잡는다.** 실측 24편 중 2편이 `본문` 한 단어만 있는 줄로 시작했고,
## 그 줄이 그대로 화면에 올라갔다. 콜론을 요구하는 규칙이 그것을 통과시켰다.
## 그 여파로 22편은 첫 문장의 주어까지 사라졌다 — 누구 얘긴지 본문만으로는 알 수 없다.
static func strip_labels(text: String) -> String:
	var pattern := _label_pattern()
	var result: Array[String] = []
	for line in text.split("\n"):
		var trimmed := (line as String).strip_edges()
		if _LABELS.has(trimmed):
			continue
		result.append(pattern.sub(line, "", false))
	return "\n".join(result)


## 허용 문자만 남긴다. 나머지는 통째로 버린다.
static func keep_allowed(text: String) -> String:
	var kept := ""
	for i in text.length():
		var character := text[i]
		if _is_allowed(character):
			kept += character
	return kept


## 수치화된 규모를 말로 바꾼다.
##
## ## 무엇을 막고 무엇을 남기는가
##
## 앞선 구현은 숫자를 보이는 대로 지웠고, 그 바람에 `전투 기록 0회` `수확량 0`
## `수확 1등` 의 숫자까지 사라졌다. **그 숫자들은 정보다.** 허탕도 정보이고
## (§19.3.3 빈손), 등수와 횟수는 플레이어가 판을 읽는 재료다.
##
## 막아야 하는 것은 **피해량과 전리품 값어치**뿐이다. 이 게임의 전투는 피해가 오가는
## 방식이 아니라 상황이 갈리는 방식이라(05-rules.md §5.8),
## `12 피해` 가 뜨면 있지도 않은 계량 감각이 생긴다. 인원도 마찬가지로 등급이 대신한다.
##
## | 걸린다 | 남는다 |
## | --- | --- |
## | `3명` `12 피해` `500골드` `8 값어치` | `0회` `1등` `세 번째` `전리품 0개` `50%` |
##
## 지우지 않고 **바꾼다.** 숫자만 지우면 `명 죽었다` 같은 부스러기가 남는다.
## 사람 수는 하나/여럿으로 접히므로 뜻이 보존되고, 값어치는 등급이 이미 본문에 있다.
##
## 한글 수사(`셋이 마주칠 각`)는 건드리지 않는다. 세는 말이 아니라 말투이고,
## 검증된 표본에서 그 표현이 제일 좋았다.
static func scrub_magnitudes(text: String) -> String:
	var result := _sub_headcount(text)
	return _value_pattern().sub(result, "얼마어치", true)


## 걸릴 자리들. 검사기와 테스트가 쓴다.
static func blocked_numbers(text: String) -> Array[String]:
	var found: Array[String] = []
	for hit in _headcount_pattern().search_all(text):
		found.append(hit.get_string())
	for hit in _value_pattern().search_all(text):
		found.append(hit.get_string())
	return found


## 제목 접두어를 코드가 배정한 것으로 갈아 끼운다.
##
## 모델이 붙인 것은 버린다. 실측에서 `[속보]` 가 5편 중 4편에 붙었다.
static func apply_tag(text: String, index: int, salt: int = 0) -> String:
	var lines := text.split("\n")
	for i in lines.size():
		var line := (lines[i] as String).strip_edges()
		if line.is_empty():
			continue
		lines[i] = _retag(line, RekkaHandles.tag_for(index, salt))
		break
	return "\n".join(lines)


## 댓글 닉네임을 코드가 배정한 것으로 갈아 끼운다.
##
## 같은 편 안에서 같은 닉으로 두 번 단 댓글은 같은 닉으로 남는다. 그건 반복이 아니라
## 한 사람이 두 번 단 것이다.
static func apply_handles(text: String, start_index: int, salt: int = 0) -> String:
	var pattern := _handle_pattern()
	var lines := text.split("\n")
	var assigned: Dictionary = {}
	var title_seen := false
	for i in lines.size():
		var line: String = lines[i]
		if line.strip_edges().is_empty():
			continue
		if not title_seen:
			title_seen = true
			continue
		var found := pattern.search(line)
		if found == null:
			continue
		var original := found.get_string(1)
		if not assigned.has(original):
			assigned[original] = RekkaHandles.handle_for(start_index + assigned.size(), salt)
		lines[i] = "[%s]%s" % [assigned[original], line.substr(found.get_end())]
	return "\n".join(lines)


## 게시글의 제목 줄. 접두어는 뗀 것이다.
##
## 이것을 다음 턴의 입력에 `이미 써먹은 말` 로 되돌려 주면 밈 반복이 줄어든다.
## 실측 24편 대조 — `학계 정설` 5편에서 3편, `실화냐` 2편에서 0편,
## `떴노` 2편에서 0편, 제목 접두어 13편에서 8편 (§19.B.4).
## 모델은 턴마다 새로 불려서 자기가 방금 뭘 썼는지 모르므로 코드가 알려 줘야 한다.
static func title_of(text: String) -> String:
	for line in text.split("\n"):
		var trimmed := (line as String).strip_edges()
		if trimmed.is_empty():
			continue
		return _retag(trimmed, "")
	return ""


## 최근 게시글에서 **이미 두 번 이상 나온 말.**
##
## 이것을 다음 턴 입력의 `이미 써먹은 말` 로 되돌려 준다.
## 제목만 되돌려 줬을 때 `학계 정설` 이 7편에서 3편으로 줄었다 — **되돌려 주면 준다.**
## 그런데 제목만으로는 본문과 댓글의 버릇을 못 잡는다.
## `A가 아니라 B다` 구문이 28편 중 18편에 있었다 (§19.B.8).
##
## ## 낱말이 아니라 음절 덩어리로 센다
##
## 한국어는 같은 말이 어미로 갈라진다 — `학계 정설임` 과 `학계 정설이지` 는
## 낱말로 맞추면 서로 다른 말이다. 그래서 **띄어쓰기를 지우고 네 음절씩 훑는다.**
## 어미가 달라도 앞쪽 네 음절이 같으면 같은 버릇으로 잡힌다.
##
## **이미 반복된 것만 고른다.** 한 번 나온 말까지 금지하면 화자의 어휘가 매 턴 깎이고,
## 무엇을 금지할지 사람이 정하면 그 목록이 곧 새로운 틀이 된다.
## 두 번 나왔다는 사실 자체가 고르는 기준이라 목록이 저절로 판을 따라간다.
##
## `exclude` 는 이번 턴 입력이다. 거기 있는 말(인물 · 방 · 등급)은 금지하면 안 된다 —
## 사실을 말하지 못하게 막는 꼴이 된다.
static func repeated_phrases(
	recent: Array[String], exclude: String = "", limit: int = 5
) -> Array[String]:
	var barred := _hangul_only(exclude)
	var counts: Dictionary = {}
	for post in recent:
		for gram in _grams_in(post):
			counts[gram] = int(counts.get(gram, 0)) + 1

	var ranked: Array[String] = []
	for gram in counts:
		if int(counts[gram]) >= 2 and not barred.contains(gram):
			ranked.append(gram)
	ranked.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]))

	# 한 구절에서 나온 이웃 덩어리들을 다 싣지 않는다. `학계정설` 과 `계정설임` 을
	# 둘 다 주면 금지 목록이 같은 말로 채워져 정작 다른 버릇이 밀려난다.
	var found: Array[String] = []
	for gram in ranked:
		if found.size() >= maxi(0, limit):
			break
		if not _overlaps(found, gram):
			found.append(gram)
	return found


## 그 글에 나오는 서로 다른 음절 덩어리들.
static func _grams_in(post: String) -> Array[String]:
	var text := _hangul_only(post)
	var seen: Dictionary = {}
	for i in maxi(0, text.length() - _GRAM + 1):
		seen[text.substr(i, _GRAM)] = true
	var result: Array[String] = []
	for gram in seen:
		result.append(gram)
	return result


## 이미 고른 것과 겹치는가. 절반 넘게 같으면 같은 구절에서 나온 것으로 본다.
static func _overlaps(found: Array[String], gram: String) -> bool:
	var half := gram.substr(0, _GRAM / 2 + 1)
	for kept in found:
		if kept.contains(half) or gram.contains(kept.substr(0, _GRAM / 2 + 1)):
			return true
	return false


## 한글 음절만 남긴다. 띄어쓰기와 부호는 버린다.
static func _hangul_only(text: String) -> String:
	var kept := ""
	for i in text.length():
		var code := text[i].unicode_at(0)
		if code >= _SYLLABLE_FIRST and code <= _SYLLABLE_LAST:
			kept += text[i]
	return kept


## 이 게시글이 쓴 서로 다른 닉의 수. 다음 편의 시작 번호를 이만큼 밀면 겹치지 않는다.
static func distinct_handle_count(text: String) -> int:
	var pattern := _handle_pattern()
	var seen: Dictionary = {}
	var title_seen := false
	for line in text.split("\n"):
		if (line as String).strip_edges().is_empty():
			continue
		if not title_seen:
			title_seen = true
			continue
		var found := pattern.search(line)
		if found != null:
			seen[found.get_string(1)] = true
	return seen.size()


static func _substitute(text: String) -> String:
	var result := text
	for source in _SUBSTITUTES:
		result = result.replace(source, _SUBSTITUTES[source])
	return result


static func _is_allowed(character: String) -> bool:
	if character == "\n":
		return true
	var code := character.unicode_at(0)
	if code >= _SYLLABLE_FIRST and code <= _SYLLABLE_LAST:
		return true
	if code >= _JAMO_FIRST and code <= _JAMO_LAST:
		return true
	if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
		return true
	return ALLOWED_PUNCTUATION.contains(character)


## 사람 수는 세지 않고 접는다. 하나는 하나로, 둘 이상은 여럿으로.
static func _sub_headcount(text: String) -> String:
	var pattern := _headcount_pattern()
	var result := ""
	var cursor := 0
	for hit in pattern.search_all(text):
		result += text.substr(cursor, hit.get_start() - cursor)
		result += "하나" if hit.get_string(1).to_int() <= 1 else "여럿"
		cursor = hit.get_end()
	return result + text.substr(cursor)


## 제목 줄에서 모델이 붙인 대괄호 접두어를 떼고 배정된 것을 붙인다.
static func _retag(line: String, tag: String) -> String:
	var body := line
	while body.begins_with("["):
		var close := body.find("]")
		if close < 0:
			break
		body = body.substr(close + 1).strip_edges()
	if tag.is_empty():
		return body
	return "%s %s" % [tag, body]


## 줄 끝 공백과 겹친 빈 줄을 정리하고 **댓글 사이를 고르게 띄운다.**
##
## 화면 배치는 문체가 아니라 규칙이다. 모델은 같은 프롬프트에서도 댓글을 붙여 쓰기도
## 하고 띄워 쓰기도 하는데, 실측 24편에서 여섯 편만 붙어 나왔다.
## 렌더러가 그것을 그대로 먹으면 같은 피드 안에서 여섯 편만 다르게 보인다.
static func _tidy(text: String) -> String:
	var result: Array[String] = []
	var blanks := 0
	var seen := 0
	for line in text.split("\n"):
		var trimmed := (line as String).strip_edges(false, true)
		if trimmed.strip_edges().is_empty():
			blanks += 1
			if blanks <= 1 and not result.is_empty():
				result.append("")
			continue
		# 줄 안의 겹친 공백도 하나로 접는다. 지운 글자 자리에 구멍이 남는다.
		while trimmed.contains("  "):
			trimmed = trimmed.replace("  ", " ")
		seen += 1
		# 제목 바로 다음과 댓글 앞에는 언제나 빈 줄 하나를 둔다.
		# 첫 줄은 접두어 때문에 대괄호로 시작할 수 있으므로 빈 결과일 때는 건너뛴다.
		var wants_gap := seen == 2 or trimmed.begins_with("[")
		if wants_gap and blanks == 0 and not result.is_empty():
			result.append("")
		blanks = 0
		result.append(trimmed)
	return "\n".join(result).strip_edges()


static func _headcount_pattern() -> RegEx:
	if _headcount_re == null:
		_headcount_re = RegEx.create_from_string("(\\d+)\\s*(?:%s)" % _HEADCOUNT_UNITS)
	return _headcount_re


static func _value_pattern() -> RegEx:
	if _value_re == null:
		_value_re = RegEx.create_from_string("(\\d+)\\s*(?:%s)" % _VALUE_UNITS)
	return _value_re


static func _handle_pattern() -> RegEx:
	if _handle_re == null:
		_handle_re = RegEx.create_from_string("^\\s*\\[([^\\]]*)\\]")
	return _handle_re


static func _label_pattern() -> RegEx:
	if _label_re == null:
		_label_re = RegEx.create_from_string("^\\s*(?:%s)\\s*[:\uff1a]\\s*" % "|".join(_LABELS))
	return _label_re
