RAKU = raku
PROVE = prove

.PHONY: test

test:
	$(PROVE) -e "$(RAKU) -Ilib" t/*.t
