' RUN another program, passing COMMON variables
COMMON N, F%, S$
N = 1234 : F% = 2.5 : S$ = "PASSED"
? "FIRST PROGRAM"
RUN "D:XCHAIN2.COM"
? "RUN FAILED "; ERR()
