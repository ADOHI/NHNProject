class_name RekkaLibrary
extends Resource
## **미리 만들어 실어 둔 문안 한 벌.**
##
## ## 왜 자산인가
##
## 웹(HTML5) 제출이라 브라우저에서 언어 모델을 직접 부를 수 없다 —
## 키가 빌드 안에 박힌다 (docs/design/19-rekka-voice.md §19.10 방식 A, **채택 불가**).
## 그래서 §19.10 이 *"현실적인 선"* 으로 지목한 **방식 E** 를 쓴다:
## 개발 단계에서 언어 모델로 뽑고 **결과를 자산화한다.**
##
## ## 자산이 사실을 말하지 않는다
##
## 이 자산에는 **제목 · 논평 · 댓글**만 있다. 사실 줄은 언제나 규칙이 만든다
## (`RekkaStock.fact_lines`). 나누는 이유는 §19.6.2 의 원칙 그대로다 —
## **보장되어야 하는 것은 규칙이 맡고, 좋게 들려야 하는 것은 모델이 맡는다.**
##
## 이 나눔이 세 가지를 한꺼번에 해결한다.
##
## | 문제 | 왜 풀리는가 |
## | --- | --- |
## | 자산이 사건을 지어낸다 | 자산은 사실 줄을 쓰지 않는다. 쓸 자리가 없다 |
## | 자산에 없는 조합에서 정보가 사라진다 | 사실 줄은 자산과 무관하게 언제나 나온다 |
## | 조합이 터진다 | 한 키가 그 종류 x 등급의 모든 판에 재사용된다 |
##
## ## 형식은 `.tres` 다
##
## `res://` 에서 `load()` 로 열리는 자원이어야 한다. `FileAccess` 로 원본 파일을
## 읽으면 **로컬은 되고 웹 내보내기에서 깨진다** — 내보내기 필터에 걸리지 않은
## 원본은 `.pck` 에 안 들어간다.
##
## 자산 자체는 손으로 적지 않는다. 읽고 고치는 것은
## `docs/design/samples/rekka/stock-library.txt` 이고,
## `tools/build_rekka_library.gd` 가 그것을 `.tres` 로 굽는다.
## **원문이 `.txt` 라 `tools/check_glyphs_text.gd` 가 그대로 훑는다** —
## 화면에 나갈 글자가 폰트에 없으면 웹에서 두부(□)가 된다.

## 이 자산의 기본 자리.
const DEFAULT_PATH := "res://assets/rekka/rekka_library.tres"

## 사건이 하나도 없는 턴의 열쇠. 그 턴에는 종류도 등급도 없다.
const QUIET_KEY := "QUIET"

## `GameEvent.Kind` 를 열쇠에 적을 이름으로. **숫자를 쓰지 않는다** —
## enum 값은 항목이 하나 끼면 통째로 밀린다. 그러면 자산 전체가 조용히 어긋난다.
const KIND_NAMES := {
	GameEvent.Kind.MOVED: "MOVED",
	GameEvent.Kind.SEARCHED: "SEARCHED",
	GameEvent.Kind.ACQUIRED: "ACQUIRED",
	GameEvent.Kind.ENCOUNTERED: "ENCOUNTERED",
	GameEvent.Kind.FOUGHT: "FOUGHT",
	GameEvent.Kind.NEGOTIATED: "NEGOTIATED",
	GameEvent.Kind.FLED: "FLED",
	GameEvent.Kind.DOWNED: "DOWNED",
	GameEvent.Kind.ESCAPED: "ESCAPED",
}

static var _cached: RekkaLibrary = null

## 문안의 열쇠들. `posts` 와 같은 길이이고 같은 자리끼리 짝이다.
##
## 같은 열쇠가 여러 번 나올 수 있다. 그것이 곧 "결" 이다 (§19.10.1) —
## 같은 상황이 두 번 나왔을 때 같은 글이 나오면 안 된다.
@export var keys: PackedStringArray = PackedStringArray()

## 문안 본문들. 한 칸이 게시글 한 편의 **제목 · 논평 · 댓글**이다.
@export var posts: PackedStringArray = PackedStringArray()


## 실려 있는 자산. 없으면 `null` 이 아니라 **빈 자산**을 돌려준다.
##
## `null` 을 돌려주면 부르는 쪽마다 검사를 해야 하고, 한 곳이라도 빠뜨리면
## 그 판의 피드가 통째로 죽는다. 빈 자산은 언제나 못 찾았다고 답할 뿐이라
## 예비 문안으로 조용히 넘어간다 — **피드는 절대 비지 않는다** (§19.10).
static func shared() -> RekkaLibrary:
	if _cached == null:
		var found: Resource = load(DEFAULT_PATH) if ResourceLoader.exists(DEFAULT_PATH) else null
		_cached = found as RekkaLibrary
		if _cached == null:
			_cached = RekkaLibrary.new()
	return _cached


## 사건에서 열쇠를 만든다. **수치가 아니라 등급이다** (§19.10.1).
##
## 사건이 없으면 `QUIET` 다. 등급이 없는 종류(이동)는 뒷칸이 빈다.
static func key_for(event: GameEvent) -> String:
	if event == null:
		return QUIET_KEY
	return "%s:%s" % [KIND_NAMES.get(event.kind, ""), RekkaPrompt.grade_of(event)]


## 이 열쇠에 실린 문안들.
func posts_for(key: String) -> Array[String]:
	var found: Array[String] = []
	for i in mini(keys.size(), posts.size()):
		if keys[i] == key:
			found.append(posts[i])
	return found


## 이 열쇠의 문안 하나. 없으면 빈 문자열이고, 부르는 쪽은 예비 문안으로 간다.
##
## 여럿이면 걸음으로 건너뛴다. 순서대로 쓰면 같은 상황이 언제나 같은 순서로 돈다.
func pick(key: String, index: int, salt: int = 0) -> String:
	var found := posts_for(key)
	if found.is_empty():
		return ""
	return found[RekkaRing.slot(index, salt, found.size())]


## 실린 편 수.
func count() -> int:
	return mini(keys.size(), posts.size())
