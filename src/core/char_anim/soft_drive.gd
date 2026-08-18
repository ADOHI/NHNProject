class_name SoftDrive
extends RefCounted
## 클립이 어떤 점을 **어떻게 흔드는가**. 한 바퀴를 표본해 하모닉으로 적어 둔다.
##
## `docs/design/31-soft-body.md` §31.1.3.
##
## ## 클립에게 안 묻는다 — **재서 뽑는다**
##
## 응답을 구하려면 구동의 하모닉이 필요하다. 클립에게 `drive_harmonics()` 를 물으면
## 클립 아홉을 전부 고쳐야 하고, 무엇보다 **같은 값이 두 곳에 적힌다** — 이 저장소에서
## 네 번 난 그 모양이다 (§25.13.1).
##
## 그래서 **한 바퀴를 표본해 이산 푸리에로 뽑는다.** 클립이 시각의 순수 함수이고
## 주기적이라 그냥 된다 — §25.3 이 여기서 또 한 번 값을 한다.
##
## > 그리고 이 길은 **자가 자기를 검사하지 않는다** (§25.13.2).
## > 이 파일은 `CharIdleClip` 의 상수를 **한 번도 안 읽는데**, 뽑아 보면
## > `호흡 2 회`와 `무게이동 1 회`가 그 진폭으로 나온다. 그것이 테스트다.
##
## ## 무엇을 표본하나 — **피벗이 아니라 앵커 그 점이다**
##
## `core_transform(part) * local_point` 를 재므로 **회전과 배율까지 들어온다.**
## 고개를 갸웃하면 정수리가 실제로 움직이고, 숨을 쉬면 가슴이 실제로 올라간다.
## 피벗만 보면 그 둘이 통째로 사라진다.
##
## ## 언제 도나
##
## **셋업 때 한 번이다.** 클립이나 앵커가 바뀔 때만 다시 뽑고, 프레임마다는
## `response()` 의 사인 몇 개만 돈다.

## 한 바퀴당 몇 회까지 보나. 위쪽은 진폭이 작고 표본 격자가 못 본다.
const HARMONICS := 6

## 한 바퀴를 몇 점으로 재나. `HARMONICS` 의 두 배를 넘어야 한다(나이퀴스트).
##
## **64 는 여유다.** 셋업 때 한 번 도는 값이라 아낄 이유가 없고, 모자라면
## 높은 성분이 낮은 성분으로 접혀 들어와 **조용히 틀린 진폭**이 나온다.
const SAMPLES := 64

## 한 바퀴의 길이(초).
var loop_seconds := 1.0

## 하모닉 번호 = **한 바퀴당 회수.** 정수다 — 그래서 이음매가 맞는다 (§25.3.2).
var cycles: PackedInt32Array = PackedInt32Array()

## `cos` 성분의 진폭 (축마다).
var cos_amp: PackedVector2Array = PackedVector2Array()

## `sin` 성분의 진폭 (축마다).
var sin_amp: PackedVector2Array = PackedVector2Array()

## 한 바퀴 평균 자리. **응답에는 안 들어간다** — 상수는 흔들리지 않는다.
var mean := Vector2.ZERO


## 아무것도 안 흔드는 구동. 루프가 아닌 클립이 받는 것이다 (§31.1.4).
static func still() -> SoftDrive:
	return SoftDrive.new()


## **클립이 그 점을 어떻게 흔드는지 재서 하모닉으로 적는다.**
##
## `local_point` 는 파츠 지역 좌표(`+y` 위)다. 앵커의 중심을 그대로 넣는다.
##
## **루프가 아닌 클립은 안 받는다.** 주기 분해가 성립하지 않는다 — 그런 클립은
## 충격 응답으로만 흔들린다 (§31.1.4).
static func from_clip(
	clip: CharClip, part: CharPart.Id, local_point: Vector2, features: AnimFeatures
) -> SoftDrive:
	var drive := SoftDrive.new()
	if clip == null or not clip.is_looping():
		return drive
	drive.loop_seconds = maxf(clip.loop_seconds(), 0.001)
	var track := PackedVector2Array()
	track.resize(SAMPLES)
	for n in SAMPLES:
		var at := drive.loop_seconds * float(n) / float(SAMPLES)
		track[n] = clip.sample(at, features).core_transform(part) * local_point
	drive._analyse(track)
	return drive


## 표본에서 하모닉을 뽑는다. **평범한 이산 푸리에다** — 축 둘을 따로 센다.
func _analyse(track: PackedVector2Array) -> void:
	var count := track.size()
	if count == 0:
		return
	var sum := Vector2.ZERO
	for point in track:
		sum += point
	mean = sum / float(count)
	cycles = PackedInt32Array()
	cos_amp = PackedVector2Array()
	sin_amp = PackedVector2Array()
	for k in range(1, HARMONICS + 1):
		if k * 2 > count:
			break
		var a := Vector2.ZERO
		var b := Vector2.ZERO
		for n in count:
			var angle := TAU * float(k) * float(n) / float(count)
			a += (track[n] - mean) * cos(angle)
			b += (track[n] - mean) * sin(angle)
		cycles.append(k)
		cos_amp.append(a * (2.0 / float(count)))
		sin_amp.append(b * (2.0 / float(count)))


## 이 구동이 낸 **몸의 움직임** 자체. 하모닉이 원래 신호를 되짚는지 재는 데 쓴다.
func drive_at(t: float) -> Vector2:
	var out := mean
	for k in cycles.size():
		var w := TAU * float(cycles[k]) / loop_seconds
		out += cos_amp[k] * cos(w * t) + sin_amp[k] * sin(w * t)
	return out


## **살이 몸에 대해 얼마나 어긋나 있나.** 정상상태 응답이다.
##
## 하모닉마다 진폭에 `gain` 을 곱하고 위상을 `phase_lag` 만큼 미는 것이 전부다.
## **주파수가 안 바뀌므로** `t = 0` 과 `t = 한 바퀴` 가 정확히 같다 (§25.3.2).
func response(body: SoftBody, t: float) -> Vector2:
	var out := Vector2.ZERO
	for k in cycles.size():
		var drive_hz := float(cycles[k]) / loop_seconds
		var g := body.gain(drive_hz)
		if g <= 0.0:
			continue
		var phase := TAU * drive_hz * t - body.phase_lag(drive_hz)
		out += (cos_amp[k] * cos(phase) + sin_amp[k] * sin(phase)) * g
	return out


## 하모닉이 하나도 없나. 루프가 아닌 클립이 이렇다.
func is_still() -> bool:
	return cycles.is_empty()
