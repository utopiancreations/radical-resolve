#!/usr/bin/env python3
"""
Generate bonus training samples from auroara content drafts for Radical Resolve.

Uses helios-soul-v4 (:8092) as the teacher — already carries Josh's voice and
the radical acceptance frame. For each source draft, produces N multi-turn
dialogues in the same chat-template JSONL shape as radical_resolve_v1.jsonl
so we can concat directly into a future v2 corpus.

Run while v1 training is in flight — teacher lives on GPUs 0+1, trainer on
GPU 2, no interference.
"""
import json
import re
import sys
import time
from pathlib import Path
import urllib.request

DRAFTS_DIR = Path.home() / ".openclaw/workspace/auroara_content_drafts"
OUTPUT = Path("/home/josh/helios-distillation/data/radical_resolve_v1_bonus.jsonl")
LLM_URL = "http://127.0.0.1:8092/v1/chat/completions"
DIALOGUES_PER_SOURCE = 10
REQUEST_TIMEOUT = 180

SOURCES = [
    ("lesson_2_2-the-art-of-letting-go.md", "Radical Acceptance",
     "Radical Acceptance: The practice of releasing what no longer serves you, "
     "discerning sacred holding from heavy holding."),
    ("practice_guide_breathwork.md", "Peaceful Conflict Resolution",
     "Peaceful Conflict Resolution: Returning to the breath as a ground-truth "
     "anchor in moments of overwhelm, before responding to anything outside you."),
    ("community_post_the_coming_together.md", "Collaboration & Community",
     "Collaboration & Community: We are not alone in our healing — showing up "
     "for one another is the practice."),
    ("story_beyond_the_deconstruction.md", "Personal Growth",
     "Personal Growth: The unraveling of old structures is the clearing that "
     "lets the next self arrive."),
    ("story_finding_light_in_the_dark.md", "Radical Acceptance",
     "Radical Acceptance: Even at the bottom there is something true to meet. "
     "We don't bypass the dark — we sit with it until it shifts."),
]


GEN_INSTRUCTION = """You are generating training data for a radical acceptance \
companion app. Given a SOURCE TEACHING below, write {n} distinct multi-turn \
dialogues. Each dialogue must:

- Be 2 to 4 turns total (user → assistant → optional user → optional assistant)
- Open with a user message expressing real distress, confusion, or a question \
that the SOURCE TEACHING directly answers
- Have the assistant respond in a warm, grounded, radical-acceptance voice — \
NOT clinical, NOT prescriptive — drawing from the SOURCE TEACHING but in \
fresh words, never quoting it verbatim
- Avoid generic advice like "talk to a therapist" or "remember to be kind to \
yourself" — the assistant should engage with the SPECIFIC situation
- Be emotionally diverse across the {n} dialogues (anger, grief, numbness, \
fear, doubt, hope, exhaustion, etc.)

Output ONLY a JSON array, no prose, no markdown fences. Each item must be:

{{"messages": [
  {{"role": "user", "content": "..."}},
  {{"role": "assistant", "content": "..."}}
]}}

SOURCE TEACHING:
---
{source}
---

Return the JSON array of {n} dialogues now."""


def call_llm(prompt: str) -> str:
    payload = {
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.85,
        "top_p": 0.92,
        "max_tokens": 4096,
        "stream": False,
    }
    req = urllib.request.Request(
        LLM_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    return body["choices"][0]["message"]["content"]


def parse_dialogues(raw: str) -> list[dict]:
    # Strip code fences if the model added them despite instructions.
    fence = re.search(r"```(?:json)?\s*(\[.*?\])\s*```", raw, re.DOTALL)
    if fence:
        raw = fence.group(1)
    # Find the first top-level JSON array.
    start = raw.find("[")
    end = raw.rfind("]")
    if start < 0 or end < 0:
        return []
    candidate = raw[start : end + 1]
    try:
        items = json.loads(candidate)
    except json.JSONDecodeError:
        return []
    if not isinstance(items, list):
        return []
    valid = []
    for item in items:
        if not isinstance(item, dict):
            continue
        messages = item.get("messages")
        if not isinstance(messages, list) or len(messages) < 2:
            continue
        if any(
            not isinstance(m, dict)
            or m.get("role") not in {"user", "assistant"}
            or not isinstance(m.get("content"), str)
            or not m["content"].strip()
            for m in messages
        ):
            continue
        valid.append({"messages": messages})
    return valid


def main() -> None:
    if not DRAFTS_DIR.exists():
        sys.exit(f"missing drafts dir: {DRAFTS_DIR}")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    total = 0
    per_pillar: dict[str, int] = {}
    with OUTPUT.open("w") as out:
        for filename, pillar, system_msg in SOURCES:
            source_path = DRAFTS_DIR / filename
            if not source_path.exists():
                print(f"SKIP: {filename} not found")
                continue
            source = source_path.read_text()
            print(f"\n=== {filename} → pillar={pillar} ===")
            print(f"    {len(source)} chars source; asking for "
                  f"{DIALOGUES_PER_SOURCE} dialogues")
            t0 = time.time()
            try:
                raw = call_llm(GEN_INSTRUCTION.format(
                    n=DIALOGUES_PER_SOURCE, source=source,
                ))
            except Exception as e:
                print(f"    ERROR calling llm: {e}")
                continue
            dt = time.time() - t0
            dialogues = parse_dialogues(raw)
            print(f"    parsed {len(dialogues)} valid dialogues in {dt:.1f}s")
            if not dialogues:
                print(f"    raw head: {raw[:400]!r}")
                continue
            for d in dialogues:
                record = {
                    "messages": [{"role": "system", "content": system_msg}]
                    + d["messages"],
                    "pillar": pillar,
                    "source": filename,
                }
                out.write(json.dumps(record, ensure_ascii=False) + "\n")
                total += 1
                per_pillar[pillar] = per_pillar.get(pillar, 0) + 1

    print(f"\nWrote {total} bonus samples to {OUTPUT}")
    for p, c in sorted(per_pillar.items(), key=lambda kv: -kv[1]):
        print(f"  {c:3d}  {p}")


if __name__ == "__main__":
    main()
