#!/usr/bin/env bash
# Overnight sequencer for Radical Resolve.
#
# Watches the v1 training log until it sees the completion marker (or a hard
# failure), then sequentially runs:
#   1. v1.1 continuation (10 min) on the bonus corpus, on top of the v1 adapter
#   2. v2 fresh SFT (~4 hr) on the combined v1 + bonus corpus
#
# All output goes to /home/josh/helios-distillation/output/post_v1_pipeline.log
# plus the per-run train.log files in each output subdir.
#
# Launch:
#   cd /home/josh/helios-distillation
#   nohup bash scripts/post_v1_pipeline.sh > output/post_v1_pipeline.log 2>&1 &

set -u
cd /home/josh/helios-distillation

source venv/bin/activate

V1_LOG="output/radical-resolve-gemma-e4b/train.log"
V1_ADAPTER_META="output/radical-resolve-gemma-e4b/final-adapter/training_metadata.json"
V11_DIR="output/radical-resolve-gemma-e4b-v1.1"
V2_DIR="output/radical-resolve-gemma-e4b-v2"
V2_DATA="data/radical_resolve_v2_combined.jsonl"

mkdir -p "$V11_DIR" "$V2_DIR"

ts() { date "+%Y-%m-%d %H:%M:%S"; }

echo "[$(ts)] post_v1_pipeline starting (pid $$)"
echo "[$(ts)] waiting for v1 completion marker in $V1_LOG"

# 8 hour deadline as a safety net
deadline=$((SECONDS + 28800))
while [ $SECONDS -lt $deadline ]; do
  if grep -q "RADICAL RESOLVE TRAINING COMPLETE" "$V1_LOG" 2>/dev/null; then
    echo "[$(ts)] v1 completion marker seen"
    break
  fi
  if grep -qE "Traceback|RuntimeError|OutOfMemoryError|HIPError|CUDA error|FAILED" "$V1_LOG" 2>/dev/null; then
    echo "[$(ts)] FAIL: v1 hit an error signature; aborting pipeline"
    grep -E "Traceback|RuntimeError|OutOfMemoryError|HIPError|CUDA error|FAILED" "$V1_LOG" | tail -5
    exit 1
  fi
  sleep 60
done

if [ ! -f "$V1_ADAPTER_META" ]; then
  echo "[$(ts)] FAIL: v1 marker not seen and adapter metadata missing; aborting"
  exit 1
fi

echo "[$(ts)] v1 adapter present at $V1_ADAPTER_META"

# Step 1 — v1.1 continuation on bonus only
echo "[$(ts)] launching v1.1 continuation"
CUDA_VISIBLE_DEVICES=2 python3 scripts/train_radical_resolve_e4b_v1_1.py \
  > "$V11_DIR/train.log" 2>&1
v11_rc=$?
echo "[$(ts)] v1.1 finished with exit code $v11_rc"
if [ $v11_rc -ne 0 ]; then
  echo "[$(ts)] WARN: v1.1 failed — continuing to v2 regardless (independent run)"
fi

# Step 2 — build combined dataset for v2
echo "[$(ts)] building combined dataset for v2"
cat data/radical_resolve_v1.jsonl data/radical_resolve_v1_bonus.jsonl > "$V2_DATA"
combined_lines=$(wc -l < "$V2_DATA")
echo "[$(ts)] $V2_DATA has $combined_lines lines"

# Step 3 — v2 fresh SFT on combined corpus
echo "[$(ts)] launching v2 (fresh SFT, ~4 hr)"
CUDA_VISIBLE_DEVICES=2 python3 scripts/train_radical_resolve_e4b_v2.py \
  > "$V2_DIR/train.log" 2>&1
v2_rc=$?
echo "[$(ts)] v2 finished with exit code $v2_rc"

echo "[$(ts)] post_v1_pipeline done"
exit 0
