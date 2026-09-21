.PHONY: all run

all:
	./scripts/build.sh

run: all
	open "$$HOME/Applications/macOS_sucks.app"
