' Text files: write, append, read lines, end of file, missing file
OPEN #1, 8, 0, "D:T1.TXT" : ? "OPEN W "; ERR()
FOR I = 1 TO 3 : PRINT #1, "LINE "; I : NEXT
CLOSE #1 : ? "CLOSE "; ERR()
OPEN #1, 9, 0, "D:T1.TXT" : ? "OPEN A "; ERR()
PRINT #1, "APPENDED"
CLOSE #1
OPEN #1, 4, 0, "D:T1.TXT" : ? "OPEN R "; ERR()
DO
  INPUT #1, A$
  IF ERR() <> 1 THEN EXIT
  ? "["; A$; "]"
LOOP
? "EOF "; ERR()
CLOSE #1
OPEN #1, 4, 0, "D:NOPE.TXT" : ? "MISSING "; ERR()
CLOSE #1
OPEN #2, 4, 0, "Q:" : ? "NO DEVICE "; ERR()
CLOSE #2
