class_name HoloSpark
extends RefCounted
## **사건에 붙는 것들.** 순수 계산이다.
##
## > **화려함은 사건의 성질이다.** 정지에서 화려하면 시끄럽다.
##
## 이 킷이 여덟 판에 찾은 그 문장을 실제 이펙트로 옮긴다(§20.20). 여기 있는 것은
## 대부분 **무엇이 일어나는 동안에만 존재**한다 — 멈춰 있으면 값이 0 이다.
## 상시로 남는 둘(선 신호 · 티끌)은 **한 곳에만** 붙는다.
##
## | 이펙트 | 언제 | 어디 |
## | --- | --- | --- |
## | 조각 모임 | 창이 열리는 **동안** | 그 창 하나 |
## | 선 신호 | 창이 펴져 있는 동안 | **한 번에 선 하나** |
## | 링 궤적 | 링이 **도는 동안** | 도는 방향의 **뒤쪽** |
## | 티끌 | 늘 | **가운데 인물 하나** |
## | 파문 · 섬광 | **누른 순간** | 누른 자리 |

## 화려함 세기 넷. **「없음」이 진짜로 없어야 나머지 셋이 비교가 된다.**
enum Level { NONE, SOFT, STRONG, TOO_MUCH }

## 이펙트 종류. **`COUNTS` 의 줄 번호이기도 하다.**
enum Effect { SHARD, SIGNAL, MOTE, GHOST, RING }

const LEVEL_NAMES := ["없음", "약", "세", "과"]

## 세기마다 이펙트가 몇 개인가. **행이 곧 이펙트고 열이 곧 세기다.**
##
## 새 이펙트를 `Effect` 에 넣고 여기 줄을 안 더하면 `test_every_effect_has_a_row` 가
## 빨개진다 — **「없음」 칸을 빠뜨릴 수 없게 만든 것**이 이 표의 목적이다.
const COUNTS := [
	[0, 3, 7, 14],  # 조각 — 창이 열릴 때 모여 붙는다
	[0, 1, 3, 3],  # 선 신호 — 개수는 안 늘고 「과」에서 선이 늘어난다
	[0, 5, 9, 18],  # 티끌 — 가운데 인물 둘레
	[0, 1, 2, 4],  # 링 잔상 — 도는 방향 뒤쪽
	[0, 1, 1, 3],  # 파문 고리
]

## 재료 셰이더의 세기(§20.19). **「없음」은 셰이더를 아예 안 건다.**
const STUFF_AT := [0.0, 0.45, 1.0, 2.0]

## 창이 열릴 때 조각이 얼마나 멀리서 오나(창 높이의 배수).
const SHARD_REACH: float = 1.6

## 파문이 다 퍼지는 데 걸리는 시간(초).
const RIPPLE_TIME: float = 0.55

## 신호가 한 선에 머무는 시간(초). **한 번에 한 선**이라 이 값이 훑는 속도다.
const DWELL: float = 0.85


static func level_name(level: int) -> String:
	return LEVEL_NAMES[clampi(level, 0, LEVEL_NAMES.size() - 1)]


static func levels() -> int:
	return LEVEL_NAMES.size()


## 이 세기에서 이 이펙트가 몇 개인가. `what` 은 `Effect` 의 값이다.
static func many(what: int, level: int) -> int:
	return COUNTS[int(what)][clampi(level, 0, LEVEL_NAMES.size() - 1)]


## 재료 셰이더 세기. 0 이면 셰이더를 안 건다.
static func stuff_strength(level: int) -> float:
	return STUFF_AT[clampi(level, 0, LEVEL_NAMES.size() - 1)]


## **골고루 뿌리나.** 「과」 하나만 참이다.
##
## > **「과」가 시끄러운 원인은 양이 아니라 골고루다.**
##
## 티끌이 여섯 인물 전부에게 붙고 신호가 다섯 선 전부에 흐르고 잔상이 전부에게 남는다.
## 개수를 키운 것이 아니라 **「한 곳에만」을 버린 것**이다.
static func spreads(level: int) -> bool:
	return level >= Level.TOO_MUCH


## 지금 신호가 흐르는 선. **한 번에 하나고 차례로 옮겨 간다.**
##
## 기기가 한 채널씩 훑고 있는 것으로 읽힌다 — 다 채워져 있으면 도감이고
## 하나씩 훑으면 스캔 중인 기기다(§20.17.4 의 「모르는 칸은 ?」와 같은 종류).
static func live_line(clock: float, lines: int) -> int:
	if lines <= 0:
		return 0
	return int(floorf(clock / DWELL)) % lines


## 창이 열릴 때 조각 하나가 어디 있나. `u` 0 이면 흩어져 있고 1 이면 제자리다.
##
## **조각은 창의 테두리에서 나온다.** 아무 데서나 날아오면 이 창과 상관없는 것이
## 붙는 것으로 보인다 — 조각의 출발점이 도착점의 **바깥 방향 연장**이다.
static func shard(index: int, box: Rect2, u: float) -> Rect2:
	var turn := fposmod(0.13 + float(index) * 0.6180339887, 1.0)
	var lands := Vector2(
		box.position.x + box.size.x * turn, box.position.y + box.size.y * fposmod(turn * 2.7, 1.0)
	)
	var away := (lands - box.get_center()).normalized()
	if away.length() < 0.01:
		away = Vector2.RIGHT
	var far := lands + away * box.size.y * SHARD_REACH * (0.5 + turn)
	var eased := KitEase.out_expo(clampf(u, 0.0, 1.0), 5.0)
	var wide := 3.0 + turn * 9.0
	return Rect2(far.lerp(lands, eased) - Vector2(wide, 1.5) * 0.5, Vector2(wide, 3.0))


## 조각의 진하기. **다 붙고 나면 사라진다** — 남아 있으면 장식이 된다.
static func shard_alpha(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	return sin(t * PI) * 0.9


## 연결선을 따라 흐르는 신호 점이 선의 어디쯤에 있나 0..1.
##
## 점끼리 고르게 벌어져 있고 **몸에서 창 쪽으로** 간다 — 반대로 가면 창이 몸에게
## 무언가 보내는 것이 되어 뜻이 뒤집힌다.
static func signal_at(index: int, count: int, clock: float, speed := 0.42) -> float:
	return fposmod(clock * speed + float(index) / float(maxi(count, 1)), 1.0)


## 신호 점의 진하기. **선의 양 끝에서 옅다** — 끝에서 불쑥 나타나면 튄다.
static func signal_alpha(along: float) -> float:
	return sin(clampf(along, 0.0, 1.0) * PI)


## 링이 돌 때 남는 자국의 진하기. **멈춰 있으면 0 이다.**
##
## 자국은 **돌던 방향의 뒤쪽**에만 남는다. 앞뒤로 다 남으면 잔상이 아니라 후광이다.
## 그래서 한 순간에 자국이 붙는 인물은 **가운데를 막 지나간 하나뿐**이다.
static func wake(index: int, total: int, picked: float, speed: float) -> float:
	if absf(speed) < 0.01:
		return 0.0
	# 돌던 방향으로 얼마나 앞인가. **음수면 이미 지나간 것 = 뒤쪽이다.**
	var ahead := fposmod((float(index) - picked) * signf(speed), float(maxi(total, 1)))
	if ahead > float(total) * 0.5:
		ahead -= float(total)
	if ahead > 0.0:
		return 0.0
	# 바로 뒤 하나만 남는다. 한 칸을 넘게 지나갔으면 이미 꺼진 것이다.
	return clampf(1.0 + ahead, 0.0, 1.0) * clampf(absf(speed), 0.0, 1.0) * 0.55


## 잔상 하나가 **몇 칸 뒤**의 모습인가. 겹이 깊을수록 더 옛날이다.
##
## **바짝 붙어 있어야 번짐으로 읽힌다.** 벌어지면 사람이 여럿 서 있는 것이 된다.
static func ghost_back(depth: int) -> float:
	return (float(depth) + 1.0) * 0.05


## 누른 자리에서 퍼지는 파문의 반지름(px). 다 퍼지면 `spread` 다.
##
## 고리가 여럿이면 뒤 고리가 늦게 출발한다 — 같이 나가면 두꺼운 고리 하나로 보인다.
static func ripple(u: float, spread: float, ring := 0) -> float:
	var t := clampf(u - float(ring) * 0.14, 0.0, 1.0)
	return KitEase.out_expo(t, 5.0) * spread


## 파문의 진하기. **한 번 지나가고 끝난다.**
static func ripple_alpha(u: float, ring := 0) -> float:
	var t := clampf(u - float(ring) * 0.14, 0.0, 1.0)
	return (1.0 - t) * (1.0 - t) * 0.85


## 누른 순간의 섬광. **파문보다 훨씬 짧다** — 길면 화면이 밝아진 것으로 읽힌다.
static func flare(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	var quick := clampf(t * 4.5, 0.0, 1.0)
	return (1.0 - quick) * (1.0 - quick) * (1.0 - quick)


## 가운데 인물 둘레에서 도는 티끌 하나의 자리. **여기가 터지는 자리다.**
##
## 나머지는 조용하다 — 티끌을 모든 인물에게 주면 밀도 대비가 죽고 §20.9.4 의
## 「무슨 수학 같음」이 그대로 돌아온다. 「과」에서만 그것을 일부러 한다.
static func mote(index: int, count: int, around: Rect2, clock: float) -> Vector2:
	var turn := fposmod(0.29 + float(index) * 0.6180339887, 1.0)
	var angle := clock * (0.35 + turn * 0.5) + TAU * float(index) / float(maxi(count, 1))
	var radius := around.size.x * (0.52 + 0.26 * turn)
	return Vector2(
		around.get_center().x + cos(angle) * radius,
		around.end.y - around.size.y * (0.06 + 0.5 * turn) + sin(angle) * radius * 0.16
	)


## 티끌 하나의 진하기. **깜빡인다** — 다 같은 밝기면 점을 뿌린 것이 된다.
static func mote_alpha(index: int, clock: float) -> float:
	var turn := fposmod(0.71 + float(index) * 0.6180339887, 1.0)
	return 0.22 + 0.5 * (0.5 + 0.5 * sin(clock * (1.1 + turn * 1.7) + turn * TAU))
