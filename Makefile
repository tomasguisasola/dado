PKG= dado
V= 2.2.0
DIST_DIR= $(PKG)-$V
HTMLS= doc/dado.png doc/index.html doc/license.html doc/examples.html
BR_HTMLS= doc/br/dado.png doc/br/index.html doc/br/license.html doc/br/examples.html
DADO_SRCS= src/dado.lua \
	src/dado/object.lua \
	src/dado/sql.lua
TABLE_EXTRA= src/table/extra.lua
SRCS= $(DADO_SRCS) \
	$(STRING_EXTRA) \
	$(TABLE_EXTRA)
TESTS= tests/overall.lua \
	tests/tsql.lua \
	tests/ttable.extra.lua \
	tests/tdado.lua \
	tests/tdbobj.lua


dist: $(SRCS) README $(TESTS)
	mkdir -p $(DIST_DIR)
	cp README $(DIST_DIR)
	mkdir -p $(DIST_DIR)/src/table
	cp $(TABLE_EXTRA) $(DIST_DIR)/src/table
	mkdir -p $(DIST_DIR)/src/dado
	cp src/dado.lua $(DIST_DIR)/src
	cp src/dado/*.lua $(DIST_DIR)/src/dado
	mkdir -p $(DIST_DIR)/doc/luadoc
	cp $(HTMLS) $(DIST_DIR)/doc
	mkdir -p $(DIST_DIR)/doc/br
	cp $(BR_HTMLS) $(DIST_DIR)/doc/br
	cd $(DIST_DIR); ldoc src -d doc/luadoc
	mkdir -p $(DIST_DIR)/tests
	cp $(TESTS) $(DIST_DIR)/tests
	tar czf $(PKG)-$V.tar.gz $(DIST_DIR)
	rm -rf $(DIST_DIR)

local-test:
	cd src; lua ../tests/overall.lua

install-test:
	lua -lluarocks.require tests/overall.lua
