' Locked (protected) files: every way to open them
OPEN #1, 8, 0, "D:L.TXT" : PRINT #1, "KEEP" : CLOSE #1
XIO 35, #1, 0, 0, "D:L.TXT"
OPEN #1, 8, 0, "D:L.TXT" : ? "WRITE "; ERR() : CLOSE #1
OPEN #1, 9, 0, "D:L.TXT" : ? "APPEND "; ERR()
PUT #1, 65 : ? " PUT "; ERR() : CLOSE #1 : ? " CLOSE "; ERR()
OPEN #1, 12, 0, "D:L.TXT" : ? "UPDATE "; ERR()
GET #1, X : ? " GET "; X; " "; ERR()
PUT #1, 66 : ? " PUT "; ERR() : CLOSE #1 : ? " CLOSE "; ERR()
OPEN #1, 4, 0, "D:L.TXT" : INPUT #1, A$ : ? "READ "; A$; " "; ERR() : CLOSE #1
XIO 32, #1, 0, 0, "D:L.TXT,M.TXT" : ? "RENAME "; ERR()
XIO 33, #1, 0, 0, "D:L.TXT" : ? "DELETE "; ERR()
XIO 36, #1, 0, 0, "D:*.TXT" : ? "UNLOCK "; ERR()
