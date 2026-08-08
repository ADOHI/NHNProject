class_name CharAnimProbe
extends RefCounted
## 애니메이션 테스트가 공유하는 계측 도구.
##
## `test_idle_clip.gd`(파형과 접지)와 `test_idle_features.gd`(조절판 계약)가 같은
## 방식으로 재야 두 파일의 결과를 나란히 읽을 수 있다. 그래서 헬퍼를 여기에 모았다.
##
## 파일명에 `test_` 접두사가 없으므로 GUT 이 테스트로 수집하지 않는다.

## 한 바퀴를 훑을 때의 간격. 최고점 찾기가 지연 0.09 초를 가려낼 만큼 촘촘해야 한다.
const SCAN_STEP := 0.005


static func clip() -> CharIdleClip:
	return CharIdleClip.new(CharRig.new())


static func scan_times() -> Array[float]:
	var times: Array[float] = []
	var t := 0.0
	while t < CharIdleClip.LOOP:
		times.append(t)
		t += SCAN_STEP
	return times


## 쉬는 자세로부터의 변위. 절대 좌표가 아니라 이것을 봐야 파형이 읽힌다.
static func offset(anim: CharIdleClip, part: CharPart.Id, t: float, f: AnimFeatures) -> Vector2:
	return anim.sample(t, f).positions[part] - anim.rig.rest_positions[part]


## 파츠가 가장 높이 올라간 시각. 지연의 부호와 크기를 재는 데 쓴다.
static func peak_time(anim: CharIdleClip, part: CharPart.Id, f: AnimFeatures) -> float:
	var best := -INF
	var best_t := 0.0
	for t in scan_times():
		var y := anim.sample(t, f).positions[part].y
		if y > best:
			best = y
			best_t = t
	return best_t


## 한 바퀴에서의 상하 최대 변위.
static func span(anim: CharIdleClip, part: CharPart.Id, f: AnimFeatures) -> float:
	var widest := 0.0
	for t in scan_times():
		widest = maxf(widest, absf(offset(anim, part, t, f).y))
	return widest


## 부호가 바뀐 횟수. **0 은 건너뛴다.**
##
## `CharPose` 는 `Packed*Array` 라 좌표가 float32 다. 사인이 0 을 지나는 순간의
## 미세한 값은 86 px 짜리 좌표에 더하면 그대로 삼켜져 **정확히 0** 이 된다.
## 그것을 부호 변화로 세면 한 번 지날 때 두 번 센다 (실제로 4 를 8 로 셌다).
static func sign_changes(offsets: Array[Vector2], use_x: bool) -> int:
	var changes := 0
	var last := 0.0
	for value in offsets:
		var sign_now := signf(value.x if use_x else value.y)
		if sign_now == 0.0:
			continue
		if last != 0.0 and sign_now != last:
			changes += 1
		last = sign_now
	return changes
