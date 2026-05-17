#!/usr/bin/env python3
"""
Filter soul_stories_weighted_v4.jsonl down to a Radical Resolve corpus by
removing examples whose content engages with Luminary Nexus Token economics,
blockchain, DAOs, or crypto mechanics.

The Radical Resolve mobile app is a healing companion. We want the radical
acceptance / kindness / peaceful conflict resolution / community voice but
NOT the tokenomic framing those values sometimes ride alongside in Josh's
archives.

This script is conservative: it drops any example that hits a tokenomic term
anywhere in any message. Kindness/community content NOT framed via tokenomics
is preserved.

Original v4 file is never modified — output is a new JSONL beside it.
"""
import json
import re
from collections import Counter
from pathlib import Path

SRC = Path('/home/josh/helios-distillation/data/soul_stories_weighted_v4.jsonl')
DST = Path('/home/josh/helios-distillation/data/radical_resolve_v1.jsonl')
DROPPED_LOG = Path('/home/josh/helios-distillation/data/radical_resolve_v1.dropped.jsonl')

# Long terms: substring match is safe (no common English false positives).
LNT_SUBSTRING_TERMS = [
    'luminary nexus',
    'blockchain',
    'meme coin',
    'memecoin',
    'tokenomics',
    'smart contract',
    'cryptocurrency',
    'cryptocurrencies',
    'governance token',
    'liquidity pool',
    'ethereum',
    'solidity language',
    'mint a token',
    'minting a token',
    'token holders',
    'token holder',
    'on-chain',
]

# Short terms: word-bounded only. "defi" would otherwise match "deficit",
# "dao" matches names, "crypto" matches "cryptography", "lnt" matches nothing
# real but be safe.
LNT_WORD_TERMS = [
    'lnt',
    'defi',
    'dao',
    'daos',
    'nft',
    'nfts',
    'web3',
    'erc20',
    'erc-20',
    'staking',
    'staked',
    'crypto',
    'cryptos',
]

LNT_PATTERN = re.compile(
    '|'.join(re.escape(t) for t in LNT_SUBSTRING_TERMS)
    + '|'
    + r'\b(?:' + '|'.join(re.escape(t) for t in LNT_WORD_TERMS) + r')\b',
    re.IGNORECASE,
)


def message_blob(example: dict) -> str:
    return ' '.join(m.get('content', '') for m in example.get('messages', []))


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f'Missing source dataset: {SRC}')

    kept = 0
    dropped = 0
    drop_reasons = Counter()
    pillar_kept = Counter()
    pillar_dropped = Counter()

    with SRC.open() as src, DST.open('w') as dst, DROPPED_LOG.open('w') as drop_log:
        for raw in src:
            example = json.loads(raw)
            blob = message_blob(example).lower()
            match = LNT_PATTERN.search(blob)

            pillar = example.get('pillar') or 'unknown'
            if match:
                dropped += 1
                term = match.group(0).strip().lower()
                drop_reasons[term] += 1
                pillar_dropped[pillar] += 1
                drop_log.write(raw)
            else:
                kept += 1
                pillar_kept[pillar] += 1
                dst.write(raw)

    total = kept + dropped
    print('=' * 60)
    print('Radical Resolve dataset filter')
    print('=' * 60)
    print(f'Source : {SRC}')
    print(f'Output : {DST}')
    print(f'Dropped: {DROPPED_LOG}')
    print()
    print(f'Total examples scanned : {total}')
    print(f'Kept                   : {kept} ({100 * kept / total:.1f}%)')
    print(f'Dropped                : {dropped} ({100 * dropped / total:.1f}%)')
    print()
    print('Top drop reasons (matched term):')
    for term, count in drop_reasons.most_common(15):
        print(f'  {count:5d}  {term}')
    print()
    print('Pillar distribution after filter:')
    for pillar, count in pillar_kept.most_common():
        d = pillar_dropped.get(pillar, 0)
        print(f'  {count:5d} kept  ({d} dropped)  {pillar}')


if __name__ == '__main__':
    main()
