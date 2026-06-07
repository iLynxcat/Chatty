APP := Chatty.app/Contents

.PHONY: clean

default: Chatty.app

clean:
	rm -rf .build/
	rm -rf target/
	rm -rf Chatty.app/

Chatty.app:
	swift build -c release
	mkdir -p $(APP)/MacOS
	cp .build/release/Chatty $(APP)/MacOS
	cp mac/Info.plist $(APP)/
