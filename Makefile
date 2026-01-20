name = statement_vtab

CFLAGS := -std=c99 -Wall -O3 $(CFLAGS)
PREFIX ?= /usr/local

soext = so
ifeq ($(shell uname), Darwin)
	soext = dylib
endif

src = $(name).c
module = $(name).$(soext)

.PHONY: all static install clean

$(module): $(src)
	$(CC) -fPIC -shared $(CFLAGS) -o $@ $^

$(name).a: $(src)
	$(CC) -DSQLITE_CORE $(CFLAGS) -c $^
	$(AR) rcs $(name).a $(name).o

all: $(module)

static: $(name).a

install: $(module)
	install -m644 $^ $(PREFIX)/lib/

clean:
	$(RM) $(module) $(name).a $(name).o
