class_name RelationLedger
extends RefCounted
## 굴린 사건의 기록. **관계가 들고 있는 「근거 사건 id」가 가리키는 곳이다.**
##
## docs/design/24-npc-relations.md §24.2 · §24.19.
##
## ## 왜 수치 옆에 사연이 있어야 하는가
##
## 설계 24.2 —
## *"근거 사건이 §5.10 의 「플레이어가 확률의 방향을 읽을 수 있어야 한다」 를 푼다.
## 수치를 보여주지 않고 사연을 보여주면 방향이 읽힌다."*
##
## `RelationGraph` 는 관계마다 `cause` 정수 하나만 든다. 그 정수가 무엇이었는지를
## **여기 한 곳에만** 둔다 — 관계 슬롯마다 문장을 복제하면 만 개가 된다.
##
## ## 저장 방식은 PersonRegistry 와 같다
##
## 병렬 배열이고 사건은 정수 인덱스다. 대상이 여럿인 사건(전멸)이 있어서
## 대상은 **평평한 배열 + 시작점**으로 눕힌다 — 사건마다 배열 객체를 만들지 않는다.
##
## ## 열전이 이것을 먹는다
##
## 설계 24.19 가 *"사건 기록 → 인물별 사건 이력 → 문장"* 을 그렸다.
## **인물별 색인을 따로 만들지 않는다** — 그 사람의 관계들이 근거 사건 id 를 이미 들고 있어서
## 관계를 훑으면 이력이 나온다 (`causes_of`). 설계 24.20.3 의
## *"저장하지 않고 계산한다"* 와 같은 판단이다.

## 아직 아무 사건도 아닌 자리. RelationGraph 와 같은 값을 쓴다.
const NO_CAUSE := RelationGraph.NO_CAUSE

var _kinds := PackedInt32Array()
var _actors := PackedInt32Array()
var _starts := PackedInt32Array()
var _targets := PackedInt32Array()


## 사건 하나를 적고 그 id 를 돌려준다. **그 id 가 관계의 근거 사건이 된다.**
func record(kind: RelationEvent.Kind, actor: int, targets: PackedInt32Array) -> int:
	var cause := _kinds.size()
	_kinds.append(int(kind))
	_actors.append(actor)
	_starts.append(_targets.size())
	_targets.append_array(targets)
	return cause


func size() -> int:
	return _kinds.size()


func has(cause: int) -> bool:
	return cause >= 0 and cause < _kinds.size()


func kind_of(cause: int) -> RelationEvent.Kind:
	return _kinds[cause] as RelationEvent.Kind


func actor_of(cause: int) -> int:
	return _actors[cause]


func targets_of(cause: int) -> PackedInt32Array:
	var start := _starts[cause]
	var end := _targets.size() if cause + 1 >= _starts.size() else _starts[cause + 1]
	return _targets.slice(start, end)


## 이 사람이 이 사건에서 무엇이었나. 열전이 *"나는 무엇이었나"* 를 말하는 근거다.
##
## **소문으로 안 것은 목격이 아니다.** 그것은 사건이 아니라 관계가 아는 사실이므로
## (RelationGraph.is_heard) 호출자가 알려 준다 — 안 가르면 화면이
## **모두가 모든 것을 목격한 것처럼** 말한다.
func role_of(cause: int, person: int, heard: bool = false) -> String:
	if not has(cause):
		return ""
	if _actors[cause] == person:
		return "행위자"
	if Array(targets_of(cause)).has(person):
		return "대상"
	return "소문" if heard else "목격자"


## `행위자였다` · `대상이었다` · `들었다`. 받침이 서술어를 가르므로 조사와 같이 낸다.
func role_phrase(cause: int, person: int, heard: bool = false) -> String:
	var role := role_of(cause, person, heard)
	if role.is_empty():
		return ""
	if role == "소문":
		return "전해 들었다"
	return "%s%s" % [role, "이었다" if KoreanParticle.has_final(role) else "였다"]


## 이 사람의 관계들이 기억하는 사건들. **오름차순이고 중복이 없다.**
##
## 사건이 일어난 순서가 곧 id 순서라 정렬이 곧 시간순이다.
func causes_of(graph: RelationGraph, person: int) -> PackedInt32Array:
	var seen := {}
	for other in graph.targets_of(person):
		var cause := graph.cause_of(person, other)
		if has(cause):
			seen[cause] = true
	var found := PackedInt32Array(seen.keys())
	found.sort()
	return found


## 이 사람이 이 사건을 **전해 들었나.** 그 사건을 근거로 삼는 관계에 표시가 있다.
##
## 관계마다 다르므로 사건이 아니라 관계에 물어야 한다 (RelationGraph.is_heard) —
## 같은 배신을 누구는 봤고 누구는 들었다.
func heard_by(graph: RelationGraph, person: int, cause: int) -> bool:
	for other in graph.targets_of(person):
		if graph.cause_of(person, other) == cause:
			return graph.is_heard(person, other)
	return false


## 한 줄 사연 — `배신 • 최윤호가 김건규를`.
##
## **조사는 `KoreanParticle` 이 받침으로 고른다.** `양은담가` 가 나오면 읽는 사람이
## 어디까지가 이름인지 다시 추측한다 (렉카가 같은 이유로 이미 만들어 둔 것을 쓴다).
##
## **가운뎃점(U+00B7)이 아니라 U+2022 를 쓴다.** 테마 폰트에 전자가 없어서
## 웹 빌드에서만 두부가 된다 (docs/conventions.md §5.1).
func describe(cause: int, registry: PersonRegistry) -> String:
	if not has(cause):
		return ""
	var kind := kind_of(cause)
	var actor := _name(registry, _actors[cause])
	var targets := targets_of(cause)
	if targets.is_empty():
		return "%s • %s" % [RelationEvent.label(kind), actor]

	var first := _name(registry, targets[0])
	match kind:
		RelationEvent.Kind.BETRAYAL:
			return (
				"배신 • %s%s %s%s"
				% [
					actor,
					KoreanParticle.subject(actor),
					first,
					KoreanParticle.object_of(first),
				]
			)
		RelationEvent.Kind.WIPEOUT:
			return "전멸 • %s%s 이끈 원정에서 %d명" % [actor, KoreanParticle.subject(actor), targets.size()]
		_:
			return "협력 • %s%s %s" % [actor, KoreanParticle.conjunction(actor), first]


func _name(registry: PersonRegistry, person: int) -> String:
	return registry.name_of(person) if registry.has(person) else "누군가"
