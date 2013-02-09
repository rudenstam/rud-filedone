# Keep this in sync with Tcl script which will print to partyline what version it uses
VERSION := 0.4

CC := gcc
CFLAGS := -c -Wall -O2

rud-filedone : rud-filedone.o

%.o : %.c
	$(CC) $(CFLAGS) -o $@ $<

clean :
	rm -f rud-filedone rud-filedone.o

install : rud-filedone
ifndef DEST
	$(error Usage: make install DEST=<destination>)
else
  ifeq (,$(wildcard $(DEST)))
	$(error $(DEST) doesn't exist.)
  else
	cp rud-filedone $(DEST)
  endif
endif

test: rud-filedone
ifndef BIN
	$(error Usage: make test BIN=<path to rud-filedone>)
else
  ifeq (,$(wildcard $(BIN)))
	$(error $(BIN) doesn't exist.)
  else
	@./rud-filedone-test.tcl $(BIN)
  endif
endif


.PHONY: install clean test
