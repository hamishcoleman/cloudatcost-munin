
NAME := cloudatcost-munin
INSTALLROOT := installdir
INSTALLDIR := $(INSTALLROOT)/$(NAME)

describe := $(shell git describe --dirty)
tarfile := $(NAME)-$(describe).tar.gz

all:    test

build_dep:
	aptitude install libdevel-cover-perl

# FIXME, TODO: my standard libs should be managed with a submodule

install: clean
	install -d $(INSTALLDIR)
	cp -pr lib $(INSTALLDIR)
	install -p -t $(INSTALLDIR) test_foo

tar:    $(tarfile)

$(tarfile):
	$(MAKE) install
	tar -v -c -z -C $(INSTALLROOT) -f $(tarfile) .

clean:
	rm -rf $(INSTALLROOT)

cover:
	cover -delete
	-COVER=true $(MAKE) test
	cover

test:
	./test_harness lib

