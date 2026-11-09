# Systematic FX Trading Research: Testing Whether Simple Rules Beat Noise

Research on EUR/USD trading rules from a six-person graduate team project in NC State's Master of Financial Mathematics program (Fall 2026). This repository documents **my own contributions** to that project: the feature screening, the VWAP analysis, and the Ichimoku TK cross research, which came out of a pre-registered search across 20 trading rules tested against a Monte Carlo noise benchmark.

**Headline finding:** the best rule out of 20 returned +22% out of sample, but it performed *worse* than the best of 20 random strategies would be expected to perform. On EUR/USD at realistic costs, structureless noise turns a profit about half the time, so a profitable backtest on its own proves very little.

> The team codebase is built on licensed course materials, and the broker price data cannot be redistributed, so neither is included here. This repository contains my analysis notebooks, the 20 pre-registered hypotheses, and this write-up.

---

## 1. Feature screening (`notebooks/feature_screening_15m.ipynb`)

Before building any strategy, I measured whether simple features predict future returns at all, using rank IC (the Spearman correlation between a feature now and the return over the next 1, 4, and 16 bars) on 10 years of 15-minute bars (about 248,000 bars).

- **RSI(14)** was the strongest feature, with a rank IC of **-0.036** against the next bar: a small mean-reversion signal. The sign held in all three periods tested (2016-2019, 2020-2022, 2023-2026).
- **RSI and distance from the 50-period EMA were 0.92 correlated**, so they carry mostly the same information.
- **Realized volatility** showed no predictive power.

A rank IC of -0.036 is statistically significant with this much data, but small: at the 15-minute horizon it is smaller than the bid-ask spread. That set up the main question for the rule search: can any rule turn a signal this weak into profit after costs?

## 2. VWAP analysis (`notebooks/vwap_analysis.ipynb`)

I tested whether price reacts to a rolling VWAP more than it would to a level with no meaning. Every test was run twice: once on VWAP, and once on a **placebo level** (the close from 50 bars earlier).

- Follow-through after a "bounce" off VWAP was no better than after touching the placebo level.
- A pattern in the first half of the sample weakened substantially in the second half.
- VWAP distance was 0.92 correlated with RSI, so it added little new information.

**Conclusion:** no usable VWAP edge on 1-hour EUR/USD.

## 3. Pre-registered rule search (`hypotheses/candidates.json`)

To avoid the most common way backtests fool people, trying many rules and reporting only the winner, the experiment was designed before any results were seen:

- **20 rules across 11 mechanism families** (mean reversion, trend, volatility filters, candle patterns, volume, Ichimoku, and others), each written down with the reason it should work. The list was frozen before testing.
- **One control rule** that reproduces the team's reference strategy exactly, to confirm the testing engine gives identical results (same 1,222 trades, identical returns).
- **Walk-forward testing** at two timeframes: 15-minute bars (18 out-of-sample windows) and 4-hour bars (10 windows), with a rolling training window and 1 pip of transaction cost per round trip.
- **A held-out final period** (April 2024 onward) that was never used.
- **A Bonferroni-adjusted significance bar** of 0.0025 for 20 tests.

## 4. Monte Carlo noise benchmark

For the top three rules and the control, I compared the real result with the same rule run on **400 synthetic price paths** that have similar volatility but no trends or mean reversion. If a rule's real return is no better than what it earns on noise, it has no edge.

The right comparison point matters here. When you pick the best of 20 rules, chance alone puts that best one around the **95th percentile** of the noise distribution (20/21). A real edge has to clear that bar.

## 5. The Ichimoku TK cross in detail (`strategy/SG_IchimokuCross.mq5`)

The TK cross was the strongest of the 20 rules, so I took it further: a full performance breakdown, the per-window results, a long vs. short split, a check at a second timeframe, and a working MetaTrader 5 Expert Advisor.

**The rule**

```
Timeframe:  EUR/USD, 4-hour bars
Long:       Tenkan-sen (9) crosses above Kijun-sen (26) on a closed bar
Short:      Tenkan-sen crosses below Kijun-sen
Entry:      open of the next bar
Exit:       take profit (about +110 pips) or stop loss (about -92 pips) only
Cost:       1 pip per round trip
```

Both lines are midpoints of the high-low range (about 36 hours and 4 days), so a cross means the recent trading range has shifted relative to the longer one.

**Out-of-sample performance (10 walk-forward windows, about 7.5 years)**

| | |
|---|---|
| Total return | +22.0% (unlevered) |
| Windows positive | 8 of 10 |
| Trades | 164 (about 28 per year) |
| Win rate | 61% |
| Average win / loss | +90.0 / -106.2 pips |
| Expectancy | +13.4 pips per trade |
| Breakeven win rate | 54.1% |

An initial long vs. short split showed both sides profitable with balanced trade counts (81 longs, 83 shorts), which argues against the rule simply riding the euro's decline. That split still needs a second check before relying on it.

**Why it is not an edge:** the cushion over breakeven is about 7 winning trades per 100, which is well inside what chance produces. It sat at the 79th percentile of noise, against roughly the 95th expected for the best of 20 rules. Most of its return came from one window, its most recent window was its worst (-7.51% over 43 trades at a 37% win rate), and the same rule ranked 14th of 20 on 15-minute bars.

**The Expert Advisor** implements the rule natively in MQL5, so it runs inside MetaTrader 5 without Python. It was run on a demo account only, as a test of the execution logic, not as a strategy expected to make money.

## Results

| | |
|---|---|
| Best rule | Ichimoku Tenkan-Kijun ("TK") cross on 4-hour bars, which I then analyzed in depth (per-window returns, long vs. short split, timeframe check) |
| Out-of-sample return | +22.0% over about 7.5 years, 164 trades, 61% winners |
| Position in noise distribution | **79th percentile** (best of 20 by chance alone: about 95th) |
| Same rule on 15-minute bars | Ranked 14th of 20 |
| Concentration | 62% of the total return came from one window (June 2022 to January 2023, a strongly trending period) |
| Most recent window | Its worst, at -7.51% |

**The best rule did not pass.** Four independent checks pointed the same way: it fell short of the noise benchmark, it reversed at a different timeframe, its returns came mostly from one trending period, and its recent performance was its weakest.

### What did hold up: costs drive results

- Across both timeframes, losses ranked almost perfectly by how often a rule traded. More trading meant bigger losses.
- A 1-pip round trip is about **20% of a typical 15-minute move** but only **4.7% of a typical 4-hour move**.
- Moving from 15-minute to 4-hour bars improved 5 of 6 matched rules, exactly as the cost explanation predicts.
- On this instrument and cost level, **noise was profitable in 49% to 55% of simulations**.

### Methodology issues found in the team codebase

- The optimization criterion (return plus 2 times drawdown) systematically penalized short test windows, which inverted rankings until returns were checked directly.
- A lagged-return feature was sign-flipped: positive values meant the price had *fallen*.

### Limitations

- Two of the 20 rules (volume spike and volume dry-up reversion) generated signals but opened no positions inside test windows, so they are effectively untested.
- Combinatorial purged cross-validation, available in the team codebase, was not yet run.

## Next steps

- Fewer, larger trades: daily bars and targets in the hundreds of pips, since cost per trade is the dominant problem
- A signal-exit variant of the TK cross (close on the opposite cross instead of waiting for the target or stop)
- Combinatorial purged cross-validation, saving the held-out period for one final test

## Repository contents

```
notebooks/
  feature_screening_15m.ipynb   rank IC screen across horizons and periods
  vwap_analysis.ipynb           VWAP vs. placebo level test
hypotheses/
  candidates.json               the 20 pre-registered rules, each with its stated mechanism
strategy/
  SG_IchimokuCross.mq5          the TK cross as a MetaTrader 5 Expert Advisor (demo use only)
```

**Tools:** Python, pandas, NumPy, SciPy, ta, MetaTrader 5
