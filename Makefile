VERSION := 0.2

CC := gcc
CFLAGS := -c -Wall -O2

SHA1 = $(shell git show | head -n 1 | sed s/"commit "// | head -c 6)

rud-filedone : rud-filedone.o

%.o : %.c
	$(CC) $(CFLAGS) -o $@ $<

clean :
	rm -f rud-filedone rud-filedone.o rud-filedone.*.tar.bz

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

bundle :
	mkdir -p /tmp/rud-filedone
	cp rud-filedone.c Makefile README rud-mkvsize.tcl rud-filedone-test.tcl CHANGELOG /tmp/rud-filedone/
	tar -C /tmp/ -f rud-filedone.$(VERSION).$(SHA1).tar.bz -v -j -c rud-filedone
	rm -rf /tmp/rud-filedone

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


.PHONY: install clean bundle test
