APP := Chatty.app/Contents

.PHONY: clean

Chatty.app:
	swift build -c release
	mkdir -p $(APP)/MacOS
	cp .build/release/Chatty $(APP)/MacOS
	cp mac/Info.plist $(APP)/

clean:
	rm -rf .build/
	rm -rf target/
	rm -rf Chatty.app/
