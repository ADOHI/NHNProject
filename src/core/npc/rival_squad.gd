class_name RivalSquad
extends RefCounted
## 던전에서 마주치는 **상대 스쿼드.** 여섯 자리가 전부 세계의 인물이다.
##
## docs/design/24-npc-relations.md §24.29, docs/design/05-rules.md §5.8 (조우 절차).
##
## ## 왜 무작위 여섯이면 안 되나
##
## 3000명에서 아무나 여섯을 뽑으면 **아는 얼굴이 한 번도 안 섞인다** —
## 내가 아는 사람이 넷뿐이라 겹칠 확률이 1% 도 안 된다. 그러면 조우 화면이
## 이름 여섯 개일 뿐이고, 관계도를 만든 값이 전투 앞에 서지 않는다.
##
## ## 저쪽도 한 길드다
##
## **상대 스쿼드는 소속에서 나온다.** 서로 남남인 여섯은 스쿼드가 아니고,
## 무엇보다 **아는 얼굴이 섞이려면 저쪽이 세계의 한 덩어리여야 한다** —
## 3000명에서 흩어 뽑으면 내가 아는 넷과 겹칠 일이 없다 (§24.29.3).
##
## | 겹 | 무엇 | 왜 |
## | --- | --- | --- |
## | **소속** | 절반은 **우리가 엮인 소속**, 절반은 아무 소속 | 아는 얼굴이 **가끔** 섞인다 |
## | **여섯** | 그 소속 안에서 | 저쪽도 한 팀이다 |
##
## **「가끔」이 어려운 자리다.** 너무 자주면 우연이 아니고 너무 드물면 시스템이 안 보인다.
## `NEARBY_CHANCE` 가 그 손잡이이고 값은 실측으로 잡았다 (§24.29.3).
##
## **기점을 우리 연줄에서 바로 뽑는 방법을 먼저 써 봤고 버렸다** —
## 그러면 「아는 얼굴이 있다」가 손잡이 값과 정확히 같아져서
## **우연이 아니라 기계가 드러난다.** 소속을 고르면 겹치는 수가 저절로 갈린다.
##
## ## 관계는 안 만든다
##
## 조우했다고 관계가 생기지 않는다. **관계는 사건의 찌꺼기다** (설계 24.5) —
## 싸우거나 협력하거나 배신한 뒤에 `RelationResolver` 가 만든다.
## 여기는 **누가 그 자리에 서는지**만 정한다.

## 조우 화면의 자리 수. UI 레인이 원형에 여섯을 세운다.
const SIZE := 6

## 소속을 **우리가 엮인 곳에서** 고를 확률.
##
## 1.0 이면 매번 아는 얼굴 쪽으로 기울어 우연이 아니게 되고, 0 이면 3000명에서
## 무작위라 거의 안 섞인다. 값의 근거는 §24.29.3 의 실측표다.
const NEARBY_CHANCE := 0.5

## 이 스쿼드에 선 사람들. 세계의 인물 번호다.
var members := PackedInt32Array()

## 어느 소속에서 왔나. **저쪽 길드의 이름표**다 (아직 이름은 없다, §24.16.5).
var faction: int = PersonRegistry.NO_FACTION

var _world: NpcWorld


func _init(world: NpcWorld) -> void:
	_world = world


## 한 무리를 뽑는다. viewers 는 **보는 쪽 사람들**(우리 대원)이고,
## 그 사람들의 연줄이 어느 소속을 만날지를 기울인다.
##
## viewers 가 비면 세계에서 아무 소속이나 고른다 — 플레이어와 무관한
## 두 무리가 서로 만나는 경우다 (설계 24.11 의 세계가 도는 것).
static func draw(
	world: NpcWorld, rng: RandomNumberGenerator, viewers: PackedInt32Array, size: int = SIZE
) -> RivalSquad:
	var squad := RivalSquad.new(world)
	if world == null or not world.is_ready() or world.registry.size() == 0:
		return squad

	squad.faction = squad._pick_faction(rng, viewers)
	var pool := world.factions.members_of(squad.faction)
	if pool.is_empty():
		return squad

	var taken := {}
	for viewer in viewers:
		taken[viewer] = true
	# 소속이 여섯보다 작을 수 있다. 그러면 있는 만큼만 선다.
	for _try in pool.size() * 2:
		if squad.members.size() >= maxi(size, 1):
			break
		var pick := pool[rng.randi() % pool.size()]
		if taken.has(pick):
			continue
		taken[pick] = true
		squad.members.append(pick)
	return squad


func size() -> int:
	return members.size()


## 보는 사람들이 **아는 얼굴**들. 한쪽만 알아도 센다 (SocialReach.familiar).
##
## 조우에서는 방향이 둘 다 뜻이 있다 — 내가 저 사람을 아는 것도,
## 저 사람이 나를 아는 것도 그 자리에 정보를 만든다 (설계 24.8).
func familiar_to(viewers: PackedInt32Array) -> PackedInt32Array:
	var found := PackedInt32Array()
	if _world == null:
		return found
	for member in members:
		for viewer in viewers:
			if _world.registry.has(viewer) and SocialReach.familiar(_world.graph, viewer, member):
				found.append(member)
				break
	return found


## 어느 소속을 만나나. 절반은 **우리가 엮인 소속**, 절반은 아무 소속.
##
## 「우리가 엮인 소속」은 우리 사람들이 아는 이들이 몸담은 곳이다 —
## *"저 길드에 내 대원의 형이 있다"* 가 그렇게 성립한다 (설계 24.22.5 의
## *"가족이 소속을 가로지른다"* 가 여기서 값을 한다).
func _pick_faction(rng: RandomNumberGenerator, viewers: PackedInt32Array) -> int:
	if not viewers.is_empty() and rng.randf() < NEARBY_CHANCE:
		var linked := _linked_factions(viewers)
		if not linked.is_empty():
			return linked[rng.randi() % linked.size()]
	return SocialReach.pick_faction(_world, rng, SIZE)


## 우리 사람들의 연줄이 몸담은 소속들. 우리 소속 자체는 뺀다 — 우리를 만날 수는 없다.
func _linked_factions(viewers: PackedInt32Array) -> PackedInt32Array:
	var ours := {}
	for viewer in viewers:
		if _world.registry.has(viewer):
			ours[_world.registry.faction_of(viewer)] = true

	var found := PackedInt32Array()
	var seen := {}
	for viewer in viewers:
		if not _world.registry.has(viewer):
			continue
		for other in _world.graph.targets_of(viewer):
			var where := _world.registry.faction_of(other)
			if where == PersonRegistry.NO_FACTION or ours.has(where) or seen.has(where):
				continue
			if _world.factions.size_of(where) < SIZE:
				continue
			seen[where] = true
			found.append(where)
	return found
