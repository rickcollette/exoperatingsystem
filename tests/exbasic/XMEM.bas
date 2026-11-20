' Memory: the free memory, a big array up to the top, too big an array
GRAPHICS 0
? "TEXT OK"
? "FREE "; FRE()
N = FRE() / 2 - 200
DIM BIG(N)
BIG(N) = 4321 : BIG(0) = 1234
? "BIG "; BIG(0); " "; BIG(N); " "; FRE() < 500
DIM HUGE(10000)
? "NOT HERE"
