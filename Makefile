name = statement_vtab

CC ?= cc
CFLAGS := -O3 $(CFLAGS)
PREFIX ?= /usr/local

soext = so
ifeq ($(shell uname), Darwin)
	soext = dylib
endif

src = $(name).c
module = $(name).$(soext)

.PHONY: all install clean

$(module): $(src)
	$(CC) -fPIC -std=c99 -shared $(CFLAGS) -o $@ $^

all: $(module)

install: $(module)
	install $^ $(PREFIX)/lib/

clean:
	rm -f $(module)
