#!/usr/bin/env python3
"""
Scrub first-person experience claims from the Radical Resolve corpus.

The smoke test on v1/v2 showed the model occasionally fabricates personal
memories ("I remember when my landlord…", "back in 2017 I went through…").
This is a structural problem: the v4 soul corpus was built from Josh's own
autobiographical archive, so the assistant voice learned to speak in
first-person past tense about lived experiences. A healing companion app
must not do this.

Approach: drop any example whose ASSISTANT message matches a high-precision
first-person-experience regex. User messages are untouched (users telling
their own stories is fine). System messages are untouched (they're pillar
definitions, no experience claims).

Inputs:
  data/radical_resolve_v1.jsonl       (14,262 — filtered Helios corpus)
  data/radical_resolve_v1_bonus.jsonl (49    — auroara drafts)

Outputs:
  data/radical_resolve_v3.jsonl       (kept after scrub, ready for SFT)
  data/radical_resolve_v3.dropped.jsonl (audit trail)
"""
import json
import re
from collections import Counter
from pathlib import Path

DATA_DIR = Path('/home/josh/helios-distillation/data')
SOURCES = [
    DATA_DIR / 'radical_resolve_v1.jsonl',
    DATA_DIR / 'radical_resolve_v1_bonus.jsonl',
]
OUT_KEEP = DATA_DIR / 'radical_resolve_v3.jsonl'
OUT_DROP = DATA_DIR / 'radical_resolve_v3.dropped.jsonl'

# Patterns target SPECIFIC first-person past-tense experience claims.
# Each is tight enough to avoid false positives on benign uses of "I"
# (like "I hear you", "I'd suggest", "I think"). Patterns are compiled
# with re.IGNORECASE.
EXPERIENCE_PATTERNS = [
    r"\bi remember (?:when|that time|back when|sitting|standing|the day|how)\b",
    r"\bwhen i (?:was|got|went|had|started|first|finally|realized|learned|noticed|sat|stood|woke)\b",
    r"\bi went through (?:that|this|something|a|an|the)\b",
    r"\bi'?ve been (?:there|through that|through this|exactly|in your)\b",
    r"\bi'?ll never forget\b",
    r"\bi used to (?:think|believe|feel|wake|sit|live|work|fight|cry|hide|drink|run|carry)\b",
    r"\bin my (?:own )?(?:life|experience|case|story|journey|past|twenties|thirties|forties)\b",
    r"\bi (?:was|got|had|spent|lived|worked|dated|married|divorced|fired|laid off)\b[^.!?]{0,80}\b(?:year|month|week|day|decade|time)s? ago\b",
    r"\bback in (?:19|20)\d{2}\b",
    r"\b(?:years?|months?|weeks?|decades?) ago,? i\b",
    r"\bi faced (?:that|this|something|a similar|the same|exactly)\b",
    r"\bi struggled with (?:that|this|exactly|the same|similar)\b",
    r"\bthere was a (?:moment|time|period|day|night|year|chapter) (?:when|where) i\b",
    r"\bi sat with (?:that|this|those feelings|my own)\b",
    r"\bmy own (?:journey|story|past|history|recovery|healing|breakdown|breakthrough)\b",
    r"\bwhen i first (?:learned|discovered|realized|understood|encountered|tried|started)\b",
    r"\bi was in (?:that|this|the same|a similar) (?:place|spot|situation|position|boat|moment)\b",
    r"\bi had to (?:learn|figure out|sit with|accept|let go|grieve|forgive) (?:that|this|my)\b",
]

EXPERIENCE_RE = re.compile('|'.join(EXPERIENCE_PATTERNS), re.IGNORECASE)


def assistant_blob(example: dict) -> str:
    return ' '.join(
        m.get('content', '')
        for m in example.get('messages', [])
        if m.get('role') == 'assistant'
    )


def main() -> None:
    kept = 0
    dropped = 0
    drop_reasons = Counter()
    pillar_kept = Counter()
    pillar_dropped = Counter()
    per_source_kept = Counter()
    per_source_dropped = Counter()

    with OUT_KEEP.open('w') as keep_f, OUT_DROP.open('w') as drop_f:
        for src in SOURCES:
            if not src.exists():
                print(f'WARN: {src} missing, skipping')
                continue
            for raw in src.open():
                example = json.loads(raw)
                blob = assistant_blob(example)
                match = EXPERIENCE_RE.search(blob)
                pillar = example.get('pillar', 'unknown')
                if match:
                    dropped += 1
                    pillar_dropped[pillar] += 1
                    per_source_dropped[src.name] += 1
                    drop_reasons[match.group(0).lower().strip()[:60]] += 1
                    drop_f.write(raw)
                else:
                    kept += 1
                    pillar_kept[pillar] += 1
                    per_source_kept[src.name] += 1
                    keep_f.write(raw)

    total = kept + dropped
    print('=' * 64)
    print('Radical Resolve v3 — first-person experience scrub')
    print('=' * 64)
    print(f'kept    : {OUT_KEEP}')
    print(f'dropped : {OUT_DROP}')
    print()
    print(f'total scanned : {total}')
    print(f'kept          : {kept} ({100 * kept / total:.1f}%)')
    print(f'dropped       : {dropped} ({100 * dropped / total:.1f}%)')
    print()
    print('per source:')
    for src in SOURCES:
        k = per_source_kept.get(src.name, 0)
        d = per_source_dropped.get(src.name, 0)
        if k + d == 0:
            continue
        print(f'  {src.name:40s}  kept={k:5d}  dropped={d:5d}  '
              f'({100 * d / (k + d):.1f}% scrubbed)')
    print()
    print('pillar distribution after scrub:')
    for pillar, count in pillar_kept.most_common():
        d = pillar_dropped.get(pillar, 0)
        print(f'  {count:5d} kept  ({d:4d} dropped)  {pillar}')
    print()
    print('top match patterns (sample):')
    for term, count in drop_reasons.most_common(15):
        print(f'  {count:5d}  {term}')


if __name__ == '__main__':
    main()
