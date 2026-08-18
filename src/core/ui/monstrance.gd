class_name Monstrance
extends RefCounted
## 방사(放射) 기하와 **광선별 시간.** 노드에 의존하지 않는 순수 계산이다.
##
## 컨셉 「현시(顯示)」의 뼈대다 (docs/design/20-ui-kit.md §20.6).
## 화면의 대부분은 금세공된 방사이고 정보는 그 중심의 창 하나에만 있다.
##
## ## 왜 광선이 두 벌인가 — 조형 이유와 기술 이유가 같은 답을 낸다
##
## 세공품의 방사는 **긴 광선과 짧은 광선이 번갈아** 선다. 한 벌만 쓰면 부채가
## 밋밋하고, 두 벌이면 겹이 생긴다.
##
## 그리고 그것이 **텍스처 왜곡 문제의 답이기도 하다.** 금 광선 에셋은 세로 그림
## (320x1024, 가로세로비 0.31)이다. 이걸 리치 1080 짜리 광선 하나에 40px 폭으로
## 늘이면 세로로 열 배 늘어나서 **타출한 점렬이 국수처럼 늘어진다.**
## 폭을 리치에 비례시키지 않고 **벌마다 절대 폭**으로 잡으면, 짧은 벌은 원본
## 비율에 거의 맞고 긴 벌도 세 배 안에서 끝난다.
##
## ## 왜 여기에 시간이 같이 있나
##
## **나전 판이 여기서 죽었다.** 광택을 시간 uniform 에 상수를 곱해 만들었더니
## 여섯 조각이 **전부 같은 방향으로 같이** 움직였고, 그건 움직이는 것으로 보이지
## 않았다 (§20.2). 방사에서 그 실수는 더 크다 — 광선 열댓 개가 한 몸으로 맥동하면
## 그냥 화면이 밝아졌다 어두워지는 것이다.
##
## 그래서 **광선마다 위상이 다르다.** 결정적으로 뽑는다 — `randf()` 를 쓰면 캡처마다
## 화면이 달라져 비교가 안 된다.
##
## ## 해시로 위상을 뽑으면 안 됐다 — 테스트가 잡았다
##
## 처음에 `KitEase.hash01(i * 613 + 71)` 로 위상을 뽑았다. **`hash01` 은 입력의 선형
## 함수**(LCG 한 스텝)라, 보폭에 따라 값들이 촘촘하게 몰릴 수 있다. 보폭 613 에서
## 광선 스물넷의 위상 폭이 **0.027** 이었다 — 사실상 전부 같은 위상이고,
## **나전 판의 결함이 그대로 재현될 상태였다.**
##
## 눈으로는 못 봤을 것이다. 「살아 있어 보이는데」로 넘어갔을 것이고 앞 판이 정확히
## 그래서 틀렸다. 단위 테스트가 폭을 재서 잡았다.
##
## 그래서 위상은 해시가 아니라 **황금비 켜기**로 뽑는다. 임의의 개수에 대해 값이
## 가장 고르게 흩어지는 것이 보장되고 보폭 운에 걸리지 않는다.

## 광선 하나가 금이 다 차는 데 걸리는 시간.
const GILD_RAY: float = 0.16

## 다음 광선이 시작하기까지의 지연. `count` 배가 개시 전체 길이다.
const GILD_STAGGER: float = 0.011

## 상시 광택이 광선 하나를 훑는 주기.
const SHEEN_PERIOD: float = 1.10

## 눌림이 잦아드는 시간.
##
## **0.34 초에 감쇠 9 로 잡았더니 20fps GIF 에서 한 프레임만 보였다** — 첫 프레임에
## 0.74 까지 빨려 들고 다음 프레임(0.05초)에 이미 0.97 이었다. 눌렀는데 아무 일도
## 안 일어난 것처럼 보였다. **모션은 존재하는 것으로 부족하고 표본에 걸려야 한다.**
const PRESS_TIME: float = 0.42

## 짧은 벌의 리치 배율.
const SHORT_RANK: float = 0.40

## 황금비의 소수부. 위상을 이 보폭으로 켜면 개수와 무관하게 고르게 흩어진다.
const PHASE_STEP: float = 0.6180339887498949

## 방사의 중심. 화면 안일 수도 밖일 수도 있다.
var center: Vector2

## 광선 수. 짝수 자리가 긴 벌, 홀수 자리가 짧은 벌이다.
var count: int

## 부채의 시작·끝 각(라디안). Godot 은 y 가 아래로 커지므로 위쪽이 음수 각이다.
var angle_from: float
var angle_to: float

## 중심에서 광선이 시작하는 반지름과 긴 벌의 최대 리치.
var inner: float
var outer: float

## 벌마다의 절대 반폭(px). 리치에 비례시키지 않는 이유는 모듈 주석에 있다.
var half_long: float
var half_short: float


func _init(
	p_center: Vector2,
	p_count: int,
	p_angle_from: float,
	p_angle_to: float,
	p_inner: float,
	p_outer: float,
	p_half_long: float,
	p_half_short: float
) -> void:
	center = p_center
	count = maxi(2, p_count)
	angle_from = p_angle_from
	angle_to = p_angle_to
	inner = p_inner
	outer = p_outer
	half_long = p_half_long
	half_short = p_half_short


## 광선 `i` 가 긴 벌인가.
func is_long(i: int) -> bool:
	return i % 2 == 0


## 광선 `i` 의 중심각. 슬롯의 **가운데**에 앉힌다 — 그래야 부채 양끝이 대칭이다.
func ray_angle(i: int) -> float:
	var slot := (float(i) + 0.5) / float(count)
	return angle_from + (angle_to - angle_from) * slot


## 광선 `i` 의 최대 리치.
##
## 벌마다 다르고, 그 위에 광선마다 0.86~1.00 배로 흔든다. 다 같은 반지름에 두면
## **깨끗한 원호**가 생기는데 그건 회전 원형 HUD 의 실루엣이다(배격 목록).
## 흔들면 바깥 경계가 불규칙해지고 세공품의 실루엣이 된다.
func ray_outer(i: int) -> float:
	# 흔들림은 고른 것이 아니라 **불규칙한** 것이어야 하므로 해시를 쓴다. 다만
	# 넣기 전에 지표를 한 번 섞는다 — 안 섞으면 위상에서 걸린 함정을 여기서도 밟는다.
	var jitter := 0.86 + 0.14 * KitEase.hash01(_scramble(i))
	var rank := 1.0 if is_long(i) else SHORT_RANK
	return outer * rank * jitter


## 광선 `i` 의 반폭.
func ray_half(i: int) -> float:
	return half_long if is_long(i) else half_short


## 개시 — 광선 `i` 에 금이 얼마나 찼나. 0 이면 아직 심연이다.
##
## 중심에서 밖으로 **순서대로** 찍혀 나간다. 전부 동시에 나타나면 그냥
## 화면이 켜지는 것이고, 순서가 있으면 **찍히는 동작**이 된다.
func gild_progress(i: int, elapsed: float) -> float:
	var started := elapsed - float(i) * GILD_STAGGER
	if started <= 0.0:
		return 0.0
	return KitEase.out_expo(started / GILD_RAY, 7.0)


## 개시 전체가 끝나는 데 걸리는 시간. 캡처 대본이 이걸 보고 길이를 잡는다.
func gild_span() -> float:
	return float(count) * GILD_STAGGER + GILD_RAY


## 상시 광택이 광선 `i` 의 어디를 지나고 있나. 0 이 뿌리, 1 이 끝.
##
## **위상이 광선마다 다르다.** 이것이 이 컨셉의 상시 모션 전부다.
func sheen_at(i: int, clock: float) -> float:
	return fposmod(clock / SHEEN_PERIOD + float(i) * PHASE_STEP, 1.0)


## 지표의 비트를 섞는다. 해시에 지표를 그대로 넣으면 선형성이 그대로 남는다.
static func _scramble(n: int) -> int:
	var x := (n * 0x27D4EB2D + 0x165667B1) & 0x7FFFFFFF
	x ^= x >> 13
	return (x * 0x85EBCA6B) & 0x7FFFFFFF


## 눌림 — 리치에 곱할 배율. **방사가 중심으로 역류한다.**
##
## 확 줄고 되튀며 1 로 돌아온다. 지수 접근으로는 되튈 방법이 없어서
## 경과 시간의 함수로 쓴다 (`KitEase` 모듈 주석).
func press_reach(since_press: float) -> float:
	if since_press < 0.0 or since_press >= PRESS_TIME:
		return 1.0
	var u := since_press / PRESS_TIME
	# 0.05초 간격 표본에서 0.70 → 0.83 → 0.95 → 1.03 → 1.05 로 잡힌다.
	# 네 프레임에 걸쳐 빨려 들었다 되튀므로 GIF 에서 동작으로 읽힌다.
	return 1.0 - 0.30 * exp(-u * 3.4) * cos(u * 5.2)


## 광선 `i` 를 그릴 사각형(광선 자기 좌표계). 회전은 부르는 쪽이 건다.
##
## 광선 텍스처는 **뿌리가 아래, 끝이 위**인 세로 그림이라 y 가 음수 쪽으로 뻗는다.
func ray_rect(i: int, reach_scale: float) -> Rect2:
	var reach := maxf(inner + 1.0, ray_outer(i) * reach_scale)
	var half := ray_half(i)
	return Rect2(Vector2(-half, -reach), Vector2(half * 2.0, reach - inner))


## 광선 `i` 의 회전각. 텍스처가 위를 보고 있으므로 90도를 더한다.
func ray_rotation(i: int) -> float:
	return ray_angle(i) + PI * 0.5
