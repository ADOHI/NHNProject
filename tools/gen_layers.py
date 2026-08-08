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
FOREGROUND = _p(
    STYLE,
    "A ragged ledge of broken foreground rock and rubble running across the bottom of",
    "the frame, seen very close to the camera, almost in silhouette,",
    "rim-lit along its top edge by a warm glow coming from beyond it.",
    "Only the rock band along the bottom — the entire upper two thirds of the picture",
    "is empty flat magenta.",
    NO_STUDIO,
    CHROMA,
    NO_TEXT,
)

#: 인간 — **사방에서 오므로 시점이 제각각이어야 한다.**
#: 전부 정측면이면 사방이 안 된다. 그리고 자세는 탐내는 것이지 겁먹은 것이 아니다.
HUNTER_CORE = (
    "a human treasure hunter in mismatched worn adventuring gear and scavenged armour, "
    "caught mid-lunge reaching greedily toward the treasure, "
    "openly covetous and exhilarated, grinning with naked greed, "
    "absolutely not afraid, not fleeing, not defensive"
)

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
#: 그리고 여러 문장으로 눌러 말한다. 그리고 **비명이 아니라 웃음**이다 —
#: 강요한 적이 없으니 죄책감도 없고, 그래서 태연하다. 그게 더 서늘하다.
DEMON_CORE = (
    "a grotesque floating demon with exactly ONE single enormous eye — a cyclops, "
    "one huge glossy eyeball taking up most of its face, "
    "it has only ONE eye and there is no second eye anywhere on its head. "
    "Below the eye a wide closed-lip smirk curls up at the corners. "
    "It is thoroughly amused and relaxed, watching something below with lazy delight, "
    "smug and entertained, chuckling to itself. "
    "It is NOT screaming, NOT roaring, NOT snarling, NOT attacking, its mouth is not "
    "stretched wide open in a howl — it is quietly enjoying the show"
)

DEMONS: list[tuple[str, str]] = [
    (
        "demon_a",
        "Large and close, hovering and leaning down to look, chin resting on one hand "
        "like a bored spectator, the single eye swivelled downward to the LEFT.",
    ),
    (
        "demon_b",
        "Long and thin, coiling downward like smoke, arms folded, "
        "the single eye turned downward to the RIGHT, smirking.",
    ),
    (
        "demon_c",
        "Squat and bloated, drifting, one spindly finger pointing down at something below "
        "while shaking with silent laughter, the single eye looking straight DOWN.",
    ),
]

DEMON_LIGHT = (
    "Mostly a dark silhouette against the dark, lit only weakly from BELOW by a distant "
    "warm golden glow that catches the curve of the huge eye and the edge of the grin."
)


def layers() -> list[tuple[str, str, tuple[int, int]]]:
    """(이름, 프롬프트, 크기). 순서가 곧 생성 순서다."""
    out: list[tuple[str, str, tuple[int, int]]] = [
        ("backdrop", BACKDROP, (1536, 864)),
        ("hoard", HOARD, (1024, 768)),
        ("foreground", FOREGROUND, (1536, 512)),
    ]
    for name, view, size in HUNTERS:
        out.append((name, _p(STYLE, HUNTER_CORE + ".", view, SHADY, CHROMA, NO_TEXT), size))
    for name, pose in DEMONS:
        out.append(
            (name, _p(STYLE, DEMON_CORE + ".", pose, DEMON_LIGHT, SHADY, CHROMA, NO_TEXT), (896, 896))
        )
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", default=os.path.join(OUT, "full_2.png"),
                    help="화풍 레퍼런스로 물릴 풀샷")
    ap.add_argument("--seed", type=int, default=61204)
    ap.add_argument("--only", default="", help="쉼표로 구른 겹 이름만 생성")
    args = ap.parse_args()

    ref = upload(args.ref)
    print("style reference uploaded as", ref, flush=True)
    wanted = {n.strip() for n in args.only.split(",") if n.strip()}

    for index, (name, prompt, size) in enumerate(layers()):
        if wanted and name not in wanted:
            continue
        run(name, _p(prompt, STYLE_REF), size[0], size[1],
            args.seed + index * 613, steps=24, refs=[ref])


if __name__ == "__main__":
    main()
