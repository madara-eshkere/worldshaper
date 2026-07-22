extends RefCounted
## Speed drives turn order/frequency in the TurnScheduler: a higher-speed actor
## comes up more often (a speed-8 bat acts ~2x as often as a speed-4 player, so it
## closes distance when you flee). Derived from DEX with a big-but-meaningful spread
## (69 vs 70 matters, but there is no "100 speeds"). Balance the numbers later.
##
##   DEX  1 -> speed 1        DEX 20 -> speed 6
##   DEX 10 -> speed 3        DEX 30 -> speed 9
##   speed 10 is reserved for special/flying creatures, set explicitly.

static func for_dex(dex: int) -> int:
	return clampi(int(round(dex * 0.3)), 1, 9)
