.PHONY: all fat clean
TARGET = tbdump
FAT = $(TARGET)-fat
MULTI = $(FAT).x86_64 $(FAT).armv7 $(FAT).arm64
SRC = src/*.c
FLAGS = -std=c99 -Wall -O3 -DTIMESTAMP="`date +'%d. %B %Y %H:%M:%S'`" $(CFLAGS)
STRIP ?= strip

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) -o $(TARGET) $(FLAGS) $(SRC)
	$(STRIP) $(TARGET)
	mv $(TARGET) ../..

fat: $(FAT)

$(FAT): $(MULTI)
	lipo -create -output $(FAT) $(MULTI)
	$(STRIP) $(FAT)
	codesign -s - $(FAT)

$(FAT).x86_64: $(SRC)
	xcrun -sdk macosx clang -arch x86_64 -o $(FAT).x86_64 $(FLAGS) $(SRC)

$(FAT).armv7: $(SRC)
	xcrun -sdk iphoneos clang -arch armv7 -o $(FAT).armv7 $(FLAGS) $(SRC)

$(FAT).arm64: $(SRC)
	xcrun -sdk iphoneos clang -arch arm64 -o $(FAT).arm64 $(FLAGS) $(SRC)

clean:
	rm -f $(TARGET) $(FAT) $(MULTI)
