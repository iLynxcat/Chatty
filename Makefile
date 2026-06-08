APP := Chatty.app/Contents

.PHONY: clean

chatty.zip: Chatty.app target/release/chattysrv
	zip -r chatty.zip Chatty.app
	zip chatty.zip -j target/release/chattysrv

target/debug/chattysrv:
	cargo build

target/release/chattysrv:
	cargo build --release

Chatty.app:
	swift build -c release
	mkdir -p $(APP)/MacOS
	cp .build/release/Chatty $(APP)/MacOS
	cp mac/Info.plist $(APP)/
	mkdir -p $(APP)/Resources
	cp -r mac/Resources $(APP)/Resources

clean:
	swift package clean
	cargo clean
	rm -rf Chatty.app/
	rm -rf chatty.zip
