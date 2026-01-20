name = statement_vtab

CFLAGS := -O3 $(CFLAGS)
PREFIX ?= /usr/local

soext = so
ifeq ($(shell uname), Darwin)
	soext = dylib
endif

src = $(name).c
module = $(name).$(soext)

.PHONY: all static install clean

$(module): $(src)
	$(CC) -fPIC -std=c99 -shared $(CFLAGS) -o $@ $^

$(name).a: $(src)
	$(CC) -std=c99 -DSQLITE_CORE $(CFLAGS) -c $^
	$(AR) rcs $(name).a $(name).o

all: $(module)

static: $(name).a

install: $(module)
	install -m644 $^ $(PREFIX)/lib/

clean:
	rm -f $(module) $(name).a $(name).o
