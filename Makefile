RAKU = raku
PROVE = prove

.PHONY: test

test:
	$(RAKU) -Ilib t/assembler.t