APP := Chatty.app/Contents

Chatty.app:
	swift build -c release
	mkdir -p $(APP)/MacOS
	cp .build/release/Chatty $(APP)/MacOS
	cp mac/Info.plist $(APP)/
