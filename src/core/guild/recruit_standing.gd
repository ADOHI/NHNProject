class_name RecruitStanding
extends RefCounted
## 후보 하나를 데려올 수 있는가. **호감 · 유대 · 성향 궁합 셋이 조건이다.**
##
## docs/design/24-npc-relations.md §24.13,
## docs/design/06-progression.md §6.1 — *"영입은 자원만으로 되지 않고
## 던전에서 쌓은 관계를 요구한다."*
##
## ## 왜 이 클래스가 따로 있나
##
## `RecruitProspect` 는 **접선처가 찾아낸 후보**라는 사실만 든다 (설계 22.7).
## 판정은 관계 그래프를 봐야 하는데, 그것을 후보 안에 넣으면 후보가
## `PersonRegistry` 와 `RelationGraph` 를 들고 다녀야 한다.
## **판정을 값으로 뽑아 두면** 후보는 결과만 들고 화면은 이유를 그대로 낸다.
##
## ## 방향이 정해져 있다 — 후보가 나를 어떻게 보는가
##
## 관계는 비대칭이다 (설계 24.21.2). 영입에서 무게가 있는 쪽은
## **후보가 영입하는 사람에게 갖는 호감**이다. 내가 저 사람을 좋아하는 것은
## 영입에 아무 영향이 없다 — 오는 것은 저쪽이다.
##
## ## 성향 궁합을 위계 축으로 잡은 이유
##
## 설계 24.13 — *"자유형은 위계 강한 길드에 오지 않는다."*
## 길드에는 아직 성향이 없다 (설계 24.1 의 2층이 미구현). **그래서 영입하는 사람의
## 위계 값을 길드의 위계로 읽는다** — 사람 하나가 길드를 대표하는 것은 임시이고,
## 2층이 서면 그 자리에 길드의 값이 들어온다.

## 호감의 기준선. 여기에 의리 축이 얹힌다.
const AFFINITY_BASE := 30

## 의리 축이 기준선을 얼마나 밀 수 있나.
##
## **실리형은 호감이 낮아도 온다** (설계 24.13). 의리 +100 이면 55 를 요구하고
## 실리 -100 이면 5 만 요구한다 — 의리형은 사람을 보고 오고 실리형은 조건을 보고 온다.
const AFFINITY_LOYAL_SPREAD := 25

## 유명세가 요구 호감을 얼마나 밀어 올리나 (설계 24.42).
##
## [`02`](../../docs/design/02-overview.md) §2.6 — *"영입 — 유명 선수 이적.
## 주목도가 곧 몸값."* **이 게임에는 아직 이적료가 없다** (영입 실행 자체가 없다,
## §22.7). 그러면 몸값을 무엇으로 치르나 — **이 게임의 화폐는 관계다** (설계 6.1
## *"영입은 자원만으로 되지 않고 던전에서 쌓은 관계를 요구한다"*).
##
## 그래서 유명세는 **돈이 아니라 호감을 더 요구한다.** 유명한 사람은
## *"당신이 누군데"* 가 성립하고, 무명인 사람은 그렇지 않다.
##
## **25 인 것은 의리 축과 같은 폭이다** — 둘 중 하나가 다른 하나를 압도하면
## 조건이 사실상 하나가 된다. 유명세 중위가 4 라(§24.40.3) **대부분의 후보에게 1 이 붙고**
## 유명세 100 인 사람에게만 25 가 붙는다.
##
## **실측으로 확인했다** (§24.42.2) — 영입 가능한 쌍이 36.8% → 36.4% 로 거의 안 움직이고,
## **이 손잡이 때문에만 막힌 쌍이 46** 이다. 무명인 사람은 안 비싸지고 유명한 사람만 비싸진다.
const AFFINITY_FAME_PRICE := 25

## 유대 문턱. **협력 한 번(유대 +20)으로는 모자라고 두 번이면 넘는다** —
## 설계 24.12 의 *"유대는 같이 다니면 오른다"* 가 영입에서 값을 하는 자리다.
const BOND_REQUIRED := 30

## 위계관이 이만큼 벌어지면 성향이 안 맞는다.
##
## 축이 -100~+100 이라 120 은 **양쪽 다 뚜렷해야** 넘는 값이다.
## 한쪽만 극단이면 안 걸린다 — 걸리게 하면 자유형이 아무 길드에도 못 간다.
const HIERARCHY_CLASH := 120

## 후보가 영입하는 사람에게 갖는 호감.
var affinity: int

## 둘 사이의 유대.
var bond: int

## 이 후보에게 필요한 호감. **의리 축과 유명세 둘이 민다** (§24.42).
var required_affinity: int

## 위계관의 차이.
var hierarchy_gap: int

## 후보의 유명세. 사유 문장이 「몸값」을 말하려고 든다.
var prospect_fame: int

## 후보의 위계 값. 사유 문장이 극 이름을 쓰려고 든다.
var prospect_hierarchy: int

## 영입하는 사람의 위계 값.
var recruiter_hierarchy: int

## 아예 모르는 사이인가.
var is_stranger: bool


## 관계 그래프에서 판정을 뽑는다.
##
## recruiter 는 **영입하는 쪽 사람**이다. 설계 24.1 이
## *"플레이어는 특별한 노드가 아니다"* 라고 했으므로 인물 하나로 취급한다.
static func of(
	registry: PersonRegistry, graph: RelationGraph, prospect: int, recruiter: int
) -> RecruitStanding:
	var standing := RecruitStanding.new()
	if not registry.has(prospect) or not registry.has(recruiter) or prospect == recruiter:
		standing.is_stranger = true
		return standing

	standing.is_stranger = not graph.knows(prospect, recruiter)
	standing.affinity = graph.affinity(prospect, recruiter)
	standing.bond = graph.bond(prospect, recruiter)
	standing.prospect_hierarchy = registry.trait_of(prospect, NpcAxis.Kind.HIERARCHY)
	standing.recruiter_hierarchy = registry.trait_of(recruiter, NpcAxis.Kind.HIERARCHY)
	standing.hierarchy_gap = absi(standing.prospect_hierarchy - standing.recruiter_hierarchy)
	standing.prospect_fame = registry.fame_of(prospect)
	standing.required_affinity = required_affinity_for(
		registry.trait_of(prospect, NpcAxis.Kind.LOYAL), standing.prospect_fame
	)
	return standing


## 요구 호감. **의리 축과 유명세 둘이 민다.** 도구와 시험이 같은 식을 쓰게 하려고 함수로 둔다.
##
## 의리형은 사람을 보고 오고 실리형은 조건을 보고 온다(§24.13).
## **유명한 사람은 둘 다 아니어도 「당신이 누군데」가 성립한다** (§24.42).
static func required_affinity_for(loyal: int, fame: int = 0) -> int:
	var from_loyal := roundi(float(loyal) / 100.0 * float(AFFINITY_LOYAL_SPREAD))
	var from_fame := roundi(
		float(fame) / float(PersonGenerator.FAME_MAX) * float(AFFINITY_FAME_PRICE)
	)
	return AFFINITY_BASE + from_loyal + from_fame


func can_recruit() -> bool:
	if is_stranger:
		return false
	if bond < BOND_REQUIRED or affinity < required_affinity:
		return false
	return hierarchy_gap <= HIERARCHY_CLASH


## 왜 안 되는가. **화면에 그대로 나간다** (설계 24.17.4).
##
## 막힌 조건을 하나만 낸다 — 셋을 다 늘어놓으면 무엇부터 해야 하는지가 안 읽힌다.
func blocked_reason() -> String:
	if is_stranger:
		return "서로 모르는 사이다 (같이 뛴 적이 없다)"
	if bond < BOND_REQUIRED:
		return "엮인 것이 얕다 (유대 %d / 필요 %d)" % [bond, BOND_REQUIRED]
	if affinity < required_affinity:
		# **유명한 후보에게는 이유를 다르게 말한다.** 같은 「호감이 모자라다」라도
		# 무명인 사람과 유명한 사람은 플레이어가 할 일이 다르다 (§24.17.4).
		if prospect_fame >= PersonGenerator.FAME_KNOWN:
			return (
				"이름값이 있다 (유명세 %d • 호감 %+d / 필요 %+d)" % [prospect_fame, affinity, required_affinity]
			)
		return "나를 그만큼 좋게 보지 않는다 (호감 %+d / 필요 %+d)" % [affinity, required_affinity]
	if hierarchy_gap > HIERARCHY_CLASH:
		return (
			"위계관이 정반대다 (%s 대 %s)"
			% [
				NpcAxis.pole_label(NpcAxis.Kind.HIERARCHY, prospect_hierarchy),
				NpcAxis.pole_label(NpcAxis.Kind.HIERARCHY, recruiter_hierarchy),
			]
		)
	return ""


## 판정을 한 줄로. 개발 도구가 쓴다.
func summary() -> String:
	if can_recruit():
		return "가능 (호감 %+d 유대 %d)" % [affinity, bond]
	return blocked_reason()
