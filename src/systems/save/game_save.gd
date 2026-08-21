class_name GameSave
extends RefCounted
## 세이브의 **봉투.** 무엇을 담고 어떤 버전인가를 정한다. 파일은 안 만진다.
##
## 파일 입출력을 여기서 떼어 둔 이유는 하나다 — **디스크 없이 왕복을 시험할 수 있다.**
## 저장한 것을 그대로 불러오면 같은가는 이 클래스 하나로 판정된다
## (docs/design/34-systems.md §34.4).
##
## ## 담을 「무엇」은 코어가 안다
##
## 여기는 `Guild.to_dict()` 를 봉투에 넣고 꺼낼 뿐이다. 길드의 필드 이름을
## 여기서 한 번 더 적기 시작하면, 규칙이 바뀔 때마다 두 곳을 고치게 된다.

## 세이브 형식의 판. **첫 판부터 넣는다** — 나중에 넣으면 그 전에 저장된 것을 못 읽는다.
##
## | 판 | 무엇이 늘었나 |
## | --- | --- |
## | 1 | 길드 · 씨앗 |
## | **2** | **세계가 걸어온 길** (`WorldProgress`) — docs/design/37-meta-loop.md §37.5 |
##
## **판 1 을 계속 읽는다.** 그 파일에는 걸어온 길이 없으므로 세계가 처녀 상태로 서고,
## 그것이 그 파일이 저장하던 그대로다 (§34.4.1 이 세계 변화를 안 담았다).
const VERSION := 2

const KEY_VERSION := "version"
const KEY_SEED := "campaign_seed"
const KEY_GUILD := "guild"
const KEY_SAVED_AT := "saved_at"

## 세계가 걸어온 길. **봉투가 든다** — 길드의 것이 아니라 세계의 것이다.
const KEY_WORLD := "world"


## 지금 상태를 봉투에 담는다.
##
## `saved_at` 은 게임이 읽지 않는다 — 파일을 열어 본 사람이 언제 것인지 알라고 넣는다.
static func capture(guild: Guild, campaign_seed: int) -> Dictionary:
	if guild == null:
		return {}
	return {
		KEY_VERSION: VERSION,
		KEY_SEED: campaign_seed,
		KEY_SAVED_AT: Time.get_datetime_string_from_system(),
		KEY_GUILD: guild.to_dict(),
		KEY_WORLD: guild.world_progress.to_dict(),
	}


## 봉투를 뜯는다. **어느 단계에서 막혀도 사유가 남는다.**
##
## `npc_world` 를 주면 그것에 길드를 딛는다. 안 주면 씨앗에서 세계를 다시 세운다 —
## 세계가 필요 없는 시험은 `build_world` 를 꺼서 3000명 세우는 값을 안 낸다.
static func restore(
	data: Dictionary, build_world: bool = true, npc_world: NpcWorld = null
) -> SaveResult:
	if not data.has(KEY_VERSION):
		return SaveResult.failed(SaveResult.Status.BAD_SHAPE, "버전이 없다")
	var version := int(data[KEY_VERSION])
	if version > VERSION:
		return SaveResult.failed(
			SaveResult.Status.VERSION_AHEAD, "파일 %d, 이 빌드 %d" % [version, VERSION]
		)
	if not data.has(KEY_GUILD) or not (data[KEY_GUILD] is Dictionary):
		return SaveResult.failed(SaveResult.Status.BAD_SHAPE, "길드가 없다")

	var campaign_seed := int(data.get(KEY_SEED, 0))
	var world := npc_world
	if world == null and build_world:
		world = NpcWorld.create(campaign_seed)

	# **길드를 세우기 전에 세계를 되감는다.** 후보의 영입 판정은 세계에서 재는 값이라
	# (`Guild._rebind_world`) 순서가 뒤집히면 **한 틱 전의 세계로 판정한 명단**이 뜬다.
	var progress := WorldProgress.from_dict(data.get(KEY_WORLD, {}) as Dictionary)
	progress.replay(world)

	var guild := Guild.from_dict(data[KEY_GUILD] as Dictionary, world)
	if guild == null:
		return SaveResult.failed(SaveResult.Status.BAD_SHAPE, "대원 명단이 없다")
	guild.world_progress = progress
	return SaveResult.ok(guild, campaign_seed, world)
