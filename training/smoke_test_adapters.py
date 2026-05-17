#!/usr/bin/env python3
"""
Smoke test for Radical Resolve adapters. Loads base Gemma 4 E4B once,
swaps each adapter in, and runs the same probe prompts through each so
we can eyeball differences between v1, v1.1, and v2.

Usage:
    CUDA_VISIBLE_DEVICES=1 python3 smoke_test_adapters.py [v1|v1.1|v2|all]
"""
import os, sys, json, gc
from pathlib import Path

os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("PYTORCH_HIP_ALLOC_CONF", "expandable_segments:True")

import torch
from transformers import AutoTokenizer, AutoModelForImageTextToText
from peft import PeftModel

BASE = Path.home() / "models" / "gemma-4-E4B-it"
PROJ = Path("/home/josh/helios-distillation/output")
ADAPTERS = {
    "v1":   PROJ / "radical-resolve-gemma-e4b"      / "final-adapter",
    "v1.1": PROJ / "radical-resolve-gemma-e4b-v1.1" / "final-adapter",
    "v2":   PROJ / "radical-resolve-gemma-e4b-v2"   / "final-adapter",
    "v3":   PROJ / "radical-resolve-gemma-e4b-v3"   / "final-adapter",
}

_APP_PROMPTS_DIR = Path.home() / "radical-resolve" / "assets" / "prompts"


def _load_app_system(asset_id: str) -> str:
    """Pull the live system instruction from the shipped Flutter assets."""
    path = _APP_PROMPTS_DIR / f"{asset_id}.json"
    with open(path) as f:
        return json.load(f)["systemInstruction"]


PROBES = [
    {
        "name": "SOS / loss + fear  (sos_grounding system prompt)",
        "messages": [
            {"role": "system", "content": _load_app_system("sos_grounding")},
            {"role": "user", "content":
             "I just got laid off and I have a kid on the way. I don't know how "
             "I'm going to make this work."},
        ],
    },
    {
        "name": "Peaceful Conflict / landlord  (analytical_planner system prompt)",
        "messages": [
            {"role": "system", "content": _load_app_system("analytical_planner")},
            {"role": "user", "content":
             "My landlord is trying to raise my rent way past what's legal and I'm "
             "scared to push back. What do I do?"},
        ],
    },
]

GEN_KWARGS = dict(
    max_new_tokens=300,
    do_sample=True,
    temperature=0.7,
    top_p=0.92,
    repetition_penalty=1.07,
)


def load_base():
    print(f"Loading base from {BASE}...")
    model = AutoModelForImageTextToText.from_pretrained(
        str(BASE), torch_dtype=torch.bfloat16, device_map={"": 0},
    )
    model.config.use_cache = True
    model.eval()
    return model


def generate(model, tok, messages):
    prompt = tok.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=True
    )
    inputs = tok(prompt, return_tensors="pt").to(model.device)
    with torch.inference_mode():
        out = model.generate(**inputs, **GEN_KWARGS,
                             pad_token_id=tok.pad_token_id or tok.eos_token_id)
    new_tokens = out[0][inputs["input_ids"].shape[1]:]
    return tok.decode(new_tokens, skip_special_tokens=True).strip()


def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["all"]
    if "all" in targets:
        targets = list(ADAPTERS.keys())

    tok = AutoTokenizer.from_pretrained(str(BASE))
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    base = load_base()

    for label in targets:
        path = ADAPTERS[label]
        if not path.exists():
            print(f"\n=== {label}: adapter not found at {path} (skipping) ===")
            continue
        print(f"\n{'='*70}\nADAPTER: {label}  ({path})\n{'='*70}")
        model = PeftModel.from_pretrained(base, str(path))
        model.eval()
        for probe in PROBES:
            print(f"\n--- {probe['name']} ---")
            print(f"USER: {probe['messages'][-1]['content']}")
            try:
                reply = generate(model, tok, probe["messages"])
            except Exception as e:
                reply = f"GENERATION ERROR: {e}"
            print(f"ASSISTANT: {reply}")
        # Unload adapter before next iteration
        model = model.unload()
        del model
        gc.collect()
        torch.cuda.empty_cache()


if __name__ == "__main__":
    main()
