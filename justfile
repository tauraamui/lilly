run: generate-git-hash
    v -g run ./src .

run-gui: generate-git-hash
    v -g -d gui run ./src .

run-debug: nonprod-compile
	./lilly --debug .

run-gui-debug: compile-gui
	./lillygui --debug .

experiment: generate-git-hash
    v -g run ./experiment .

test: generate-git-hash
    v -g test ./src

nonprod-compile: generate-git-hash
    v -g ./src -o lilly -prod

prod-compile: generate-git-hash
    v ./src -o lilly -prod

compile-gui: generate-git-hash
    v -d gui ./src -o lillygui

generate-git-hash:
    git log -n 1 --pretty=format:"%h" > ./src/.githash

build: prod-compile

apply-license-header:
	addlicense -c "The Lilly Editor contributors" -y "2023" ./src/*.v

install-license-tool:
	go install github.com/google/addlicense@latest

symlink: build
	sudo ln -s $PWD/lilly /usr/local/bin
