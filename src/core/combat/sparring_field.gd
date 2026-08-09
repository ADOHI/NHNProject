class_name SparringField
extends RefCounted
## 대련장의 **자리**. 대원이 어디 있고 적들이 어디 있는가.
##
## `docs/design/28-combat.md` §28.20.27 · §28.20.34.
##
## ## 왜 거리가 필요한가
##
## 사용자가 확정했다: *"무기 액션할때 각 무기 움직임이 애니메이션 말고 실제 캐릭터를
## 얼마나 움직일지도 계산되어야 해. 내리치기가 전진 공격으로 나간다던지 하는것 말이야"*
##
## 그러려면 **둘 다 위치를 가져야 한다.** 값은 `WeaponMotion` 이 낸다 (애니 레인 실측).
##
## **전진은 무기 길이의 역함수다** — `전진 = 목표 간격 - (팔 + 무기 길이)`.
## 짧은 무기가 더 파고든다. 다만 실측해 보니 **큰 무기는 전진도 느렸다** (§28.20.30).
##
## ## 적은 **목록**이다
##
## 하나여도 목록으로 든다. §28.20.33 이 「적이 여럿이면」을 물음으로 남겼는데,
## 하나를 특별 취급해 두면 여럿이 될 때 판정하는 쪽이 두 갈래로 갈린다.
##
## ## 시간은 여기 없다
##
## 이 클래스는 **자리만** 안다. 눈금도 다음 타 시각도 `SparringBout` 의 것이다.
## 그래서 판을 다시 쏴도 여기 있는 것은 안 지워진다.
##
## ## 「전진 뒤 제자리로 돌아오나」는 미정이다
##
## 사용자가 정한다. **남으면 5타 체인이 다섯 번 밀고 들어간다.**
## 그래서 규칙을 고르지 않고 둘 다 되게 둔다.

enum AdvanceMode {
	RETURN,  ## 휘두른 뒤 제자리로 돌아온다
	STAY,  ## 나간 자리에 남는다 — 5타 체인이 다섯 번 밀고 들어간다
}

## **리치 안에 둘이 있으면 누구를 때리나** (§28.20.33 물음 ②).
##
## **처음에는 작은 물음으로 적어 뒀는데 §28.20.36 에서 뒤집혔다** —
## 전원이 가장 가까운 적만 때리면 뒷줄이 영영 안 맞아서 **스쿼드를 키워도 못 이긴다.**
## 그래서 여기 고르는 것이 「누구를」이 아니라 **물량전이 성립하느냐**다.
##
## **넷 다 만들어 두고 값은 안 박았다.** 기본값은 `NEAREST` — 지금까지의 동작 그대로다.
## 어느 것이 대각선을 뒤집는지는 `tools/survey_target_rules.gd` 가 낸다.
##
## 앞의 셋은 **퍼뜨리는** 쪽이고 `FINISH_OFF` 는 **모으는** 쪽이다.
## 퍼뜨리는 게 항상 옳은지는 모른다 — **먼저 눕히면 그만큼 덜 맞기 때문이다.**
enum TargetChoice {
	NEAREST,  ## 가장 가까운 것 (지금)
	BY_NUMBER,  ## 번호로 나눈다 — 대원 i 는 적 i%N. 제일 단순하고 고르게 퍼진다
	LEAST_TARGETED,  ## 안 맞은 놈부터 — 아무도 안 때리는 적이 있으면 그리로
	FINISH_OFF,  ## 거의 눕은 놈을 마저 눕힌다 — 위 셋과 반대 방향이다
	LEADER_FIRST,  ## **우두머리부터** — 사람 무리는 그 하나로 끝난다 (§28.10 · §28.20.44)
}

## **우두머리를 어떻게 아나** (§28.20.47).
##
## §28.20.44 가 *"노리지 않으면 우두머리 조건은 전원 조건과 구별되지 않는다"* 로 끝났다.
## 그러면 **노릴 수 있느냐가 먼저**고, 그 앞에 **알 수 있느냐**가 있다.
## **모르면 못 노린다.**
##
## **정하지 않는다.** 셋을 다 만들어 두고 `tools/survey_leader_targeting.gd` 가 잰다.
enum LeaderKnowledge {
	VISIBLE,  ## 보인다 — 처음부터 안다
	ON_HIT,  ## 때려 봐야 안다 — 한 대라도 맞혀야 드러난다
	HIDDEN,  ## 아예 모른다 — 노릴 수가 없다
}

## **미정이다.** 애니 레인이 둘 다 만들어 사용자에게 보냈고 사용자가 정한다.
##
## 그래서 **둘 다 되게 해 두고 값은 박지 않는다.** 확인 화면에서 T 로 바꿔 가며
## 만져 볼 수 있고, 측정 도구는 두 경우를 다 잰다.
var advance_mode: AdvanceMode = AdvanceMode.RETURN

## **미정이다** (§28.20.34 물음 ② · §28.20.37).
##
## 넷을 다 만들어 뒀고 **기본값은 지금까지의 동작**이다. 고르는 것은 사용자다.
var target_choice: TargetChoice = TargetChoice.NEAREST

## **미정이다** (§28.20.47). 기본값은 **보인다** — 지금까지 잰 표가 그 판이다.
var leader_knowledge: LeaderKnowledge = LeaderKnowledge.VISIBLE

## **쓰러진 적이 판에서 빠지나** (§28.20.52).
##
## §28.10 이 확정했다 — *"몬스터는 죽고 사람은 제압이야."* 둘 다 **그 판에서는 빠진다.**
## 그런데 **대련장은 지금까지 아무도 안 치웠다** — 누워도 계속 때리고 계속 맞는다.
##
## **§28.20.36~49 의 표가 전부 「아무도 안 빠진다」 위에 서 있다.**
## 적이 여섯까지일 때는 그 차이가 작았지만 **물량전에서는 그것이 전부**다 —
## 앞줄이 안 비면 뒷줄과 싸울 일이 영영 없다.
##
## **기본값은 `false` — 지금까지의 동작 그대로다.** 옛 표를 조용히 바꾸지 않는다.
var downed_leave: bool = false

## **적이 다가오는 속력** (초당 픽셀, §28.20.53).
##
## §28.20.52 가 물량전 상한을 **여섯**으로 재고 그 까닭을 「한 번에 몇이 닿나」로 짚었다.
## 그리고 그 절이 상한을 옮길 후보 넷 중 **이것이 제일 자연스럽다**고 적었다 —
## 지금 적은 제자리에서만 때린다. **뒷줄이 빈 자리로 들어오면 여섯이 계속 갈린다.**
##
## **기본값은 0 — 지금까지의 동작 그대로다.** 옛 표를 조용히 바꾸지 않는다.
##
## > 이것은 §28.4 의 RTS 자동 이동이 할 일의 **아주 거친 흉내**다.
## > 여기서 정하는 것이 아니라 **상한이 얼마나 움직이는지만** 본다.
var approach_speed: float = 0.0

## 1픽셀 = 1단위. 화면 좌표와 같은 축을 쓴다 (오른쪽이 +).
var attacker_x: float = 0.0

## 켜 하나가 얼마나 뒤인가 (§28.20.38).
##
## **수를 박지 않고 `WeaponMotion` 에서 뽑는다.** 이 값이 뜻을 가지는 것은
## 리치와의 관계에서뿐이라 — 작은 무기는 못 닿고 큰 무기는 닿아야 한다 —
## 애니 레인이 리치를 옮기면 **이것도 같이 옮겨져야** 한다 (§28.20.50).
var rank_depth: float = WeaponMotion.splitting_rank_depth()

var _enemies: Array[SparringEnemy] = []


func _init(p_attacker_x: float = 0.0, p_target_x: float = 240.0) -> void:
	attacker_x = p_attacker_x
	_enemies = [SparringEnemy.new(p_target_x)]


# ---------------------------------------------------------------- 누가 서 있나


func enemy_count() -> int:
	return _enemies.size()


## 그 번호의 적. 범위를 벗어나면 `null`.
func enemy_at(index: int) -> SparringEnemy:
	if index < 0 or index >= _enemies.size():
		return null
	return _enemies[index]


func enemies() -> Array[SparringEnemy]:
	return _enemies


func add_enemy(x: float, weapon: BackpackItem = null, rank: int = 0) -> SparringEnemy:
	var enemy := SparringEnemy.new(x, weapon, rank)
	_enemies.append(enemy)
	return enemy


func clear_enemies() -> void:
	_enemies.clear()


# ---------------------------------------------------------------- 거리


## 그 적까지의 거리. 항상 0 이상이다.
func gap_to(index: int) -> float:
	var enemy := enemy_at(index)
	if enemy == null:
		return INF
	return absf(enemy.x - attacker_x)


## 고른 적까지의 거리. 적이 없으면 `INF`.
func gap() -> float:
	return gap_to(target_index())


## **거리로 고른 적.** 없으면 -1.
##
## 이것은 **자리 계산용**이다 — 바라보는 방향과 전진이 어디서 멈추는가.
## **누구를 때리는가는 `target_choice` 가 정하고 그 판단은 `SparringBout` 이 한다** —
## 「안 맞은 놈부터」나 「거의 눕은 놈부터」는 눈금을 알아야 하고, 눈금은 판의 것이다.
func target_index() -> int:
	if _enemies.is_empty():
		return -1
	var best := 0
	var best_gap := gap_to(0)
	for index in range(1, _enemies.size()):
		var candidate := gap_to(index)
		if candidate < best_gap:
			best_gap = candidate
			best = index
	return best


## 고른 적의 자리. 적이 없으면 대원의 자리를 돌려준다 (그리는 쪽이 안 터지게).
func target_x() -> float:
	var enemy := enemy_at(target_index())
	return enemy.x if enemy != null else attacker_x


## 대원이 적을 바라보는 방향 (+1 오른쪽 / -1 왼쪽).
func facing() -> float:
	return 1.0 if target_x() >= attacker_x else -1.0


## **이 리치 안에 드는 적들.** 가까운 것부터, 최대 `limit` 명.
##
## §28.20.34 물음 ①. **닿는 범위가 곧 걸치는 범위다** — 리치가 무기마다 다르므로
## 걸침에 쓸 새 자료가 필요 없다. 몇 명까지 걸치는지만 `limit` 로 받는다.
##
## **등 뒤는 안 맞는다.** 바라보는 쪽의 적만 고른다. 그렇게 안 하면 지나쳐 온 적이
## 계속 맞아서 전진이 곧 후방 공격이 된다.
##
## 순서가 `target_index()` 와 같은 규칙(가까운 것부터)인 것이 중요하다.
## 「누구를」과 「몇에게」가 서로 다른 규칙이면 첫째로 맞는 적이 고른 적이 아니게 된다.
## 순서는 **거리순 그대로**다 — 규칙에 따른 재정렬은 `SparringBout` 이 한다 (§28.20.37).
## 「안 맞은 놈부터」와 「거의 눕은 놈부터」는 눈금을 알아야 하고 눈금은 판의 것이다.
func targets_within(reach: float, limit: int = 1) -> PackedInt32Array:
	var found := PackedInt32Array()
	if limit <= 0 or _enemies.is_empty():
		return found
	var ahead := facing()
	var ordered: Array[Vector2] = []
	for index in _enemies.size():
		var offset := _enemies[index].x - attacker_x
		if offset * ahead < 0.0:
			continue
		var distance := absf(offset)
		if distance > reach:
			continue
		ordered.append(Vector2(distance, float(index)))
	# **같은 켜는 거리가 같다.** 그때 순서가 판마다 달라지면 안 되므로 번호로 가른다 —
	# `sort_custom` 은 안정 정렬이 아니다.
	ordered.sort_custom(
		func(a: Vector2, b: Vector2) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y
	)
	for entry in ordered:
		if found.size() >= limit:
			break
		found.append(int(entry.y))
	return found


# ---------------------------------------------------------------- 움직임


## 대원을 그만큼 앞으로 민다. **고른 적을 지나치지는 않는다.**
##
## 지나치게 두면 전진이 쌓였을 때 대원이 적 뒤로 빠져 방향이 뒤집힌다.
##
## ## 다른 적에 막히나 — **미정이다** (§28.20.34 물음 ③)
##
## **전투가 혼자 정할 물음이 아니다.** `docs/design/11-decisions.md` 가 2026-08-07 에
## **「유닛이 다른 유닛을 밀 수 없다」**를 확정했다
## (`src/proto/unit_move/` — 밀치기가 지터의 원인이었다).
##
## 막으면 §28.20.30 의 **파고들기가 죽는다** — 앞의 적이 뒤의 적을 지켜 준다.
## 지나가게 두면 몸이 겹친다. 미는 것은 확정을 뒤집는 것이다.
##
## **여기서는 아무에게도 안 막힌다.** 자리만 적어 둔다.
func advance(distance: float) -> void:
	if distance <= 0.0:
		return
	var goal := target_x()
	var moved := attacker_x + facing() * distance
	if facing() > 0.0:
		attacker_x = minf(moved, goal)
	else:
		attacker_x = maxf(moved, goal)


## 한 번 휘두른 결과로 몸이 움직인다.
##
## **남을지 돌아올지는 미정이라 여기서 갈린다.** 규칙을 고르는 것이 아니라
## 고를 수 있게 두는 것이다.
func swing_advance(distance: float) -> void:
	if advance_mode == AdvanceMode.STAY:
		advance(distance)


## **적이 줄을 메우며 다가온다** (§28.20.53).
##
## 맨 앞은 `WeaponMotion.opening_gap_px()` 까지 오고, 뒤는 앞사람에서 `rank_depth` 만큼
## 떨어진 자리까지 온다. **줄이 짧아지는 것이 아니라 앞으로 밀리는 것이다.**
##
## `out` 에 든 적은 **자리를 비운다** — 쓰러져 빠진 것이 길을 안 막는다.
## 시체가 길을 막느냐는 §28.20.34 물음 ③(밀치기)과 같은 자리라 여기서 정하지 않는다.
func close_in(seconds: float, out: PackedInt32Array = PackedInt32Array()) -> void:
	if approach_speed <= 0.0 or seconds <= 0.0:
		return

	# **줄 순서를 다시 세우지 않는다.** 세워 둔 순서가 곧 거리 순서이고
	# 앞으로만 오므로 그 순서가 안 뒤집힌다. 매번 정렬하면 사건마다 N log N 이 되어
	# 적 100 명짜리 판이 못 끝난다 — 실제로 한 번 못 끝냈다.
	var step := approach_speed * seconds
	var ahead := facing()
	var want := WeaponMotion.opening_gap_px()
	for index in _enemies.size():
		if out.has(index):
			continue
		var enemy := _enemies[index]
		var gap := absf(enemy.x - attacker_x)
		if gap > want:
			var goal := attacker_x + ahead * want
			var moved := enemy.x - ahead * step
			enemy.x = maxf(moved, goal) if ahead > 0.0 else minf(moved, goal)
			gap = absf(enemy.x - attacker_x)
		want = gap + rank_depth


## 적 하나짜리로 되돌린다.
func reset(p_attacker_x: float, p_target_x: float) -> void:
	attacker_x = p_attacker_x
	_enemies = [SparringEnemy.new(p_target_x)]


## 적 여럿으로 세운다. **무기는 아직 안 쥐여 준다** — 판이 쥐여 준다.
func reset_with(p_attacker_x: float, xs: PackedFloat32Array) -> void:
	attacker_x = p_attacker_x
	_enemies.clear()
	for x in xs:
		_enemies.append(SparringEnemy.new(x))


## **적을 켜로 세운다** (§28.20.38). `counts[r]` 이 r 번째 켜에 선 인원이다.
##
## 같은 켜는 **거리가 같다** — 가로로 나란히 선 것이라 이 판에서는 구분할 것이 없다.
## 뒤 켜는 `rank_depth` 만큼씩 물러선다.
func stand_in_ranks(p_attacker_x: float, front_gap: float, counts: Array[int]) -> void:
	attacker_x = p_attacker_x
	_enemies.clear()
	for rank in counts.size():
		var at := front_gap + float(rank) * rank_depth
		for _slot in counts[rank]:
			_enemies.append(SparringEnemy.new(at, null, rank))
