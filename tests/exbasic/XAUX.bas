' A program that leaves channel 0 (E:) with AUX1 = 0, as XIO #0 in BASIC
' does: the batch file and the prompt must go on
STATUS #0, S : ? "E: "; S
POKE $34A, 0
? "AUX1 CLEARED"
