"""Grind balance sim - runnable in Termux: python3 tools/balance.py
Models LIVE sources in minutes of play (not days):
  seva ~48 XP per ~15s cycle, sadhana 30-80 per ~25s + 45s cooldown,
  bandits 60-90 per ~30s kill, tutorial q01 120 one-shot.
"""
import json
from pathlib import Path

D = Path(__file__).parent.parent / "data"
ranks = json.loads((D / "gurukkal_ranks.json").read_text())["ranks"]
need = {r["rank"]: r["xp_needed"] for r in ranks}

# blended honest rate: mix of seva/sadhana/bandits ≈ 150 XP/min
RATE = 150.0

if __name__ == "__main__":
    t2 = need[2] / RATE
    t3 = need[3] / RATE
    print(f"Rank 2 ({need[2]} XP): ~{t2:.1f} min at {RATE:.0f} XP/min")
    print(f"Rank 3 ({need[3]} XP): ~{t3:.1f} min at {RATE:.0f} XP/min")
    assert t2 <= 6, f"rank2 too slow: {t2} min"
    assert t3 <= 15, f"rank3 too slow: {t3} min"
    # quest one-shots must cover rank 2 with plot start
    ones = 120 + 100 + 120  # q01 + sthala + shilanyasa
    assert ones >= need[2], f"honest path short of rank2: {ones} < {need[2]}"
    print("BALANCE OK: ranks land in minutes, honest path reaches Rank 2.")
