class_name WorldNews
extends RefCounted
## 세계에서 난 일 중 **내가 알 만한 것**만 골라 한 줄로 낸다.
##
## docs/design/37-meta-loop.md §37.6, docs/design/15-world.md §15.2.1,
## docs/design/24-npc-relations.md §24.11.
##
## ## 전부 적지 않는다
##
## §24.11 — *"매 틱 세계 곳곳에서 사건이 발생하고 **대부분은 플레이어가 모른다.**
## 일부만 렉카 피드로 드러난다 — 그것이 정보 자원."*
##
## 스무 판이면 사건이 300건 넘게 쌓인다. 그것을 다 적으면 피드가 아니라 로그다.
## **고르는 규칙이 이 클래스의 전부다** (§37.6.2) —
##
## | 남기는 것 | 왜 |
## | --- | --- |
## | 아는 얼굴이 낀 것 | 대원 · 후보 · 그들의 연줄. 설계 15.2.2 가 이름에 무게를 붙이는 통로다 |
## | 유명한 사람이 낀 것 | §24.7 — *"무명인 사람 얘기는 아무도 안 본다"* |
## | 그 밖 | **버린다** |
##
## ## 내가 한 일은 뉴스가 아니다 — **재 보고 넣은 규칙이다**
##
## 처음에는 아는 얼굴만 걸렀더니 **다섯 줄이 전부 「내 대원과 내 대원이 같이 뛰었다」**
## 였다. 당연하다 — `WorldStep._bind_together` 가 매 틱 내 대원끼리 협력 사건을 적고,
## 그것이 장부의 **맨 끝**에 쌓인다. 방금 내가 한 일을 뉴스라고 읽어 주는 셈이고,
## 그것은 정산 화면이 이미 말한 것이다 (`SettlementSheet._squad_sheet`).
##
## 그래서 **행위자와 대상이 전부 내 사람이면 버린다.** 내 대원이 **바깥 사람과** 얽힌
## 것은 남는다 — 그것이 설계 15.2.2 의 *"NPC 가 인물이 된다"* 가 도는 자리다.
##
## ## 문장은 지어내지 않는다
##
## 자리표시와 조사는 `RekkaSlots` 가 이미 한다 — 받침을 여기서 다시 계산하면
## `양은담와` 가 나온다 (설계 19.B.5). 접두어도 `RekkaHandles` 것을 그대로 쓴다.
##
## **렉카 문안 자산은 안 쓴다.** 그쪽 열쇠는 던전 사건(`GameEvent`)의 등급으로 만들어져
## 있어서, 세계 사건에 붙이려면 **방과 전리품 등급을 지어내야** 한다 —
## 설계 13.3.0 의 *"로그에 담기는 값은 언제나 진실"* 을 어긴다 (§37.6.1).

## 한 번에 내는 줄 수. 아지트 칸 하나에 들어가는 만큼이다.
const MAX_LINES := 5

## 뒤에서 이만큼만 훑는다. **오래된 소식은 소식이 아니다** — 그리고 사건이 수천 건
## 쌓여도 이 값이 비용의 상한이 된다.
const MAX_SCAN := 400

## 자리표시 이름. 문장 틀과 값이 같은 열쇠를 써야 한다.
const ACTOR := "이름"
const TARGET := "상대"

## 사건 하나를 한 줄로. **`RelationEvent.Kind` 순서와 나란하다.**
##
## `{이름이}` 처럼 자리표시에 조사를 붙여 적는다 — 받침 계산은 `RekkaSlots` 가 한다.
## 조사가 받침을 안 타는 것(`에게` · `의`)은 그대로 붙는다.
##
## **후유증(3번)이 빈 칸인 것은 의도다** (`_LINES` 를 훑는 쪽이 빈 줄을 버린다).
## 세계는 후유증을 안 굴리고(`EventSeeder.KIND_WEIGHTS` 가 0 이다) 그것은 **내 원정이
## 남기는 것**이라 정산 화면이 이미 한 줄로 적는다 (`SettlementSheet`).
## 게다가 그 사건의 대상 칸에는 사람이 아니라 **틱 번호**가 들어 있다.
const LINES: Array[String] = [
	"{이름과} {상대가} 같이 뛰었다",
	"{이름이} {상대를} 등졌다",
	"{이름이} 이끈 원정이 몰살당했다",
	"",
	"{이름이} {상대를} 끌고 나왔다",
	"{이름이} {상대에게} 길을 일러 줬다",
	"{이름과} {상대가} 안 싸우기로 했다",
	"{이름이} {상대를} 말없이 먼저 쳤다",
	"{이름이} {상대를} 털었다",
	"{이름이} {상대를} 두고 나왔다",
	"{이름이} {상대를} 못 본 척 지나갔다",
	"{이름이} {상대를} 함정으로 보냈다",
	"{이름이} {상대의} 정보를 팔았다",
	"{이름이} {상대의} 위치를 흘렸다",
	"{이름이} {상대의} 주검을 털었다",
	"{이름이} 있던 길드를 나갔다",
	"{이름이} 계약을 깼다",
	"{이름이} 길드를 세웠다",
	"{이름이} 1면에 실렸다",
	"{이름이} 크게 한 건 했다",
	"{이름이} 더 깊이 들어갔다",
]


## 최근 소식 몇 줄. **최신이 앞이다** (설계 8.2 — 최신이 위).
##
## `known` 은 내가 아는 사람들의 인물 번호다 (`GuildCircle.known_of`).
## 비어 있어도 돈다 — 그때는 유명한 사람 소식만 남는다.
## `mine` 은 **내 대원**이다. 그들끼리 벌어진 일은 내가 한 일이라 뉴스가 아니다.
static func gather(
	world: NpcWorld,
	known: PackedInt32Array,
	mine: PackedInt32Array = PackedInt32Array(),
	limit: int = MAX_LINES
) -> Array[String]:
	var found: Array[String] = []
	if world == null or world.ledger == null or limit <= 0:
		return found

	var seen := _set_of(known)
	var ours := _set_of(mine)

	var newest := world.ledger.size() - 1
	var oldest := maxi(newest - MAX_SCAN + 1, 0)
	for cause in range(newest, oldest - 1, -1):
		if found.size() >= limit:
			break
		if _is_our_own(world, cause, ours):
			continue
		if not _worth_telling(world, cause, seen):
			continue
		var line := line_for(world, cause)
		if not line.is_empty():
			found.append(line)
	return found


## 인물 번호 묶음을 훑기 쉬운 모양으로.
static func _set_of(people: PackedInt32Array) -> Dictionary:
	var found := {}
	for person in people:
		found[person] = true
	return found


## 내 사람들끼리만 벌어진 일인가. **그것은 내가 한 일이지 소식이 아니다.**
static func _is_our_own(world: NpcWorld, cause: int, ours: Dictionary) -> bool:
	if ours.is_empty() or not ours.has(world.ledger.actor_of(cause)):
		return false
	if world.ledger.kind_of(cause) == RelationEvent.Kind.AFTERMATH:
		return true
	for target in world.ledger.targets_of(cause):
		if not ours.has(target):
			return false
	return true


## 이 사건이 사람에게 갈 만한가.
static func _worth_telling(world: NpcWorld, cause: int, seen: Dictionary) -> bool:
	var actor := world.ledger.actor_of(cause)
	if seen.has(actor):
		return true
	if world.registry.fame_of(actor) >= PersonGenerator.FAME_KNOWN:
		return true
	# **후유증의 대상 칸에는 사람이 아니라 틱 번호가 들어 있다** (`WorldStep._shock`).
	# 그것을 인물 번호로 읽으면 엉뚱한 사람이 소식에 낀다.
	if world.ledger.kind_of(cause) == RelationEvent.Kind.AFTERMATH:
		return false
	for target in world.ledger.targets_of(cause):
		if seen.has(target):
			return true
	return false


## 사건 하나를 한 줄로. 채울 수 없으면 빈 문자열이다 — 부르는 쪽이 버린다.
##
## 접두어는 렉카 것을 그대로 쓴다. **절반이 빈 칸이라** 매번 붙지 않는다
## (`RekkaHandles.TAGS` — *"매번 붙으면 그게 곧 틀이다"*).
static func line_for(world: NpcWorld, cause: int) -> String:
	if world == null or world.ledger == null or not world.ledger.has(cause):
		return ""
	var kind := int(world.ledger.kind_of(cause))
	if kind < 0 or kind >= LINES.size() or LINES[kind].is_empty():
		return ""

	var values := {ACTOR: world.registry.name_of(world.ledger.actor_of(cause))}
	var targets := world.ledger.targets_of(cause)
	if not targets.is_empty() and world.registry.has(targets[0]):
		values[TARGET] = world.registry.name_of(targets[0])

	var filled := RekkaSlots.fill_line(LINES[kind], values)
	if filled.is_empty():
		return ""
	var tag := RekkaHandles.tag_for(cause, world.seed_value)
	return filled if tag.is_empty() else "%s %s" % [tag, filled]
