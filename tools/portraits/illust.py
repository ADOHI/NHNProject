"""전신 일러스트와 SD 변환의 그래프, 문자열.

**배선은 `2dAnim/minimal-char-studio` 에서 그대로 가져왔다** (§27.22).
그 스튜디오가 이미 검증한 것을 다시 짜지 않는다 —
`mcs/comfy/workflows.py` 의 `_build_zimage` 와 `mcs/comfy/edits.py` 의
`_build_klein_edit_legacy` 다.

# 인스턴스가 하나다 — 그리고 그것이 맞다

그 스튜디오는 `instance="modern"`(8001)로 적어 뒀는데 **지금 8001 은 안 떠 있고
8000 만 떠 있다.** 8000 에 필요한 것이 전부 있는지 실제로 물어봤다 (2026-08-08):

    CheckpointLoaderSimple, CLIPLoader(lumina2, flux2), ModelSamplingAuraFlow ,
    KSampler(res_multistep), EmptySD3LatentImage, Flux2KleinKSamplerExperimental
    kompostoZITANI_zitANI_fp8, z_image_turbo_vae, qwen_3_4b_bf16_fp8_scaled

**전부 있다.** 그래서 인스턴스를 새로 띄우지 않는다 — 예전에 둘 띄웠다가
블루스크린이 났고, 그 스튜디오도 *"인스턴스가 하나로 줄어 「로컬 ComfyUI 는
하나만」 규칙과도 맞는다"* 로 끝냈다.

**대신 모델을 갈 때마다 `comfy.free()` 를 부른다.** 16GB 에 zitani 와 Klein 을
같이 올리면 경합한다.

# zitani 의 기본값은 **제작자 권장**이다. 고치지 마라

`workflows.py` 가 적어 둔 것 — 체크포인트의 safetensors 메타데이터에 제작 워크플로가
박혀 있고 그 설정이 `steps 9 / cfg 1.0 / res_multistep / simple /
ModelSamplingAuraFlow shift 3.0` 이었다. 그 레인의 배선은 `euler` 였고
`ModelSamplingAuraFlow` 가 빠져 있었으며, **그것이 zitani 결과가 밋밋했던 원인일 수
있다**고 적혀 있다. **모델이 자기 권장값을 들고 있으면 그걸 먼저 쓴다.**

# 네거티브를 안 쓴다

`cfg 1.0` 이면 `pred = uncond + cfg × (cond − uncond)` 가 `pred = cond` 로 줄어
**네거티브 항이 수식에서 사라진다.** 그 레인이 실측했다 —
프롬프트 전체를 부정해도 결과가 **비트 단위로 같았다** (`PROMPTS.md` §7-1).
그래서 배경,품질 통제는 **긍정 서술로만** 한다. 초상 레인의 §27.9 와 같은 결론이다.
"""

from __future__ import annotations

import ast
import os

# ── zitani (Z-Image Turbo) — 전신 일러스트 ───────────────────────────────────

ZITANI_CKPT = "kompostoZITANI_zitANI_fp8.safetensors"
ZIMAGE_CLIP = "qwen_3_4b_bf16_fp8_scaled.safetensors"
ZIMAGE_VAE = "z_image_turbo_vae.safetensors"

#: 제작자 권장값. **고치지 마라** (모듈 머리말).
ZITANI_STEPS = 9
ZITANI_CFG = 1.0
ZITANI_SAMPLER = "res_multistep"
ZITANI_SCHEDULER = "simple"
ZITANI_SHIFT = 3.0

#: 캐릭터 시트는 세로형이다. `PROMPTS.md` §7 실측 — 정사각형에 전신을 넣으면
#: 좌우가 낭비되고 그만큼 몸이 작게 그려져 **의상과 손이 먼저 뭉갠다.**
ILLUST_W, ILLUST_H = 832, 1216

# ── Klein 4B Pro edit — SD(치비) 변환 ────────────────────────────────────────

KLEIN_UNET = "fluxKlein4BPro_v10.safetensors"
KLEIN_CLIP = "qwen_3_4b_fp4_flux2.safetensors"
KLEIN_VAE = "flux2-vae.safetensors"
KLEIN_EDIT_STEPS = 4

#: 치비 시트는 형태가 단순하고 최종 스프라이트 크기를 생각하면 512² 로 충분하다
#: (`PROMPTS.md` §7).
SD_SIZE = 512

#: SD 변환 지시. **`d60ee36` 에서 되살렸다** — `51e86f4` 의 리팩터가 이 상수를 떨어뜨려
#: `gen_batch.py --stage sd` 가 조용히 깨져 있었다 (`illust.SD_CONVERT` 를 부르는데 없었다).
#:
#: **모듈 두 개가 서로를 부르는데 한쪽만 고친 사고다.** 상수를 옮길 때 부르는 쪽을
#: 안 따라간 것이고, `--stage illust` 만 돌려 봐서 여태 안 터졌다.
#:
#: `keeping the same ... drawing style` 이 여기서 무겁다 — **화풍을 전신에서 SD 로
#: 넘기는 것이 이 한 구절이다.** 배경을 연 뒤에도 이게 서는지가 §27.31 의 물음이다.
SD_CONVERT = (
    "Redraw this same character as one small chibi game sprite, keeping the same face, "
    "the same hair, the same clothes, the same colours and the same drawing style. "
    "The head is as large as the whole rest of the body. The whole figure stands inside "
    "the frame with empty margin around it. Seen from a three-quarter right view. "
    "The background is plain flat white all the way to every edge."
)

# ── 코드가 고정하는 문장 ─────────────────────────────────────────────────────

# ---------------------------------------------------------------------------
# 원본 조리법 — **베끼지 않고 읽어 온다** (§27.24)
# ---------------------------------------------------------------------------
#
# 출처: `2dAnim/minimal-char-studio/mcs/commands/illust.py` 의 `build_prompt()`,
# `mcs/prompt/quality.py` 의 `ANIME_ANCHOR`.
# 실제로 모델에 간 문자열이 `outputs/minimal-char/results.jsonl` 에 **212건** 남아 있다
# (전부 zitani, 전부 832x1216).
#
#     A 2D Japanese anime illustration. {style}. {character}. {FRAME}
#
# **상수를 베껴 적지 않는다.** 이 저장소에서 베낀 상수가 조용히 낡은 사고가 여러 번이다.
# 그 파일을 실제로 읽어서 값을 꺼낸다 — 그쪽이 문자열을 고치면 여기가 같이 바뀌고,
# 이름이 바뀌면 **조용히 낡는 대신 터진다.**
#
# `import` 대신 `ast` 로 읽는 이유: `mcs/commands/illust.py` 는 PIL 과 그 패키지의
# 절반을 끌고 오고 락 파일까지 건드린다. **우리는 문자열 두 개만 필요하다.**
# 파싱은 실행이 아니라 읽기라 부작용이 없다.

_STUDIO = os.path.join(os.path.expanduser("~"), "2dAnim", "minimal-char-studio")


def _const_from(rel_path: str, name: str) -> str:
    """그 파일의 모듈 수준 문자열 상수 하나를 읽어 온다. **없으면 터뜨린다.**"""
    path = os.path.join(_STUDIO, *rel_path.split("/"))
    with open(path, encoding="utf-8") as f:
        tree = ast.parse(f.read(), filename=path)
    for node in tree.body:
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id == name:
                return ast.literal_eval(node.value)
    raise RuntimeError(
        f"{path} 에 {name} 이 없다. minimal-char-studio 가 바뀌었다 — "
        f"§27.24 를 읽고 조리법을 다시 맞춰라"
    )


#: 매체 앵커. **맨 앞이라 가장 세다.** 그쪽 주석 — *"이게 없으면 그림체 슬롯이 회화 쪽으로
#: 갈 때 모델이 반실사로 끌려간다."* 순서를 바꾸지 마라 (위치가 곧 가중치다).
ANIME_ANCHOR = _const_from("mcs/prompt/quality.py", "ANIME_ANCHOR")

#: 구도, 배경, 그림자를 한 덩어리로 잡는 고정 문자열.
#: 그쪽 주석이 근거를 적어 뒀다 — *"그림자를 세 방향으로 막는다. `no shadow on the
#: ground` 만으로는 바닥에 해칭 그림자와 접지 그림자가 계속 그려졌다."*
ILLUST_FRAME = _const_from("mcs/commands/illust.py", "FRAME")

#: 화풍 슬롯. **원본은 매 장 LLM 이 새로 짓는다** (무한 탐색이 목적이라 그렇다).
#: **우리는 하나로 고정한다** — 사용자 결정. 3000명이 같은 화집에서 나온 것처럼 보여야 한다.
#: 화풍 다양성을 버리는 대신 **초상도 전신도 SD 도 같은 손이 된다.**
#:
#: 형식은 원본 가이드가 요구하는 **실행 가능한 작화 지시**다 — 윤곽선, 음영, 색 셋을
#: 각각 "무엇을 하라"로. 기록에 남은 표본이 그 모양이다:
#:
#:     "Fine dotted outlines, rich velvety shading, sepia tones paired with
#:      desaturated rose and cypress suggest early 1900s manga nostalgia"
#:
#: **`water_bishoujo` 를 뽑은 실제 문자열은 어디에도 안 남아 있다** (§27.24.3).
#: 그래서 후보를 만들어 검수를 받는다. `STYLE_CANDIDATES` 를 보라.
ILLUST_STYLE = (
    "Fine ink outlines over translucent watercolour washes, the pigment pooling and "
    "drying unevenly inside each shape, muted slate blue, ochre and dull red"
)

# ---------------------------------------------------------------------------
# 화풍 후보 — **1차는 내가 지었고, 2차는 기록에서 꺼냈다** (§27.25)
# ---------------------------------------------------------------------------
#
# 1차(`wash`/`ink`/`soft`)는 내가 원본 **형식**에 맞춰 지은 것이다. `soft` 가 배경을
# 깼다 (§27.24.5). 2차는 짓지 않는다 — `results.jsonl` 의 zitani 기록에 **원본 앵커와
# 원본 FRAME 을 그대로 달고 실제로 모델에 갔던 화풍 문자열 19개**가 남아 있다.
# 우리 슬롯 구조와 **글자 하나까지 같은 자리**에서 나온 것이라 형식을 추측할 필요가 없다.
#
#     A 2D Japanese anime illustration. {여기}. {인물}. Full body from head to toe ...
#
# 그래서 2차 후보는 **전부 그 19개에서 골랐다.** 고른 기준은 예쁨이 아니라 **축**이다 —
# 한 후보가 여러 축을 동시에 극단으로 가면 무엇이 효과를 냈는지 알 수 없다.
#
# 기록의 원문 일부에는 인물 서술(`a woman in her thirties in a plain grey wool coat...`)이
# **화풍 슬롯 안까지 흘러 들어와 있다.** 그건 그쪽 LLM 이 칸을 넘긴 사고고, 우리는
# 화풍 부분만 잘라 쓴다. (§27.24.5 가 말한 「칸을 넘어간다」의 또 다른 실례다.)

#: `(밀어 본 축, 화풍 문자열)`. **값 하나를 바꾸는 자리라 갈아 끼우기가 싸다.**
#: `기록`이라 적힌 것은 `outputs/minimal-char/results.jsonl` 의 실제 zitani 프롬프트다.
STYLE_CANDIDATES: dict[str, tuple[str, str]] = {
    # ── 1차 — 내가 지었다. 검수 결과가 §27.24.5 에 있다 ──────────────────────
    "wash": ("[1차] 물감이 형태 안에서 고인다", ILLUST_STYLE),
    "ink": ("[1차] 굳은 잉크선 + 가장자리를 비운 평평한 수채", (
        "Firm dark ink contours with dry-brush breaks, flat translucent watercolour fills "
        "left pale at the edges, faded indigo, rust and bone white"
    )),
    "soft": ("[1차] **깨졌다** — 물감이 선 밖으로 번진다", (
        "Soft graphite contours under wet watercolour bleeding past the line, colour "
        "settling into grainy pools, dusty green, warm grey and muted plum"
    )),

    # ── 2차 · 선 축 — 있나 없나, 굵나 가늘나, 고른가 변하나 ──────────────────
    "hairline": ("선: 가장 가늘다 (머리카락 굵기)", (
        "Delicate hairline outlines with gradient shading; rich teal, muted orange, and "
        "crisp white evoke 1980s sci-fi manga illustrations"
    )),
    "heavy": ("선: 가장 굵고 거칠다", (
        "Heavy, jagged outlines contrast with intricate hatching; deep reds and golds, "
        "evoking traditional ukiyo-e"
    )),
    "noline": ("선: 거의 없다 — 형태를 색 덩어리로 읽는다", (
        "Soft, almost invisible outlines; strong, cell-shaded blocks of color; earthy "
        "browns and muted greens, echoing a handmade craft"
    )),
    "varied": ("선: 굵기가 변하고 끊긴다", (
        "Varied line weight outlines break up for texture; blocky geometric fills; muted "
        "sienna, gray, and moss, channeling 1970s gekiga contrasts"
    )),

    # ── 2차 · 음영 축 — 계단이 몇인가 (평평 ↔ 연속) ─────────────────────────
    "hatch": ("음영: 선으로 만든다 (크로스해칭)", (
        "Delicate ink outlines with cross-hatched shading, vibrant coral, teal, and "
        "mustard colors, late 80s manga vibe"
    )),
    "cel": ("음영: 각진 셀 — 계단이 둘", (
        "Medium grey outlines, streak-like angular cell shading, vivid jewel tones of "
        "emerald, sapphire, and amethyst indicative of 90s anime aesthetics"
    )),
    "gradient": ("음영: 계단이 없다 — 연속 그라데이션", (
        "Highly thick charcoal-like outlines, with smooth gradients; bright oranges, "
        "purples, and teal hues, suggestive of pop surrealism"
    )),

    # ── 2차 · 색 축 — 온도, 채도, 색 수 ─────────────────────────────────────
    "sepia": ("색: 채도 최저 · 따뜻 · 색 수 적다", (
        "Fine dotted outlines, rich velvety shading, sepia tones paired with desaturated "
        "rose and cypress suggest early 1900s manga nostalgia"
    )),
    "neon": ("색: 채도 최고 · 차갑다", (
        "Light pencil outlines, vibrant gradients softly transitioning, neon blues and "
        "rich burgundies, reminiscent of late 80s cyberpunk anime aesthetics"
    )),

    # ── 2차 · 가장자리 축 — **`soft` 가 진 자리의 재시험이다** ───────────────
    # `soft` 는 「물감이 선 밖으로 번진다」로 썼다가 배경을 깼다. 같은 뜻을 **행동이
    # 아니라 상태**로 쓴 기록이 있다 — `feathered`. 규칙이 맞으면 이건 산다.
    "feather": ("가장자리: 부드럽다를 **상태**로 (`soft` 재시험)", (
        "Imprecise watercolor-esque outlines, feathered shading and highlights, vibrant "
        "yellows and magentas channel vibrant shojo manga"
    )),
    # **금지 규칙을 정면으로 시험한다.** 이 문자열은 `bleeding` 을 쓰고도 212건 배치에
    # 실제로 들어갔다. 배경이 성하면 §27.24.5 의 원인 지목이 틀린 것이고,
    # 깨지면 **낱말이 아니라 뜻이 넘어간다**는 진단이 두 표본으로 선다.
    "bleed": ("가장자리: 기록에 남은 `bleeding` — 규칙 자체를 시험한다", (
        "Wispy grey outlines bleeding into soft chalky layers of sepia, periwinkle, and "
        "ochre, like 1970s manga"
    )),

    # ── 3차 · **형식을 바꾼다** — 위 열넷이 「다 비슷하다」는 평을 받았다 ────────
    #
    # 사용자: *"지금 보면 화풍이 너무 안 드러나는데... `paint_bishoujo` 이 폴더에
    # 생성하는 테스트 할때는 화풍이 잘 드러났는데"*, *"색보다는 화풍에 집중해줘"*
    #
    # **위 열넷은 전부 「선 + 음영 + 색」 형식이다.** 그 형식은 애니메 기본값 위에
    # 얹히는 미세 조정이라 **뭘 넣어도 애니메로 수렴한다.** 기록에서 골랐다는 것이
    # 갈린다는 뜻이 아니었다 — **그 기록 자체가 그 형식으로 돌린 판이다.**
    # 실측이 그것을 뒷받침한다: `stylebench/bench.json` 의 `noise 27.8` 대
    # `NEW spread 29.91` — **화풍 여섯을 바꾼 것이 시드 하나 바꾼 것과 거의 같았다.**
    #
    # `outputs/minimal-char/paint_bishoujo/index.html` 의 여섯은 형식이 다르다:
    #
    #     oil painting, thick impasto brushstrokes, painterly, no outlines
    #
    # **차이가 넷이다:**
    #
    # ㉠ **매체를 이름으로 부른다.** `oil painting` 은 모델 안의 사전분포가 거대해서
    #    이름 하나로 화면 전체가 바뀐다. `Fine dotted outlines` 에는 그런 게 없다
    # ㉡ **`no outlines` 가 있다.** 애니메 기본값은 선화다. **선을 안 끊으면 어떤
    #    화풍을 시켜도 애니메로 수렴한다.** 위 열넷은 오히려 선을 서술한다 —
    #    `hairline`, `varied`, `heavy` 는 **선을 유지하겠다고 말하고 있었다**
    # ㉢ **색 이름이 하나도 없다.** 색 벌이 화풍을 안 만들면서 예산의 3분의 1을 먹고,
    #    게다가 §27.25.6 대로 ③ 의 옷 색까지 이긴다
    # ㉣ **3~4어절이다.** 우리는 15~20낱말이었다. 길면 서로 상쇄된다
    #
    # **§27.9 의 부정문 금지를 `no outlines` 에 걸지 않는다.** 그 규칙은 Klein 흉상
    # 경로에서 얻었고 이것은 **zitani 경로에서 `paint_bishoujo` 가 실증한 문구**다.
    # §27.24.2 의 규율 그대로 — *규칙은 그것을 얻은 경로 안에서만 유효하다.*

    # ㉮ `paint_bishoujo` 여섯 **그대로.** 사용자가 「그때는 잘 나왔다」고 한 그 여섯이다
    "p_oil": ("[기준선] 매체: 유화", "oil painting, thick impasto brushstrokes, painterly, no outlines"),
    "p_water": ("[기준선] 매체: 수채", "watercolor painting, wet-on-wet, soft bleeding edges, no outlines"),
    "p_gouache": ("[기준선] 매체: 과슈", "gouache painting, opaque brush marks, no outlines"),
    "p_alla": ("[기준선] 매체: 알라프리마", "loose alla prima painting, visible brushwork, no outlines"),
    "p_pastel": ("[기준선] 매체: 파스텔", "soft pastel painting, blended chalk strokes, no outlines"),
    "p_digital": ("[기준선] 매체: 디지털", "digital painting, soft blended brushwork, no lineart"),

    # ㉯ 매체를 더 벌린다. **같은 형식**(매체 이름 + 결과 상태 + `no outlines`)
    "m_charcoal": ("매체: 목탄", "charcoal drawing, smudged soft blacks, no outlines"),
    "m_pencil": ("매체: 색연필", "coloured pencil drawing, fine layered strokes, no outlines"),
    "m_lino": ("매체: 판화", "linocut print, flat carved shapes, coarse grain, no outlines"),
    "m_acrylic": ("매체: 아크릴", "acrylic painting, flat matte layers, hard edges, no outlines"),
    "m_collage": ("매체: 콜라주", "cut paper collage, torn edges, flat layers, no outlines"),
    # 스크린톤은 **선이 곧 정체성**이라 `no outlines` 를 안 붙인다. 매체 축의 반대 끝이다
    "m_tone": ("매체: 스크린톤 (선을 남긴다)", "black and white manga screentone, halftone dot shading"),

    # ㉰ **같은 매체를 `no outlines` 없이.** 그 구절이 실제로 일하는지 가르는 자리다.
    #    붙인 것과 안 붙인 것의 차이가 곧 그 구절의 값이다
    "k_oil": ("매체: 유화 — **`no outlines` 뺐다**", "oil painting, thick impasto brushstrokes, painterly"),
    "k_gouache": ("매체: 과슈 — **`no outlines` 뺐다**", "gouache painting, opaque brush marks"),
    "k_charcoal": ("매체: 목탄 — **`no outlines` 뺐다**", "charcoal drawing, smudged soft blacks"),
}


# ---------------------------------------------------------------------------
# 앵커 — **셋 다 원본에 있다.** 고르는 게 아니라 재는 자리다 (§27.27)
# ---------------------------------------------------------------------------
#
# 맨 앞 문구는 **위치가 가중치라 가장 세다.** 그래서 매체를 불러도 애니메로 당길 수 있다.
# `results.jsonl` 을 세어 보니 원본이 형식을 둘 썼고 **다수가 앵커 없는 쪽이다:**
#
#     Drawn in {화풍}. {인물}. {FRAME}                      189건  ← 다수
#     A 2D Japanese anime illustration. {화풍}. {인물}. ...   19건
#
# 그리고 `outputs/minimal-char/noanchor_bishoujo/` 에 **앵커를 통째로 뺀** 실험이 있다.
# 다만 그때 화풍이 여전히 「선·음영·색」 형식이라 **결론이 반쪽이다** —
# 앵커 탓인지 형식 탓인지 안 갈린다. **네 칸을 다 채워야 갈린다.**

#: `모드 이름 -> 화풍 앞에 붙는 것`. **`""` 는 앵커 없음이다.**
ANCHORS: dict[str, str] = {
    "anime": "",      # 아래 `compose_illust` 가 `ANIME_ANCHOR` 를 쓴다 (기록 19건)
    "drawn": "Drawn in ",   # 기록 189건. **다수 형식이고 애니메 앵커가 없다**
    "none": "",       # `noanchor_bishoujo` 와 같은 자리
}


# ---------------------------------------------------------------------------
# 탐침용 규격 — **파이프라인이 쓰는 것이 아니다. 재려고만 쓴다** (§27.28)
# ---------------------------------------------------------------------------
#
# `paint_bishoujo` 의 실물을 보고 알았다 — **그 판들의 배경은 흰색이 아니다.**
# 회색 캔버스이고 `oil` 은 캔버스 올까지 보이고 `digipaint` 는 **검정**이다.
# 벌어짐 22.6 의 대부분이 거기서 나온다 (`digipaint` 하나가 나머지에서 46 떨어져 있다).
#
# > **매체가 드러나던 자리가 배경이었다.** 그리고 우리 ④ 규격은
# > `pure flat white background` + `Nothing else` 로 **그 자리를 지운다.**
#
# 그래서 우리 판에서 화풍은 **인물 안쪽에서만** 드러날 수 있고 폭이 좁다.
# 실측이 그것을 그대로 말한다 — 매체 이름을 넣어도 벌어짐이 6~7 에 머물렀고,
# 매체가 종이색을 내려 할 때마다 우리 자가 **「배경 깨짐 100%」**로 적었다.
# **화풍을 보이게 하는 바로 그것을 우리가 금지하고 있다.**
#
# `FRAME_OPEN` 은 그 가설을 재려고만 만든 것이다. 구도는 그대로 두고
# **배경 지시만 뺀다.** 여기서 벌어짐이 뛰면 진단이 맞은 것이다.
# **`ILLUST_FRAME` 은 안 건드린다** — §27.24 대로 원본 고정 문자열이다.
#
# # ④ 를 조각으로 갈라 잰다 — **배경과 발밑 그림자는 다른 문제다**
#
# 통합자: *"전부 빼는 게 답인지 일부만 빼는 게 답인지는 네가 재라.
# 배경이 종이색인 것과 발밑에 그림자가 지는 것은 다른 문제다."*
#
# 원본 ④ 는 문장 넷이다. **셋은 배경 담당이고 하나는 구도 담당이다:**
#
#     ㉮ Full body from head to toe ... character centered.   구도. **무조건 유지**
#     ㉯ Isolated on a pure flat white background.             배경을 희게
#     ㉰ No ground, no floor, no cast shadow and no contact shadow under the feet.
#     ㉱ Nothing else in the image.                            배경에 물건을 안 놓게
#
# ㉰ 는 **셋을 한꺼번에 막는다** — 바닥, 드리운 그림자, 접지 그림자.
# 그쪽 주석이 근거를 적어 뒀다: *"`no shadow on the ground` 만으로는 바닥에
# 해칭 그림자와 접지 그림자가 계속 그려졌다."* **배경을 열어도 이건 남길 수 있다.**
FRAME_PARTS = {
    "pose": ("Full body from head to toe, standing straight in a neutral idle pose, "
             "arms slightly away from the body, character centered."),
    "white": "Isolated on a pure flat white background.",
    "noshadow": ("No ground, no floor, no cast shadow and no contact shadow "
                 "under the feet."),
    "nothing": "Nothing else in the image.",
}

#: 규격 갈래. **`closed` 가 원본 그대로다** (§27.24 의 212건 검증 문자열).
FRAMES: dict[str, tuple[str, list[str]]] = {
    "closed": ("원본 그대로 — 흰 배경 강제", ["pose", "white", "noshadow", "nothing"]),
    "open": ("구도만 — 배경 지시를 통째로 뺐다", ["pose"]),
    "shadow": ("배경은 열고 **발밑 그림자만 막는다**", ["pose", "noshadow"]),
    "nothing": ("배경은 열고 그림자·잡동사니를 막는다", ["pose", "noshadow", "nothing"]),
}


def frame_of(name: str) -> str:
    """갈래 이름으로 ④ 문자열을 짓는다. `closed` 는 **원본을 그대로 돌려준다.**"""
    if name not in FRAMES:
        raise ValueError(f"모르는 규격: {name!r} (있는 것: {list(FRAMES)})")
    if name == "closed":
        return ILLUST_FRAME  # 베낀 것이 아니라 그 파일에서 읽어 온 것이다
    return " ".join(FRAME_PARTS[k] for k in FRAMES[name][1])


FRAME_OPEN = frame_of("open")


def compose_illust(character: str, style: str = "", anchor: str = "anime",
                   frame: str = "") -> str:
    """원본 조립 그대로. **갈아 끼우는 것은 `character` 한 칸뿐이다** (§27.24).

    순서가 곧 가중치다 — 앵커, 화풍, 인물, 규격. **바꾸지 마라.**
    품질 태그는 **안 붙인다** — 원본이 A/B 재고 사용자 결정으로 뺐다.

    `anchor` 는 셋 다 **원본에 실물이 있는 조립**이다 (`ANCHORS` 주석).
    기본은 `anime` — 지금까지 잰 판이 전부 그것이라 비교가 유지된다.
    """
    if anchor not in ANCHORS:
        raise ValueError(f"모르는 앵커: {anchor!r} (있는 것: {list(ANCHORS)})")
    style = (style or ILLUST_STYLE).rstrip(".")
    if anchor == "anime":
        head = f"{ANIME_ANCHOR}. "
    else:
        head = ANCHORS[anchor]
        style = style[0].upper() + style[1:] if (anchor == "none" and style) else style
    return f"{head}{style}. {character.rstrip('.')}. {frame or ILLUST_FRAME}"


def zitani_graph(prompt: str, seed: int, width: int, height: int,
                 steps: int = ZITANI_STEPS, prefix: str = "illust") -> dict:
    """`minimal-char-studio` 의 `_build_zimage` 배선 그대로."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ZITANI_CKPT}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": ZIMAGE_CLIP, "type": "lumina2"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": ZIMAGE_VAE}},
        "10": {"class_type": "ModelSamplingAuraFlow",
               "inputs": {"model": ["1", 0], "shift": ZITANI_SHIFT}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": ""}},
        "6": {"class_type": "EmptySD3LatentImage",
              "inputs": {"width": width, "height": height, "batch_size": 1}},
        "7": {"class_type": "KSampler", "inputs": {
            "model": ["10", 0], "positive": ["4", 0], "negative": ["5", 0],
            "latent_image": ["6", 0], "seed": int(seed), "steps": int(steps),
            "cfg": ZITANI_CFG, "sampler_name": ZITANI_SAMPLER,
            "scheduler": ZITANI_SCHEDULER, "denoise": 1.0}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": prefix}},
    }


def klein_edit_graph(prompt: str, image: str, seed: int, width: int = SD_SIZE,
                     height: int = SD_SIZE, steps: int = KLEIN_EDIT_STEPS,
                     prefix: str = "sd") -> dict:
    """`minimal-char-studio` 의 `_build_klein_edit_legacy` 배선 그대로.

    **참조는 conditioning 쪽(`ReferenceLatent`)으로만 들어간다.** 샘플러의 latent 는
    참조가 아니라 `EmptyFlux2LatentImage` 다 — 그 레인이 주석으로 못 박아 뒀다.
    """
    return {
        "1": {"class_type": "UNETLoader",
              "inputs": {"unet_name": KLEIN_UNET, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": KLEIN_CLIP, "type": "flux2"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": KLEIN_VAE}},
        "4": {"class_type": "LoadImage", "inputs": {"image": image}},
        "5": {"class_type": "VAEEncode", "inputs": {"pixels": ["4", 0], "vae": ["3", 0]}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "7": {"class_type": "ReferenceLatent",
              "inputs": {"conditioning": ["6", 0], "latent": ["5", 0]}},
        "8": {"class_type": "EmptyFlux2LatentImage",
              "inputs": {"width": width, "height": height, "batch_size": 1}},
        "9": {"class_type": "Flux2KleinKSamplerExperimental", "inputs": {
            "model": ["1", 0], "positive": ["7", 0], "latent_image": ["8", 0],
            "steps": int(steps), "seed": int(seed), "denoise": 1.0,
            "base_shift": 0.5, "max_shift": 1.15}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["9", 0], "vae": ["3", 0]}},
        "11": {"class_type": "SaveImage", "inputs": {"images": ["10", 0], "filename_prefix": prefix}},
    }
