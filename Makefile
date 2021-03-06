NIM=nimble c

MAIN=updatepaper

SRC=src

DEBUGOUT=build
RELEASEOUT=release

FLAGS=-d:ssl

DEBUGOPTS=$(FLAGS) --outdir:$(DEBUGOUT) --verbose
RELEASEOPTS=$(FLAGS) --outdir:$(RELEASEOUT) -d:release

.PHONY: run debug release all clean

run:
	$(NIM) $(DEBUGOPTS) -r $(SRC)/$(MAIN)

debug:
	$(NIM) $(DEBUGOPTS) $(SRC)/$(MAIN)

release:
	$(NIM) $(RELEASEOPTS) $(SRC)/$(MAIN)

all: debug release

clean:
	rm ./$(DEBUGOUT)/*
	rm ./$(RELEASEOUT)/*
