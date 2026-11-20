' Graphics modes, sound and back to the text screen
DIM A(1000)
A(1000) = 77
GRAPHICS 8 + 16 : ? "GR8 "; ERR()
COLOR 1 : PLOT 0, 0 : DRAWTO 319, 191
LOCATE 10, 10, X
SOUND 0, 100, 10, 8 : PAUSE 5 : SOUND
GRAPHICS 7 : COLOR 2 : PLOT 5, 5 : FCOLOR 3 : FILLTO 50, 50
GRAPHICS 0
? "BACK "; A(1000)
? "STATUS"
STATUS #0, S : ? "E: "; S
STATUS #3, S : ? "CLOSED "; S
