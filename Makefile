# just a dummy makefile to call shake

all :
	cabal run build -- # --lint --progress

clean :
	cabal run build -- clean
