run:
    v -g run ./src .

test:
    v -g test ./src

compile:
    v ./src -o lilly -prod

build: compile

apply-license-header:
	addlicense -c "The Lilly Editor contributors" -y "2023" ./src/*.v

install-license-tool:
	go install github.com/google/addlicense@latest

symlink: compile
	sudo ln -s $PWD/lilly /usr/local/bin
