extends Node
## Turn counter (ADR-0007: the whole game is turn-based).
## Out of combat turns are "smooth": they advance whenever the player acts,
## with no visible pause. Combat stop-time arrives at M1.

signal turn_advanced(turn: int)

var turn: int = 0


func advance() -> int:
	turn += 1
	turn_advanced.emit(turn)
	return turn
