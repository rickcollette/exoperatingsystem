' XIO in Atari BASIC order: rename, lock, unlock, delete
OPEN #1, 8, 0, "D:OLD.TXT" : PRINT #1, "X" : CLOSE #1
OPEN #1, 8, 0, "D:W1.BAK" : CLOSE #1
OPEN #1, 8, 0, "D:W2.BAK" : CLOSE #1
XIO 32, #1, 0, 0, "D:OLD.TXT,NEW.TXT" : ? "RENAME "; ERR()
XIO 35, #1, 0, 0, "D:NEW.TXT" : ? "LOCK "; ERR()
XIO 33, #1, 0, 0, "D:NEW.TXT" : ? "DEL LOCKED "; ERR()
OPEN #1, 8, 0, "D:NEW.TXT" : ? "WRITE LOCKED "; ERR() : CLOSE #1
XIO 36, #1, 0, 0, "D:NEW.TXT" : ? "UNLOCK "; ERR()
XIO 33, #1, 0, 0, "D:NEW.TXT" : ? "DELETE "; ERR()
XIO 33, #1, 0, 0, "D:NEW.TXT" : ? "DEL AGAIN "; ERR()
XIO 33, #1, 0, 0, "D:*.BAK" : ? "DEL WILD "; ERR()
XIO 32, #1, 0, 0, "D:NONE.TXT,X.TXT" : ? "REN MISSING "; ERR()
OPEN #1, 4, 0, "D:OLD.TXT" : ? "OLD GONE "; ERR() : CLOSE #1
