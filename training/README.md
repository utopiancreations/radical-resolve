# Training the Radical Resolve model

The on-device LLM shipped in this app is a LoRA fine-tune of
[unsloth/gemma-4-E4B-it](https://huggingface.co/unsloth/gemma-4-E4B-it) on a
custom radical-acceptance corpus distilled from the
[Helios](https://github.com/utopiancreations/helios) project.

This directory contains the **exact scripts** that produced each shipped model.
Data and model weights are intentionally not in git — data because it contains
the maintainer's personal archives, weights because they're 3 GB+ and live on
Cloudflare R2 for download by the app.

## Pipeline

```
v4 Helios soul stories (15k chat-template samples, already pillar-weighted)
  │
  ├─ filter_for_radical_resolve.py    (drop LNT/blockchain/tokenomics noise)
  │     → radical_resolve_v1.jsonl   (14,262 kept, 740 dropped)
  │
  ├─ generate_bonus_from_drafts.py    (auroara lesson/practice/story drafts
  │                                    → multi-turn dialogues via Helios soul)
  │     → radical_resolve_v1_bonus.jsonl   (49 samples)
  │
  └─ scrub_first_person_for_v3.py     (drop assistant messages that fabricate
                                       lived experiences: "I remember when…",
                                       "back in 2017 I…", "I've been there")
        → radical_resolve_v3.jsonl   (8,376 kept after scrub)
```

## Training scripts

| Script | Output | Recipe |
|---|---|---|
| `train_radical_resolve_e4b.py` | `output/radical-resolve-gemma-e4b/` (v1) | Fresh SFT on v1 corpus, LoRA r=64 α=128, LR 2e-5, 3 epochs |
| `train_radical_resolve_e4b_v1_1.py` | `output/radical-resolve-gemma-e4b-v1.1/` | Continuation on bonus only, LR 1e-5, 4 epochs, on top of v1 adapter |
| `train_radical_resolve_e4b_v2.py` | `output/radical-resolve-gemma-e4b-v2/` | Fresh SFT on v1 + bonus, same recipe as v1 |
| `train_radical_resolve_e4b_v3.py` | `output/radical-resolve-gemma-e4b-v3/` | **Ship candidate.** Fresh SFT on scrubbed v3 corpus, same recipe |
| `post_v1_pipeline.sh` | — | Overnight sequencer used during initial training to chain v1 → v1.1 → v2 |
| `smoke_test_adapters.py` | stdout | Loads each adapter, runs probes with the production system prompts |

## LoRA target modules

PEFT can't inject into Gemma 4's vision/audio towers (they wrap Linear in
`Gemma4ClippableLinear`, which PEFT doesn't recognize). All training scripts
use a regex scoped to the language-model decoder only:

```python
target_modules = r"^model\.language_model\.layers\.\d+\." \
                 r"(?:self_attn|mlp)\." \
                 r"(?:q_proj|k_proj|v_proj|o_proj|gate_proj|up_proj|down_proj)$"
```

This yields ~147 M trainable params on the 8 B base, ~1.8% trainable.

## Why v3 supersedes v1 and v2

Smoke-testing each adapter against the same prompts:

- **v1** — autobiographical voice, frequently fabricates lived experiences
  ("when I was in that exact spot — unemployed, facing the unknown with a
  baby arriving — I had this moment where I just stopped spinning"). Rejected.
- **v1.1** — tight present-tense grounding, no fabrications. Good for SOS.
- **v2** — blends v1's depth with v1.1's anchoring, but still occasionally
  slips ("I remember a situation where my landlord, who was part of a large
  management company…").
- **v3** — same recipe as v2 but trained on the scrubbed corpus. With the
  production system prompts (see `assets/prompts/`), produces zero fabricated
  experiences in smoke tests. This is what ships.

The scrub revealed **41.5% of the v1+bonus corpus was contaminated** with
first-person experience claims — the cost of distilling from Josh's own
autobiographical archives. The v3 scrub gets us to a clean 8,376-sample
corpus while preserving every healing pillar in adequate volume.

## To retrain from scratch

You will need:
1. A Linux rig with at least one 24 GB+ GPU (we used 1× AMD Radeon AI PRO R9700)
2. ROCm 7.2+ (or CUDA equivalent) + Python 3.12 + venv with `transformers`,
   `peft`, `trl`, `datasets`, `accelerate`
3. The `radical_resolve_v1.jsonl` source dataset (not in this repo — derived
   from the Helios v4 soul corpus)

Then:

```bash
python3 filter_for_radical_resolve.py        # v1 corpus
python3 generate_bonus_from_drafts.py        # bonus (needs Helios soul on :8092)
python3 scrub_first_person_for_v3.py         # v3 corpus
CUDA_VISIBLE_DEVICES=0 python3 train_radical_resolve_e4b_v3.py
```

After training, merge the LoRA into base, convert to GGUF Q5_K_M, upload to
R2, and update `lib/config/model_config.dart` with the new URL + sha256.

## License

Same as the parent app — Apache 2.0 for code; the underlying Gemma 4 E4B
weights are under Google's Gemma license; the training data is private to
the maintainer.
