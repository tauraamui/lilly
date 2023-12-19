run:
    v -g run ./src .

run-gui:
    v -g -d gui run ./src .

run-debug: nonprod-compile
	./lilly --debug .

run-gui-debug: compile-gui
	./lillygui --debug .

experiment:
    v -g run ./experiment .

test:
    v -g test ./src

nonprod-compile:
    v -g ./src -o lilly -prod

prod-compile:
    v ./src -o lilly -prod

compile-gui:
    v -d gui ./src -o lillygui

build: prod-compile

apply-license-header:
	addlicense -c "The Lilly Editor contributors" -y "2023" ./src/*.v

install-license-tool:
	go install github.com/google/addlicense@latest

symlink: build
	sudo ln -s $PWD/lilly /usr/local/bin
