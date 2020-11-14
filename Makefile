# just a dummy makefile to call shake

all :
	cabal new-run build -- # --lint --progress

clean :
	cabal new-run build -- clean
