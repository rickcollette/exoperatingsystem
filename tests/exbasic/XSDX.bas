' SpartaDOS directories through XIO: MKDIR 42, CHDIR 44, RMDIR 43
XIO 42, #1, 0, 0, "D:NEWDIR" : ? "MKDIR "; ERR()
OPEN #1, 8, 0, "D:NEWDIR>IN.TXT" : PRINT #1, "INSIDE" : CLOSE #1 : ? "WRITE "; ERR()
XIO 44, #1, 0, 0, "D:NEWDIR" : ? "CHDIR "; ERR()
OPEN #1, 4, 0, "D:IN.TXT" : INPUT #1, A$ : ? "READ "; A$; " "; ERR() : CLOSE #1
XIO 44, #1, 0, 0, "D:>" : ? "CHDIR ROOT "; ERR()
XIO 43, #1, 0, 0, "D:NEWDIR" : ? "RMDIR FULL "; ERR()
XIO 33, #1, 0, 0, "D:NEWDIR>IN.TXT" : ? "DEL "; ERR()
XIO 43, #1, 0, 0, "D:NEWDIR" : ? "RMDIR "; ERR()
