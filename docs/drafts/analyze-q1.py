#!/usr/bin/env python3
"""Reproduce every statistic in the Store-submission census.

Regenerate the source data (needs a GitHub token; the search API caps at 1000 results,
which is why the window is one quarter):

    gh api -X GET search/issues --paginate \
      -f q='repo:raycast/extensions is:pr label:"new extension" created:2026-01-01..2026-03-31' \
      > q1-2026.json
    jq -s '[.[].items[]] | unique_by(.number)' q1-2026.json > q1.json
    python3 analyze-q1.py q1.json

Or run against the committed slim CSV, which carries the same columns:

    python3 analyze-q1.py data-q1-2026-new-extensions.csv
"""

import csv
import json
import statistics as st
import sys
from collections import Counter, defaultdict
from datetime import datetime


def load(path):
    """Accept either the raw API JSON or the slim CSV; normalize to one shape."""
    if path.endswith(".csv"):
        with open(path) as f:
            return [
                {
                    "number": int(r["number"]),
                    "author": r["author"],
                    "created_at": r["created_at"],
                    "closed_at": r["closed_at"] or None,
                    "state": r["state"],
                    "merged": r["merged"] == "True",
                    "draft": r["draft"] == "True",
                    "comments": int(r["comments"]),
                }
                for r in csv.DictReader(f)
            ]
    raw = json.load(open(path))
    items = raw["items"] if isinstance(raw, dict) else raw
    return [
        {
            "number": i["number"],
            "author": i["user"]["login"],
            "created_at": i["created_at"],
            "closed_at": i.get("closed_at"),
            "state": i["state"],
            "merged": bool(i.get("pull_request", {}).get("merged_at")),
            "draft": bool(i.get("draft")),
            "comments": i["comments"],
        }
        for i in items
    ]


def days(i):
    f = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
    return (f(i["closed_at"]) - f(i["created_at"])).total_seconds() / 86400


d = load(sys.argv[1] if len(sys.argv) > 1 else "data-q1-2026-new-extensions.csv")
merged = [i for i in d if i["merged"]]
failed = [i for i in d if i["state"] == "closed" and not i["merged"]]

print(f"n={len(d)}  merged={len(merged)}  failed={len(failed)}  open={len(d)-len(merged)-len(failed)}")
print(f"failure rate = {len(failed) / (len(merged) + len(failed)) * 100:.1f}%\n")

print("DRAFT AT CLOSE")
print(f"  failed & draft {sum(i['draft'] for i in failed)}/{len(failed)}"
      f" = {sum(i['draft'] for i in failed) / len(failed) * 100:.1f}%")
print(f"  merged & draft {sum(i['draft'] for i in merged)}\n")

print("ENGAGEMENT")
for name, g in (("merged", merged), ("failed", failed)):
    c = [i["comments"] for i in g]
    print(f"  {name}: median {st.median(c):.0f}  mean {st.mean(c):.1f}"
          f"  zero-comment {sum(x == 0 for x in c)}")

print("\nMERGE RATE BY COMMENT COUNT  (correlational — merged PRs accrue comments by progressing)")
for lo, hi in [(0, 2), (3, 4), (5, 6), (7, 9), (10, 10**9)]:
    m = sum(lo <= i["comments"] <= hi for i in merged)
    f = sum(lo <= i["comments"] <= hi for i in failed)
    if m + f:
        label = f"{lo}-{hi}" if hi < 10**9 else f"{lo}+"
        print(f"  {label:>5} comments: merged {m:3}  failed {f:3}  rate {m / (m + f) * 100:5.1f}%")

print("\nTIME TO RESOLUTION (days)")
for name, g in (("merged", merged), ("failed", failed)):
    v = sorted(days(i) for i in g if i["closed_at"])
    q = lambda p: v[int(len(v) * p)]
    print(f"  {name}: median {st.median(v):5.1f}  p25 {q(.25):5.1f}  p75 {q(.75):5.1f}  p90 {q(.90):5.1f}")

print("\nWHEN FAILURES DIE  (stale bot = 25-day label + 7-day close)")
buckets = [("<1 day", 0, 1), ("1-14", 1, 14), ("14-25", 14, 25),
           ("25-60 STALE ZONE", 25, 60), ("60+", 60, 10**9)]
for label, lo, hi in buckets:
    n = sum(1 for i in failed if i["closed_at"] and lo <= days(i) < hi)
    print(f"  {label:>18} {n:4}  {n / len(failed) * 100:5.1f}%  {'#' * int(n / len(failed) * 100)}")

print("\nAUTHORS")
au = Counter(i["author"] for i in d)
one = {a for a, n in au.items() if n == 1}
multi = {a for a, n in au.items() if n > 1}
print(f"  distinct {len(au)}   exactly-one-PR {len(one)} ({len(one) / len(au) * 100:.1f}%)")
for name, s in (("one-PR", one), ("multi-PR", multi)):
    sub = [i for i in d if i["author"] in s and i["state"] == "closed"]
    m = sum(i["merged"] for i in sub)
    print(f"  {name:>9} authors: {m}/{len(sub)} merged = {m / len(sub) * 100:.1f}%")

by = defaultdict(list)
for i in d:
    by[i["author"]].append(i)
fa = {i["author"] for i in failed}
rec = sum(1 for a in fa if any(x["merged"] for x in by[a]))
print(f"  authors with >=1 failure: {len(fa)};"
      f" landed one anyway: {rec} ({rec / len(fa) * 100:.1f}%)")
