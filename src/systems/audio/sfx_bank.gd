class_name SfxBank
extends RefCounted
## 구운 소리를 들고 있는 곳 (docs/design/29-sound.md §29.5).
##
## `AudioStreamGenerator` 를 안 쓰는 이유가 여기 있다. 웹은 **단일 스레드**라
## 매 프레임 버퍼를 채우다 한 번 굶으면 소리가 뚝뚝 끊긴다.
## 미리 구워 두면 재생 시점 비용이 0 이다.
##
## 노드가 아니다 — 굽는 것과 재생하는 것을 갈라 두면 헤드리스에서 굽기만 검사할 수 있다.

## 잡음 씨까지 바꿔 여러 벌 굽는 사건. **빠르게 반복되는 것만** 여기 넣는다.
##
## 체인은 0.35초 간격으로 5타가 나가고 걸음은 1.2초에 2보다. 같은 배열을
## 그대로 다섯 번 재생하면 기계로 들린다 (§29.6).
## 나머지 사건은 한 벌만 굽고 재생 때 pitch_scale 로만 흔든다 — 그건 공짜다.
const REPEATING: Array = [
	SfxEvent.Kind.HIT_LANDED,
	SfxEvent.Kind.SWING_IMPACT,
	SfxEvent.Kind.HIT_REACTION,
	SfxEvent.Kind.CHAIN_LINK,
	SfxEvent.Kind.FOOT_WALK,
	SfxEvent.Kind.FOOT_RUN,
	SfxEvent.Kind.UI_PIECE_IN,
	SfxEvent.Kind.UI_PIECE_OUT,
]

## 반복 사건 한 개당 굽는 벌 수.
##
## **강도 단 하나에 파일이 셋이라 셋이다.** 5타면 한 벌이 두 번 나오지만,
## 재생 때 pitch_scale 이 ±6 % 로 다시 흔들어 주므로 같은 소리로 안 들린다.
const VARIATION_COUNT := 3

var _cache: Dictionary = {}
var _baked_bytes := 0


## 요청 하나에 해당하는 스트림들. 없으면 그 자리에서 굽는다 (게으른 굽기).
##
## 처음 재생하는 사건은 여기서 한 프레임을 쓴다. 그게 싫으면 미리 `warm()` 한다.
func streams_for(request: SfxRequest, variations: int = 1) -> Array[AudioStreamWAV]:
	var wanted := maxi(variations, 1)
	# 재료가 세 개뿐인데 네 벌을 구우면 한 벌이 중복이다. 있는 만큼만 굽는다.
	var available := SfxLibrary.paths_for(request).size()
	if SfxRender.mode == SfxRender.Source.FILE and available > 0:
		wanted = mini(wanted, available)
	# 벌 수를 열쇠에 넣는다. 안 넣으면 한 벌짜리로 먼저 캐시된 요청이
	# 나중에 네 벌을 달라고 해도 한 벌만 돌려줘, 변주가 조용히 사라진다.
	# 원천(파일/합성)도 넣는다 — 안 넣으면 모드를 바꿔도 옛 소리가 나온다.
	var key := "%s#%d#%d" % [request.bake_key(), wanted, SfxRender.mode]
	if _cache.has(key):
		return _cache[key]

	var made: Array[AudioStreamWAV] = []
	for index in wanted:
		# CC0 재료가 있으면 벌마다 **다른 녹음 파일**이 걸린다. 합성 씨를 흔드는 것보다
		# 훨씬 강한 변주다 — 같은 물건을 다시 때린 것이 아니라 원래 다른 녹음이다.
		var stream := SfxRender.render(request, index).to_stream()
		_baked_bytes += stream.data.size()
		made.append(stream)
	_cache[key] = made
	return made


## 사건 하나를 재생 가능한 스트림으로. 여러 벌이면 그중 하나를 고른다.
func stream_for(event: SfxEvent.Kind, weight: float = -1.0, pick: int = 0) -> AudioStreamWAV:
	var request := SfxCatalog.request_for(event)
	if weight > 0.0 and SfxCatalog.is_weight_driven(event):
		request = request.with_weight(weight)
	var variations := VARIATION_COUNT if REPEATING.has(event) else 1
	var streams := streams_for(request, variations)
	return streams[pick % streams.size()]


## 미리 구워 둔다. 로딩 화면이 있을 때 여기서 값을 치른다.
##
## 굽는 데 걸린 시간(ms)을 돌려준다 — 웹에서 이 값을 그대로 보고할 수 있게.
func warm(events: Array = []) -> float:
	var started := Time.get_ticks_usec()
	var targets := events if not events.is_empty() else SfxEvent.all()
	for event in targets:
		stream_for(event)
	return (Time.get_ticks_usec() - started) / 1000.0


## 구워 둔 스트림 벌 수.
func baked_count() -> int:
	var total := 0
	for streams in _cache.values():
		total += streams.size()
	return total


## 구워 둔 PCM 총 바이트. **이건 내려받는 용량이 아니다** — 실행 중 메모리다.
## 소리 파일을 하나도 안 싣기 때문에 웹 빌드 크기는 0 만큼 늘어난다.
func baked_bytes() -> int:
	return _baked_bytes


func clear() -> void:
	_cache.clear()
	_baked_bytes = 0
