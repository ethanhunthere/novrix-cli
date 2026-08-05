PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
BIN     := bin/novrix

.PHONY: build test install uninstall lint check clean help

build: $(BIN)

$(BIN): build.sh src/header.sh src/lib/*.sh
	bash build.sh

test: $(BIN)
	bash tests/smoke.sh

check: build test lint

install: $(BIN)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/novrix
	@echo "installed: $(DESTDIR)$(BINDIR)/novrix"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/novrix

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -s bash bin/novrix install.sh build.sh tests/smoke.sh; \
	else \
		echo "shellcheck not installed — skipping"; \
	fi

clean:
	rm -f $(BIN)

help:
	@echo "make build     assemble bin/novrix from src/ modules (build.sh)"
	@echo "make test      run the offline test suite"
	@echo "make lint      run shellcheck (if installed)"
	@echo "make check     build + test + lint"
	@echo "make install   install novrix to $(BINDIR)"
	@echo "make uninstall remove novrix"
