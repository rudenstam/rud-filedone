CC=gcc
CFLAGS=-c -Wall -O2


all: rud-filedone

rud-filedone: rud-filedone.o

rud-filedone.o: rud-filedone.c
	$(CC) $(CFLAGS) rud-filedone.c
