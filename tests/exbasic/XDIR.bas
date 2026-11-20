' Directory listing through CIO: OPEN mode 6
OPEN #1, 8, 0, "D:ZZ1.TXT" : PRINT #1, "ABC" : CLOSE #1
OPEN #1, 6, 0, "D:*.TXT" : ? "OPEN "; ERR()
DO
  INPUT #1, A$
  IF ERR() <> 1 THEN EXIT
  ? A$
LOOP
? "END "; ERR()
CLOSE #1
