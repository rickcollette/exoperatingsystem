' NOTE and POINT: bookmarks in a file
OPEN #1, 8, 0, "D:N.TXT"
FOR I = 1 TO 40 : PRINT #1, "RECORD NUMBER "; I : NEXT
CLOSE #1
OPEN #1, 4, 0, "D:N.TXT"
FOR I = 1 TO 20 : INPUT #1, A$ : NEXT
NOTE #1, S, B : ? "NOTE "; ERR()
INPUT #1, A$ : ? A$
FOR I = 1 TO 10 : INPUT #1, A$ : NEXT
? A$
POINT #1, S, B : ? "POINT "; ERR()
INPUT #1, A$ : ? A$
CLOSE #1
OPEN #1, 4, 0, "D:N.TXT"
NOTE #1, S0, B0 : INPUT #1, A$
POINT #1, S0, B0 : INPUT #1, A$ : ? A$
CLOSE #1
? "POS "; S; " "; B; " "; S0; " "; B0
