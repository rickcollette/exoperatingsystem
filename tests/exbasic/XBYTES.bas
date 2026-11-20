' Bytes and blocks: PUT/GET, BPUT/BGET, partial block at end of file
DIM B(299) BYTE, C(299) BYTE
FOR I = 0 TO 299 : B(I) = I * 7 : NEXT
OPEN #1, 8, 0, "D:B.DAT"
BPUT #1, ADR(B), 300 : ? "BPUT "; ERR()
PUT #1, 65 : PUT #1, 66
CLOSE #1
OPEN #1, 4, 0, "D:B.DAT"
BGET #1, ADR(C), 300 : ? "BGET "; ERR()
S = 0 : FOR I = 0 TO 299 : S = S + (B(I) <> C(I)) : NEXT
? "DIFF "; S
GET #1, X, Y : ? "GET "; X; " "; Y; " "; ERR()
GET #1, X : ? "EOF "; ERR()
CLOSE #1
OPEN #1, 4, 0, "D:B.DAT"
BGET #1, ADR(C), 290 : BGET #1, ADR(C), 50
? "PART "; ERR(); " "; DPEEK($358)
CLOSE #1
OPEN #1, 12, 0, "D:B.DAT" : ? "UPDATE "; ERR()
PUT #1, 1 : CLOSE #1
OPEN #1, 4, 0, "D:B.DAT" : GET #1, X : ? "FIRST "; X : CLOSE #1
