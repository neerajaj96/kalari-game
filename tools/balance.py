"""Grind balance sim - runnable in Termux: python3 tools/balance.py"""
import json
from pathlib import Path

D = Path(__file__).parent.parent / "data"
ranks = json.loads((D / "gurukkal_ranks.json").read_text())["ranks"]
sources = json.loads((D / "gurukkal_ranks.json").read_text())["xp_sources"]

def time_to_rank(target=3):
    # Model: 5 mey reps/day (25xp) + 1 quest/2days (60xp/day avg) + uzhichil 10xp
    daily = 5 * sources["meyppayattu_rep"] + 60 + sources["daily_uzhichil"]
    need = next(r["xp_needed"] for r in ranks if r["rank"] == target)
    return need, daily, need / daily

if __name__ == "__main__":
    for t in (2, 3):
        need, daily, days = time_to_rank(t)
        print(f"Rank {t}: need={need} daily~{daily} -> {days:.1f} days")
    # Slice check: rank 3 should be 5-10 days casual, not 5 years (per book's corrupt-school warning)
    need3, _, days3 = time_to_rank(3)
    assert 3 <= days3 <= 14, f"grind off: {days3} days to rank3"
    print("BALANCE OK: slice reaches Kolthari in ~1 week, matches 6-month full-mastery fast-track scaled down.")
