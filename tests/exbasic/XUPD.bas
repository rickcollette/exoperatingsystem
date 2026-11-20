' Read and write (mode 12): change bytes in place, the length stays
DIM B(299) BYTE
FOR I = 0 TO 299 : B(I) = 48 + I MOD 10 : NEXT
OPEN #1, 8, 0, "D:U.DAT" : BPUT #1, ADR(B), 300 : CLOSE #1
PROC_LEN()
OPEN #1, 12, 0, "D:U.DAT" : PUT #1, 65 : CLOSE #1
PROC_LEN()
OPEN #1, 12, 0, "D:U.DAT" : GET #1, X : PUT #1, 66 : CLOSE #1
PROC_LEN()
OPEN #1, 12, 0, "D:U.DAT" : BGET #1, ADR(B), 200 : BPUT #1, ADR(B), 50 : CLOSE #1
PROC_LEN()
OPEN #1, 12, 0, "D:U.DAT" : BGET #1, ADR(B), 290 : BPUT #1, ADR(B), 20 : CLOSE #1
PROC_LEN()
OPEN #1, 12, 0, "D:U.DAT" : PRINT #1, "XYZ" : CLOSE #1
PROC_LEN()

FUNC PROC_LEN()
  N = 0 : S = 0
  OPEN #2, 4, 0, "D:U.DAT"
  DO
    GET #2, C
    IF ERR() <> 1 THEN EXIT
    N = N + 1 : S = S + C
  LOOP
  CLOSE #2
  OPEN #2, 4, 0, "D:U.DAT" : GET #2, C, D, E, F : CLOSE #2
  ? N; " "; S; " "; CHR$(C); CHR$(D); CHR$(E); CHR$(F)
ENDFUNC
