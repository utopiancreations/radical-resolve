#!/usr/bin/env python3
"""
Radical Resolve — v1.1 continuation pass.

Takes the v1 LoRA adapter as the starting point and runs a short, low-LR
SFT pass on radical_resolve_v1_bonus.jsonl only (49 samples). The point
is NOT to retrain — it's to give the bonus material a measurable nudge
that's distinct from v2 (which integrates the same samples into a fresh
distillation).

Hyperparameters chosen for a small-corpus continuation:
  - batch_size=1, grad_accum=1 → 1 grad step per sample
  - epochs=4 → ~196 grad updates across the 49 samples
  - LR=1e-5 → half of v1's 2e-5, gentle reshaping rather than reshuffling

Run after train_radical_resolve_e4b.py completes:
    CUDA_VISIBLE_DEVICES=2 python3 train_radical_resolve_e4b_v1_1.py
"""
import os, sys, json, argparse
from pathlib import Path

os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("PYTORCH_HIP_ALLOC_CONF", "expandable_segments:True")
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")

import torch
from datasets import Dataset
from transformers import AutoTokenizer, AutoModelForImageTextToText
from peft import PeftModel
from trl import SFTConfig, SFTTrainer

PROJECT_DIR = Path(__file__).parent.parent
BONUS_FILE = PROJECT_DIR / "data" / "radical_resolve_v1_bonus.jsonl"
BASE_MODEL_PATH = Path.home() / "models" / "gemma-4-E4B-it"
V1_ADAPTER_DIR = PROJECT_DIR / "output" / "radical-resolve-gemma-e4b" / "final-adapter"
OUTPUT_DIR = PROJECT_DIR / "output" / "radical-resolve-gemma-e4b-v1.1"
FINAL_ADAPTER_DIR = OUTPUT_DIR / "final-adapter"

DEFAULT_EPOCHS = 4
DEFAULT_BATCH_SIZE = 1
DEFAULT_GRAD_ACCUM = 1
DEFAULT_LR = 1e-5
DEFAULT_MAX_SEQ_LEN = 2048


def load_dataset(data_file: Path) -> Dataset:
    examples = []
    with open(data_file) as f:
        for line in f:
            examples.append(json.loads(line))
    print(f"Loaded {len(examples)} bonus examples from {data_file.name}")
    return Dataset.from_list(examples)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS)
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--grad-accum", type=int, default=DEFAULT_GRAD_ACCUM)
    parser.add_argument("--lr", type=float, default=DEFAULT_LR)
    parser.add_argument("--max-seq-len", type=int, default=DEFAULT_MAX_SEQ_LEN)
    parser.add_argument("--base-model", type=str, default=str(BASE_MODEL_PATH))
    parser.add_argument("--v1-adapter", type=str, default=str(V1_ADAPTER_DIR))
    args = parser.parse_args()

    print("=" * 60)
    print("Radical Resolve v1.1 — continuation on bonus only")
    print("=" * 60)

    if not torch.cuda.is_available():
        sys.exit("ERROR: no GPU")
    n_gpus = torch.cuda.device_count()
    print(f"\nGPUs visible: {n_gpus} (CUDA_VISIBLE_DEVICES={os.environ.get('CUDA_VISIBLE_DEVICES', 'unset')})")

    if not BONUS_FILE.exists():
        sys.exit(f"ERROR: {BONUS_FILE} missing")
    if not Path(args.v1_adapter).exists():
        sys.exit(f"ERROR: v1 adapter missing at {args.v1_adapter} — did v1 actually finish?")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    FINAL_ADAPTER_DIR.mkdir(parents=True, exist_ok=True)

    print("\nLoading bonus dataset...")
    ds = load_dataset(BONUS_FILE)
    # 49 samples — too small for a real eval split. Use train-only.
    train_ds = ds

    print(f"\nLoading tokenizer from {args.base_model}...")
    tok = AutoTokenizer.from_pretrained(args.base_model, trust_remote_code=False)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    def fmt(ex):
        return {"text": tok.apply_chat_template(
            ex["messages"], tokenize=False, add_generation_prompt=False,
        )}
    train_ds = train_ds.map(
        fmt, remove_columns=[c for c in train_ds.column_names if c != "messages"]
    )

    print(f"\nLoading Gemma 4 E4B base in BF16...")
    base = AutoModelForImageTextToText.from_pretrained(
        args.base_model,
        torch_dtype=torch.bfloat16,
        device_map={"": 0},
        trust_remote_code=False,
    )
    base.config.use_cache = False
    if hasattr(base, "enable_input_require_grads"):
        base.enable_input_require_grads()

    print(f"\nLoading v1 adapter from {args.v1_adapter} (is_trainable=True)...")
    model = PeftModel.from_pretrained(base, args.v1_adapter, is_trainable=True)
    model.print_trainable_parameters()

    print(f"\nContinuation: epochs={args.epochs}  lr={args.lr}  "
          f"batch={args.batch_size}  grad_accum={args.grad_accum}")

    targs = SFTConfig(
        output_dir=str(OUTPUT_DIR),
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        gradient_accumulation_steps=args.grad_accum,
        learning_rate=args.lr,
        warmup_ratio=0.05,
        lr_scheduler_type="cosine",
        bf16=True,
        logging_steps=5,
        logging_dir=str(OUTPUT_DIR / "logs"),
        save_strategy="epoch",
        save_total_limit=2,
        eval_strategy="no",
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
        train_dataset=train_ds,
        processing_class=tok,
    )

    trainer.train()

    print(f"\nSaving v1.1 adapter to {FINAL_ADAPTER_DIR}")
    model.save_pretrained(str(FINAL_ADAPTER_DIR))
    tok.save_pretrained(str(FINAL_ADAPTER_DIR))
    with open(FINAL_ADAPTER_DIR / "training_metadata.json", "w") as f:
        json.dump({
            "project": "radical-resolve-v1.1",
            "started_from": str(args.v1_adapter),
            "base_model": args.base_model,
            "bonus_dataset": str(BONUS_FILE),
            "epochs": args.epochs, "lr": args.lr,
            "batch_size": args.batch_size, "grad_accum": args.grad_accum,
            "max_seq_len": args.max_seq_len,
            "train_examples": len(train_ds),
            "final_train_loss": trainer.state.log_history[-1].get("train_loss", "N/A"),
        }, f, indent=2)

    print("\n" + "=" * 60)
    print("RADICAL RESOLVE v1.1 CONTINUATION COMPLETE")
    print(f"  Adapter: {FINAL_ADAPTER_DIR}")
    print("=" * 60)


if __name__ == "__main__":
    main()
