run:
    v run ./src

test:
    v -g test ./src

compile:
    v ./src -o lilly.bin -prod

