CC=gcc
CFLAGS=-c -Wall -O2

all: rud-filedone

rud-filedone: rud-filedone.o

rud-filedone.o: rud-filedone.c
	$(CC) $(CFLAGS) rud-filedone.c

clean:
	rm -f rud-filedone rud-filedone.o rud-filedone.tar.bz

install: rud-filedone
ifndef DEST
	$(error Usage: make install DEST=<destination>)
else
  ifeq (,$(wildcard $(DEST)))
	$(error $(DEST) doesn't exist.)
  else
	cp rud-filedone $(DEST)
  endif
endif

bundle:
	mkdir -p /tmp/rud-filedone
	cp rud-filedone.c Makefile README rud-mkvsize.tcl /tmp/rud-filedone/
	tar -C /tmp/ -f rud-filedone.tar.bz -v -j -c rud-filedone
	rm -rf /tmp/rud-filedone

.PHONY: install clean bundle
