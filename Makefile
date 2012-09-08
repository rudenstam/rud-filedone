CC=gcc
CFLAGS=-c -Wall -O2

all: rud-filedone

rud-filedone: rud-filedone.o

rud-filedone.o: rud-filedone.c
	$(CC) $(CFLAGS) rud-filedone.c

clean:
	rm rud-filedone.o rud-filedone

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

.PHONY: install clean
