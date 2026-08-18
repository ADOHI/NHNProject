class_name SfxClip
extends RefCounted
## 샘플 배열 하나와 그 샘플레이트 (docs/design/29-sound.md §29.5).
##
## 레이트를 같이 들고 다니는 이유가 있다. **천 소리만 44100 이고 나머지는 22050 이다.**
## 실측해 보니 대부분의 재질은 11 kHz 위에 에너지가 1 % 도 없는데 천만 9.65 % 였다 —
## 천 소리의 정체가 바로 그 고역이라 거기만 두 배를 준다 (§29.7.9).
##
## `AudioStreamWAV` 가 스트림마다 `mix_rate` 를 들고 있으므로 섞어 써도 공짜다.

var samples: PackedFloat32Array
var rate: int


func _init(p_samples: PackedFloat32Array = PackedFloat32Array(), p_rate: int = 22050) -> void:
	samples = p_samples
	rate = p_rate


func seconds() -> float:
	if rate <= 0:
		return 0.0
	return float(samples.size()) / rate


func is_empty() -> bool:
	return samples.is_empty()


## 재생 가능한 스트림으로. 굽는 곳은 여기 한 군데다.
func to_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = SfxSynth.to_pcm16(samples)
	return stream
