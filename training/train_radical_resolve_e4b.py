#!/usr/bin/env python3
"""
Radical Resolve — Gemma 4 E4B LoRA fine-tune.

Distills Josh's radical acceptance / community / kindness voice into the
Gemma 4 E4B base for the on-device iOS app at github.com/utopiancreations/
radical-resolve. Dataset: radical_resolve_v1.jsonl (filtered subset of
soul_stories_weighted_v4.jsonl with all LNT/tokenomics content removed).

Differences from train_v4_moe.py:
  - Base: unsloth/gemma-4-E4B-it (dense multimodal, text path only)
  - No QLoRA — E4B in BF16 fits one R9700 (32 GB) with room to spare
  - Pin to single GPU via CUDA_VISIBLE_DEVICES so we don't fight the
    production helios-soul-v4 chat backend on :8092
  - LR 2e-5 per the radical-resolve Phase 2 plan (preserve base structure)

Usage:
    CUDA_VISIBLE_DEVICES=2 python train_radical_resolve_e4b.py
"""
import os, sys, json, argparse
from pathlib import Path

os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("PYTORCH_HIP_ALLOC_CONF", "expandable_segments:True")
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")

import torch
from datasets import Dataset
from transformers import AutoTokenizer, AutoConfig, AutoModelForImageTextToText
from peft import LoraConfig, get_peft_model
from trl import SFTConfig, SFTTrainer

PROJECT_DIR = Path(__file__).parent.parent
DATA_FILE = PROJECT_DIR / "data" / "radical_resolve_v1.jsonl"
BASE_MODEL_PATH = Path.home() / "models" / "gemma-4-E4B-it"
OUTPUT_DIR = PROJECT_DIR / "output" / "radical-resolve-gemma-e4b"
FINAL_ADAPTER_DIR = OUTPUT_DIR / "final-adapter"

DEFAULT_EPOCHS = 3
DEFAULT_BATCH_SIZE = 2
DEFAULT_GRAD_ACCUM = 4
DEFAULT_LR = 2e-5
DEFAULT_MAX_SEQ_LEN = 2048
DEFAULT_LORA_R = 64
DEFAULT_LORA_ALPHA = 128


def load_dataset(data_file: Path) -> Dataset:
    examples = []
    with open(data_file) as f:
        for line in f:
            examples.append(json.loads(line))
    print(f"Loaded {len(examples)} training examples from {data_file.name}")
    from collections import Counter
    pillars = Counter(ex.get("pillar", "?") for ex in examples)
    for p, c in pillars.most_common():
        print(f"  {c:5d}  {p}")
    return Dataset.from_list(examples)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS)
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--grad-accum", type=int, default=DEFAULT_GRAD_ACCUM)
    parser.add_argument("--lr", type=float, default=DEFAULT_LR)
    parser.add_argument("--max-seq-len", type=int, default=DEFAULT_MAX_SEQ_LEN)
    parser.add_argument("--lora-r", type=int, default=DEFAULT_LORA_R)
    parser.add_argument("--lora-alpha", type=int, default=DEFAULT_LORA_ALPHA)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--base-model", type=str, default=str(BASE_MODEL_PATH))
    args = parser.parse_args()

    print("=" * 60)
    print("Radical Resolve — Gemma 4 E4B BF16 LoRA")
    print("=" * 60)

    if not torch.cuda.is_available():
        print("ERROR: no GPU"); sys.exit(1)
    n_gpus = torch.cuda.device_count()
    print(f"\nGPUs visible: {n_gpus} (CUDA_VISIBLE_DEVICES={os.environ.get('CUDA_VISIBLE_DEVICES', 'unset')})")
    for i in range(n_gpus):
        m = torch.cuda.get_device_properties(i).total_memory / 1024**3
        free, _ = torch.cuda.mem_get_info(i)
        print(f"  GPU {i}: {torch.cuda.get_device_name(i)}  total {m:.1f} GB, free {free/1024**3:.1f} GB")

    if not DATA_FILE.exists():
        print(f"ERROR: {DATA_FILE} missing — run scripts/filter_for_radical_resolve.py first"); sys.exit(1)
    base = Path(args.base_model)
    if not base.exists():
        print(f"ERROR: base weights missing at {base}"); sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    FINAL_ADAPTER_DIR.mkdir(parents=True, exist_ok=True)

    print("\nLoading dataset...")
    ds = load_dataset(DATA_FILE)
    split = ds.train_test_split(test_size=0.05, seed=42)
    train_ds, eval_ds = split["train"], split["test"]
    print(f"  train={len(train_ds)}  eval={len(eval_ds)}")

    print(f"\nLoading tokenizer from {base}...")
    tok = AutoTokenizer.from_pretrained(str(base), trust_remote_code=False)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    def fmt(ex):
        return {"text": tok.apply_chat_template(
            ex["messages"], tokenize=False, add_generation_prompt=False,
        )}
    train_ds = train_ds.map(fmt, remove_columns=[c for c in train_ds.column_names if c != "messages"])
    eval_ds = eval_ds.map(fmt, remove_columns=[c for c in eval_ds.column_names if c != "messages"])

    sample_text = train_ds[0]["text"]
    print(f"\nSample formatted example (first 400 chars):\n{sample_text[:400]}\n...")

    print(f"\nLoading base model in BF16 (text path only)...")
    # Gemma 4 is multimodal (Gemma4ForConditionalGeneration). For text-only
    # SFT we still load the full class — vision/audio paths simply never
    # see input since training batches are text-only. Loading via
    # AutoModelForImageTextToText is the supported route for the gemma4
    # model_type.
    model = AutoModelForImageTextToText.from_pretrained(
        str(base),
        torch_dtype=torch.bfloat16,
        device_map={"": 0},
        trust_remote_code=False,
    )

    model.config.use_cache = False
    if hasattr(model, "enable_input_require_grads"):
        model.enable_input_require_grads()

    print(f"\nApplying LoRA r={args.lora_r} alpha={args.lora_alpha} on text decoder...")
    # Regex scoped to model.language_model.layers.* so we only touch the LM
    # path. The vision_tower and audio_tower wrap their projections in
    # Gemma4ClippableLinear (a non-Linear subclass PEFT can't inject), and we
    # don't want voice adaptation tied to vision/audio anyway.
    lm_proj_pattern = (
        r"^model\.language_model\.layers\.\d+\."
        r"(?:self_attn|mlp)\."
        r"(?:q_proj|k_proj|v_proj|o_proj|gate_proj|up_proj|down_proj)$"
    )
    lora_conf = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        target_modules=lm_proj_pattern,
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM",
    )
    model = get_peft_model(model, lora_conf, autocast_adapter_dtype=False)
    model.print_trainable_parameters()

    eff = args.batch_size * args.grad_accum
    print(f"\nEffective batch = {args.batch_size} x {args.grad_accum} grad_accum = {eff}")
    print(f"  epochs={args.epochs}  lr={args.lr}  max_seq_len={args.max_seq_len}")

    targs = SFTConfig(
        output_dir=str(OUTPUT_DIR),
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=1,
        eval_accumulation_steps=1,
        gradient_accumulation_steps=args.grad_accum,
        learning_rate=args.lr,
        warmup_ratio=0.05,
        lr_scheduler_type="cosine",
        bf16=True,
        logging_steps=10,
        logging_dir=str(OUTPUT_DIR / "logs"),
        save_strategy="steps",
        save_steps=100,
        save_total_limit=3,
        eval_strategy="epoch",
        max_length=args.max_seq_len,
        dataset_text_field="text",
        report_to="none",
        gradient_checkpointing=True,
        gradient_checkpointing_kwargs={"use_reentrant": False},
        optim="adamw_torch",
        dataloader_pin_memory=False,
    )

    trainer = SFTTrainer(
        model=model, args=targs,
        train_dataset=train_ds, eval_dataset=eval_ds,
        processing_class=tok,
    )

    if args.resume:
        ckpts = sorted(OUTPUT_DIR.glob("checkpoint-*"))
        if ckpts:
            print(f"Resuming from {ckpts[-1]}")
            trainer.train(resume_from_checkpoint=str(ckpts[-1]))
        else:
            trainer.train()
    else:
        trainer.train()

    print(f"\nSaving final adapter to {FINAL_ADAPTER_DIR}")
    model.save_pretrained(str(FINAL_ADAPTER_DIR))
    tok.save_pretrained(str(FINAL_ADAPTER_DIR))
    with open(FINAL_ADAPTER_DIR / "training_metadata.json", "w") as f:
        json.dump({
            "project": "radical-resolve",
            "base_model": str(base),
            "dataset": str(DATA_FILE),
            "lora_r": args.lora_r, "lora_alpha": args.lora_alpha,
            "epochs": args.epochs, "lr": args.lr,
            "max_seq_len": args.max_seq_len,
            "train_examples": len(train_ds),
            "eval_examples": len(eval_ds),
            "final_train_loss": trainer.state.log_history[-1].get("train_loss", "N/A"),
        }, f, indent=2)

    print("\n" + "=" * 60)
    print("RADICAL RESOLVE TRAINING COMPLETE")
    print(f"  Adapter: {FINAL_ADAPTER_DIR}")
    print(f"  Next: scripts/merge_lora_v4.py → GGUF Q5_K_M → R2 upload")
    print("=" * 60)


if __name__ == "__main__":
    main()
