"""전신 일러스트와 SD 변환의 그래프 · 문자열.

**배선은 `2dAnim/minimal-char-studio` 에서 그대로 가져왔다** (§27.22).
그 스튜디오가 이미 검증한 것을 다시 짜지 않는다 —
`mcs/comfy/workflows.py` 의 `_build_zimage` 와 `mcs/comfy/edits.py` 의
`_build_klein_edit_legacy` 다.

# 인스턴스가 하나다 — 그리고 그것이 맞다

그 스튜디오는 `instance="modern"`(8001)로 적어 뒀는데 **지금 8001 은 안 떠 있고
8000 만 떠 있다.** 8000 에 필요한 것이 전부 있는지 실제로 물어봤다 (2026-08-08):

    CheckpointLoaderSimple · CLIPLoader(lumina2 · flux2) · ModelSamplingAuraFlow ·
    KSampler(res_multistep) · EmptySD3LatentImage · Flux2KleinKSamplerExperimental
    kompostoZITANI_zitANI_fp8 · z_image_turbo_vae · qwen_3_4b_bf16_fp8_scaled

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
그래서 배경·품질 통제는 **긍정 서술로만** 한다. 초상 레인의 §27.9 와 같은 결론이다.
"""

from __future__ import annotations

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

#: 전신 시트의 틀. **`water_bishoujo` 가 낸 그림이 이 모양이다** —
#: 전신 정면 · 흰 배경 · 수채 · 발밑에 옅은 그림자 하나.
#:
#: **「water」는 물 속성이 아니라 수채(watercolour)였다.** 폴더 이름만 보고
#: 물 원소로 읽으면 안 된다 (§27.22).
#:
#: 초상 레인의 `FRAME` 과 같은 자리이고 같은 이유로 코드가 고정한다 —
#: **GPT 에게 구도를 맡기면 인물마다 구도가 달라진다** (§27.9.1).
ILLUST_FRAME = (
    "A full body character reference sheet of one single person standing upright and "
    "still, the whole figure from the top of the head down to the shoes held inside the "
    "frame with clear empty margin above and below, the arms hanging down at the sides. "
    "Seen from the front."
)

#: 화풍. **초상의 `STYLE` 과 다른 문자열이다** — 저쪽은 타이틀의 게임 키아트를
#: 베낀 것이고(§27.6) 이쪽은 `water_bishoujo` 가 낸 수채 캐릭터 원화다.
#: **둘을 섞지 않는다.** 섞으면 어느 쪽도 아닌 것이 나온다.
ILLUST_STYLE = (
    "Soft watercolour and ink character illustration, clean dark linework over pale "
    "translucent washes, muted restrained colour, the paint pooling and drying unevenly "
    "inside the shapes."
)

#: 배경. **긍정 서술로만 한다** — cfg 1.0 이라 네거티브가 수식에서 사라진다.
ILLUST_BACKGROUND = (
    "The background is plain flat white all the way to every edge, with one faint pale "
    "grey shadow pooled on the ground under the shoes."
)

#: SD 변환. **레퍼런스의 그림체를 따라가는 것이 일이다** (`PROMPTS.md` §6-1 · §6-3) —
#: Klein 은 그림체 사전분포가 강해 탐색에는 못 쓰지만 **레퍼런스 추종은 잘 한다.**
#:
#: `side` 를 쓰지 않는다. §6-4 실측 — `slightly angled side view` 에서 모델은
#: `side view` 만 듣고 `slightly angled` 를 버린다. **방향은 복합어 안쪽에 넣는다.**
SD_CONVERT = (
    "Redraw this same character as one small chibi game sprite, keeping the same face, "
    "the same hair, the same clothes, the same colours and the same drawing style. "
    "The head is as large as the whole rest of the body. The whole figure stands inside "
    "the frame with empty margin around it. Seen from a three-quarter right view. "
    "The background is plain flat white all the way to every edge."
)


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


def compose_illust(look: str) -> str:
    """전신 일러스트 프롬프트. **틀과 화풍은 코드, 사람은 GPT** (§27.9.1)."""
    return " ".join(p.strip() for p in [
        ILLUST_STYLE, ILLUST_FRAME, look, ILLUST_BACKGROUND] if p.strip())
