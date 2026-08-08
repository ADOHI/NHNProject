"""겹별 생성 — 로컬 ComfyUI :8000, Klein 4B Pro. 접근 C.

room-studio 레인이 이미 푼 문제라 그 결론을 그대로 쓴다
(C:/Users/adohi/2dAnim/room-studio/docs/APPROACH-COMPARISON.md).

    풀샷 한 장을 **화풍 레퍼런스로만** 물려 겹을 따로 생성한다.
    레퍼런스가 없으면 겹마다 화풍도 카메라 거리도 제각각이 되고,
    레퍼런스만 있고 "구도는 베끼지 마라" 문장이 없으면 전부 풀샷의 축소판이 된다.

컷아웃이 필요한 겹은 배경을 마젠타로 깔고 `cut_layers.py` 가 알파를 뺀다.

--- 설정 정정 (통합자 지시) -------------------------------------------------

이전 시안에 **조명 트러스 · 스피커 · 케이블 · 관객석**을 넣었다. 그것은 폐기된 설정이다.
지금 설정에서 그놈들은 **게이트를 열 뿐 스튜디오를 짓지 않는다.** 중계는 직접 본다.
장비도 세트도 없다. 그래서 배경에서 인공 설비를 전부 뺀다.

--- 조명 규칙 (합성이 성립하려면 반드시 지켜야 한다) ------------------------

빛은 **가운데 금 하나**에서 난다. 그러므로 겹마다 빛이 오는 쪽이 다르다 —
왼쪽에 앉을 인간은 오른쪽에서, 오른쪽에 앉을 인간은 왼쪽에서 받는다.
이것을 프롬프트에 박지 않으면 합성했을 때 각자 다른 태양을 이고 있게 된다.
"""

from __future__ import annotations

import argparse
import os

from gen_scene import build, post, get, run, upload, OUT  # noqa: F401  (같은 배관을 쓴다)

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# 공통 문장
# ---------------------------------------------------------------------------

#: 화풍만 가져오고 구도는 가져오지 않는다. 뒷문장이 규격의 일부다.
STYLE_REF = (
    "Match the reference image exactly in painting style, brush handling, colour "
    "palette, light temperature and level of finish. Do not copy its composition "
    "or its objects — only its look."
)

STYLE = (
    "dramatic video game key art, rich saturated colour, painterly digital illustration "
    "with crisp animation-background rendering, strong chiaroscuro, "
    "warm gold key light against deep cold teal shadow"
)

#: 의뢰인이 "적당히 수상한 느낌 내도 됨" 이라고 했다. 말끔할 필요가 없다.
SHADY = (
    "grubby and slightly seedy, worn and greasy surfaces, "
    "the faint sense that this whole arrangement is crooked"
)

#: 크로마. room-studio 실측 — 모델은 지시를 절반만 듣고 배경에도 장면 조명을 먹인다.
#: 그래서 "배경에 빛이 안 떨어진다"를 따로 못 박는다. 이 한 문장이 실제로 효과가 있었다.
CHROMA = (
    "The subject is completely isolated on a flat solid magenta background, "
    "pure #FF00FF magenta, no gradient, no vignette. "
    "The glow from the treasure lights the subject itself but no light, glow or haze "
    "falls onto the background — the background stays evenly flat magenta everywhere. "
    "Nothing else is in the picture, no floor, no shadow cast on the background."
)

#: 설정 정정. 배경에서 인공 설비를 뺀다.
NO_STUDIO = (
    "There is absolutely no man-made equipment anywhere: no lighting rigs, no trusses, "
    "no spotlights, no lamps, no loudspeakers, no cameras, no cables, no wiring, "
    "no scaffolding, no railings, no audience seating, no signage, no machinery."
)

NO_TEXT = "No text, no letters, no logo, no watermark, no user interface, no border."


def _p(*parts: str) -> str:
    return " ".join(p.strip() for p in parts if p.strip())


# ---------------------------------------------------------------------------
# 겹
# ---------------------------------------------------------------------------

#: 배경 — 크로마 없음. 가운데를 비워 둔다 (거기 금이 앉는다).
BACKDROP = _p(
    STYLE,
    "A vast ancient underground chamber of raw carved stone, hewn by hand long ago:",
    "rough rock walls, crumbling arches and pillars, broken flagstone floor,",
    "dark tunnel mouths and galleries receding into blackness on every side,",
    "cold teal gloom and drifting dust haze.",
    NO_STUDIO,
    "The room is completely EMPTY — no people, no creatures, no treasure, no chest.",
    "The exact centre of the floor is bare empty stone, and the centre of the frame",
    "is the darkest, emptiest part of the picture.",
    "A faint warm glow spills from the centre of the floor as if something there were lit.",
    SHADY,
    NO_TEXT,
)

#: 중앙 — 화면의 주인공이자 **유일한 광원**.
HOARD = _p(
    STYLE,
    "A heavy iron-bound wooden treasure chest standing open, heaped with gold that has",
    "fused into ONE single solid glowing mass. A single jagged black FISSURE splits that",
    "gold mass clean in two from top to bottom — cracked gold, broken treasure,",
    "the two halves slightly out of line with each other.",
    "The gold burns warm amber and is the only light source, throwing light outward",
    "and upward. Loose gold bars and coins spill over the chest's lip.",
    SHADY,
    CHROMA,
    NO_TEXT,
)

#: 전경 — 가장 빨리 흐르는 겹. 화면 아래 가장자리에 걸치는 바위 턱.
#:
#: **캔버스가 화면과 같은 비(1536×864)여야 한다.** `rect_of` 는 span 0 인 겹을
#: 가로세로비를 무시하고 화면에 꽉 채우므로, 캔버스 비가 다르면 그대로 늘어난다
#: (docs/design/21-title.md §21.13.11). 그래서 `cut_layers.py` 도 이 겹은 잘라내지 않는다.
#:
#: 그리고 **빈 자리를 비워 두라고 강하게 말해야 한다.** 앞 판에서 이 겹의 빈 마젠타
#: 한가운데에 이빨을 드러낸 외눈 괴물이 그려져 나왔고, 그것이 합성에서 상자를 가렸다
#: (§21.13.7). 원인은 화풍 레퍼런스였지만 문장으로도 한 번 더 막는다.
FOREGROUND = _p(
    STYLE,
    "A ragged ledge of broken foreground rock and rubble running across the BOTTOM THIRD",
    "of the frame only, seen very close to the camera, almost in silhouette,",
    "rim-lit along its top edge by a warm glow coming from beyond it.",
    "The upper two thirds of the picture is completely empty flat magenta —",
    "there is nothing in it at all: no creature, no face, no eye, no figure,",
    "no floating object, no sky, no wall, no haze. It is bare empty magenta.",
    NO_STUDIO,
    CHROMA,
    NO_TEXT,
)

#: 인간 — **사방에서 오므로 시점이 제각각이어야 한다.**
#: 전부 정측면이면 사방이 안 된다. 그리고 자세는 탐내는 것이지 겁먹은 것이 아니다.
#: **자세를 두고 지시가 갈린다. 기본값은 합성안이다.**
#:
#:   의뢰인      "사방에서 캐릭터들이 **달라들어**"
#:   기획 §2.0.3 "**달려드는 것이 아니라 재고 있는** 정지된 긴장이어야 한다 — 턴제다"
#:
#: 둘 다 맞는 말이라 가운데를 잡았다 — **몸은 이미 가고 있는데 아직 안 잡았다.**
#: 무게는 뒷발에 남아 있고 손만 먼저 나간다. 달려드는 것으로도 읽히고
#: 재고 있는 것으로도 읽히는 유일한 순간이고, 무엇보다 **턴제의 자세**다.
#: 순수한 돌격이 필요하면 `--lunge`.
HUNTER_POISED = (
    "a human treasure hunter in mismatched worn adventuring gear and scavenged armour, "
    "leaning in hard toward the treasure with one hand already reaching out for it, "
    "but the weight still held back on the rear foot and the treasure not yet touched — "
    "committed but not yet arrived, taut and coiled, sizing up the rivals, "
    "openly covetous and greedy, eyes fixed and hungry, "
    "absolutely not afraid, not fleeing, not defensive"
)

HUNTER_LUNGE = (
    "a human treasure hunter in mismatched worn adventuring gear and scavenged armour, "
    "caught mid-lunge diving for the treasure, both arms thrown out, "
    "racing the rivals, openly covetous and exhilarated, grinning with naked greed, "
    "absolutely not afraid, not fleeing, not defensive"
)

HUNTER_CORE = HUNTER_POISED

HUNTERS: list[tuple[str, str, tuple[int, int]]] = [
    (
        "hunter_back",
        # 카메라에 가장 가까이 앉는다. 뒷모습이 앞에 오면 "내가 그 자리에 있다" 가 된다.
        "Seen from BEHIND, back turned fully to the camera, lunging away from the viewer "
        "into the scene, both arms outstretched forward and away from us. "
        "Rim-lit from in FRONT of them, so the warm light wraps their silhouette edges "
        "and their back stays dark. Large in frame, close to the camera.",
        (768, 1024),
    ),
    (
        "hunter_front",
        # 판 반대편. 우리를 마주 본다 — 얼굴의 탐욕이 보이는 유일한 장.
        "Seen from the FRONT, facing the camera directly, lunging toward the viewer, "
        "arms reaching forward toward us, face fully visible and lit from BELOW by warm "
        "golden light, eyes wide with greed, mouth open in a delighted shout.",
        (768, 1024),
    ),
    (
        "hunter_left",
        # 화면 왼쪽에 앉는다 → 빛은 오른쪽(가운데)에서 온다.
        "Seen in THREE-QUARTER view from their front-left, body turned toward the RIGHT "
        "side of the frame, lunging to the RIGHT with the leading arm outstretched right. "
        "Lit strongly from the RIGHT by warm golden light; their left side is in cold shadow.",
        (768, 1024),
    ),
    (
        "hunter_right",
        # 화면 오른쪽에 앉는다 → 빛은 왼쪽(가운데)에서 온다.
        "Seen in full SIDE PROFILE from their right, body turned toward the LEFT side of "
        "the frame, lunging to the LEFT with both arms reaching left, one knee down. "
        "Lit strongly from the LEFT by warm golden light; their right side is in cold shadow.",
        (768, 1024),
    ),
]

#: 악마 — **눈이 하나다.** 풀샷에서 모델이 자꾸 둘을 그려서 여기서는 한 마리씩,
#: 그리고 여러 문장으로 눌러 말한다.
#:
#: **광기가 아니라 여유다** (docs/design/21-title.md §21.13.8). 앞 판이 여기서 졌다 —
#: "다문 입"까지는 지켜졌는데 눈을 끝까지 크게 뜨고 있어서 전부 광기로 읽혔다.
#: 외눈박이는 눈이 얼굴의 대부분이라 **눈꺼풀 하나로 성격이 정해진다.**
#: 활짝 열린 안구는 무슨 표정을 붙여도 미친 것으로 간다.
#:
#: 그리고 **부정문을 걷어냈다.** `NOT screaming, NOT roaring, NOT snarling, howl` 은
#: 모델에게 그 네 낱말을 들려주는 문장이다. 있어야 할 것만 적는다 —
#: 늘어진 눈꺼풀 · 한쪽만 올라간 다문 입 · 축 처진 몸 · 서두를 것 없는 자세.
DEMON_CORE = (
    "a grotesque floating demon with exactly ONE single eye — a cyclops, "
    "one large eyeball taking up most of its face, "
    "it has only ONE eye and there is no second eye anywhere on its head — "
    "the rest of its face is bare skin with no other eye and no empty socket. "
    "Its heavy upper eyelid droops halfway down across that eye in a lazy half-lidded "
    "gaze, the lid creased and relaxed, the pupil rolled downward to watch something far "
    "below it. "
    # 앞 판이 여기서 한 번 더 졌다 — "한쪽 입꼬리만 올라간다"고 했더니 모델이 입 전체를
    # **내려** 그려서 시무룩한 얼굴이 됐다. 올라간다는 것을 먼저, 세게 말한다.
    "Its mouth is a small closed line that tilts clearly UPWARD at one end into a "
    "lopsided smirk — the corner is lifted, pleased and amused, and the lips stay shut "
    "so no teeth show. "
    "Its body hangs loose and boneless in the air, utterly unhurried and at ease, "
    "lounging as it watches. "
    "The mood is calm, lazy, private amusement — a comfortable spectator who has seen "
    "this many times before and still finds it funny, in no hurry at all"
)

#: 자리는 §21.13.9 의 배치표를 따른다. **자리와 시선이 따로 놀면 사슬이 끊긴다** —
#: 프롬프트의 눈 방향은 `title_layers.gd` 의 `watching` 과 같은 것을 가리켜야 한다.
DEMONS: list[tuple[str, str]] = [
    (
        # 화면 왼쪽 끝 위. 왼쪽 아래의 사람을 본다.
        "demon_a",
        "Large and close, hovering, its chin propped lazily on one hand like a spectator "
        "settled into a seat, the other hand hanging limp and empty. Both hands are empty "
        "and idle — it is carrying nothing and holding no object of any kind. "
        "The half-lidded eye is rolled down and slightly to the RIGHT.",
    ),
    (
        # 화면 오른쪽 끝 위. 오른쪽 아래의 사람을 본다.
        "demon_b",
        # 앞 판에서 "drooping with boredom" 이 얼굴까지 끌어내려 우는 상이 됐다.
        # 늘어짐은 **몸에만** 건다.
        "Long and thin, its lanky body loosely coiled in the air, arms folded, "
        "leaning back as if reclining on nothing. Its hands are empty. "
        "The half-lidded eye is rolled down and slightly to the LEFT.",
    ),
    (
        # 가장 위, 가장 작고 가장 멀다. 바로 아래 정면의 사람을 본다.
        "demon_c",
        "Squat and bloated, drifting slowly, belly slack, one spindly empty hand flopped "
        "over to gesture vaguely at something below while its shoulders shake with quiet "
        "private laughter. The half-lidded eye is rolled straight DOWN.",
    ),
]

DEMON_LIGHT = (
    "Mostly a dark silhouette against the dark, lit only weakly from BELOW by a distant "
    "warm golden glow that catches the curve of the huge eye and the edge of the grin."
)


def layers(lunge: bool = False) -> list[tuple[str, str, tuple[int, int]]]:
    """(이름, 프롬프트, 크기). 순서가 곧 생성 순서다."""
    pose = HUNTER_LUNGE if lunge else HUNTER_POISED
    out: list[tuple[str, str, tuple[int, int]]] = [
        ("backdrop", BACKDROP, (1536, 864)),
        ("hoard", HOARD, (1024, 768)),
        # 전경은 **화면과 같은 비**여야 한다 (§21.13.11). 잘라내지도 않는다.
        ("foreground", FOREGROUND, (1536, 864)),
    ]
    for name, view, size in HUNTERS:
        out.append((name, _p(STYLE, pose + ".", view, SHADY, CHROMA, NO_TEXT), size))
    for name, pose in DEMONS:
        out.append(
            (name, _p(STYLE, DEMON_CORE + ".", pose, DEMON_LIGHT, SHADY, CHROMA, NO_TEXT), (896, 896))
        )
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    # **풀샷을 물리지 않는다.** 풀샷 안의 인물은 반드시 다른 겹으로 샌다 —
    # 전경 한가운데에 이빨 드러낸 외눈 괴물이 나온 것이 그 증거다(§21.13.7).
    # 배경은 화풍·팔레트·빛 온도를 그대로 들고 오면서 샐 형태가 없다.
    ap.add_argument("--ref", default=os.path.join(OUT, "backdrop.png"),
                    help="화풍 레퍼런스. 기본값은 배경 — 생물이 없어서 새어 나올 형태가 없다")
    ap.add_argument("--seed", type=int, default=61204)
    ap.add_argument("--only", default="", help="쉼표로 구분한 겹 이름만 생성")
    ap.add_argument("--lunge", action="store_true",
                    help="헌터를 재는 자세가 아니라 순수한 돌격으로 (HUNTER_CORE 주석 참고)")
    args = ap.parse_args()

    ref = upload(args.ref)
    print("style reference uploaded as", ref, flush=True)
    wanted = {n.strip() for n in args.only.split(",") if n.strip()}

    for index, (name, prompt, size) in enumerate(layers(args.lunge)):
        if wanted and name not in wanted:
            continue
        run(name, _p(prompt, STYLE_REF), size[0], size[1],
            args.seed + index * 613, steps=24, refs=[ref])


if __name__ == "__main__":
    main()
