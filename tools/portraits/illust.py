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

#: 검수용 후보. **값 하나를 바꾸는 자리라 갈아 끼우기가 싸다.**
STYLE_CANDIDATES: dict[str, str] = {
    "wash": ILLUST_STYLE,
    "ink": (
        "Firm dark ink contours with dry-brush breaks, flat translucent watercolour fills "
        "left pale at the edges, faded indigo, rust and bone white"
    ),
    "soft": (
        "Soft graphite contours under wet watercolour bleeding past the line, colour "
        "settling into grainy pools, dusty green, warm grey and muted plum"
    ),
}


def compose_illust(character: str, style: str = "") -> str:
    """원본 조립 그대로. **갈아 끼우는 것은 `character` 한 칸뿐이다** (§27.24).

    순서가 곧 가중치다 — 앵커, 화풍, 인물, 규격. **바꾸지 마라.**
    품질 태그는 **안 붙인다** — 원본이 A/B 재고 사용자 결정으로 뺐다.
    """
    style = (style or ILLUST_STYLE).rstrip(".")
    return f"{ANIME_ANCHOR}. {style}. {character.rstrip('.')}. {ILLUST_FRAME}"


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
