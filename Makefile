APP := Chatty.app/Contents

.PHONY: clean

Chatty.app:
	swift build -c release
	mkdir -p $(APP)/MacOS
	cp .build/release/Chatty $(APP)/MacOS
	cp mac/Info.plist $(APP)/

clean:
	swift package clean
	cargo clean
	rm -rf Chatty.app/
