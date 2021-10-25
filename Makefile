.PHONY: all
all: \
	public/unfortunate.iso \
	public/index.html \
	public/build/v86_all.js \
	public/build/v86_all.js.map \
	public/build/xterm.js \
	public/build/xterm.js \
	public/build/xterm.css \
	public/build/v86.wasm \
	public/v86.css \
	public/bios/seabios.bin \
	public/bios/vgabios.bin

#### Notes
# - The site is built in public/.
# - Some git submodules create work products inside their own directories, e.g. v86/build/.
# - Some of our work temporarily goes into work/ before being copied to its final location.
#   This lets us delete our rootfs_overlay and/or public/ directories without losing intermediate work if we don't want to.

#### Variables

OVERLAY = browser-vm/buildroot-v86/board/v86/rootfs_overlay

RAINBOW_GO = github.com/arsham/rainbow@v1.1.1
FORTUNE_GO = github.com/bmc/fortune-go@v0.0.0-20150411023932-a6a1cca25a5c
FIGURINE_GO = github.com/arsham/figurine@v1.0.1

# 9276 is WASM on a phone keypad
LOCAL_HTTP_PORT = 9276

#### Local HTTP server

.PHONY: serve
serve: all
	echo "Browse to <http://localhost:${LOCAL_HTTP_PORT}>"
	cd $(CURDIR)/public && python3 -m http.server --bind 0.0.0.0 ${LOCAL_HTTP_PORT}

#### Publish
# When we publish, we copy all the built artifacts to the public/ dir.
# But public/ is just a submodule of this very repo, based on an earlier commit.
# We then ensure that the SSH remote exists in that submodule,
# as by default we check out an HTTP remote so that others can clone it.
# Finally, we remove everything else, add all the files we built, commit and force push.

REPO_BUILT_BRANCH_BASE_COMMIT = 4f9b098ba9e4168c5abc196127037e20494b25cd

.PHONY: publish
publish: all
	cd $(CURDIR)/public && (git remote | grep -q sshorigin || git remote add sshorigin git@github.com:mrled/unfortunate.git)
	cd $(CURDIR)/public && (git branch -D new-built || echo "No branch 'new-built', continuing...")
	cd $(CURDIR)/public && git checkout -b new-built
	cd $(CURDIR)/public && (git branch | grep -q "^  built" && git branch -D built || echo "No branch 'built', continuing...")
	cd $(CURDIR)/public && git add -A
	cd $(CURDIR)/public && git commit -m "Publishing 'unfortunate' on $(shell date)..."
	cd $(CURDIR)/public && git checkout -b built ${REPO_BUILT_BRANCH_BASE_COMMIT}
	cd $(CURDIR)/public && git reset --hard new-built && git reset ${REPO_BUILT_BRANCH_BASE_COMMIT}
	cd $(CURDIR)/public && git add -A
	cd $(CURDIR)/public && git commit -m "Publishing 'unfortunate' on $(shell date)..."
	cd $(CURDIR)/public && git branch -D new-built
	cd $(CURDIR)/public && git push -f -u sshorigin built:built

#### Misc items that belong in the browser-vm iso root filesystem overlay

${OVERLAY}/usr/local/bin:
	mkdir -p ${OVERLAY}/usr/local/bin
${OVERLAY}/usr/share/fortune:
	mkdir -p ${OVERLAY}/usr/share/fortune
${OVERLAY}/etc/profile.d/99.fortune.sh: profile.d.fortunedb.sh
	cp profile.d.fortunedb.sh ${OVERLAY}/etc/profile.d/99.fortune.sh
${OVERLAY}/usr/local/bin/unfortunate: usr.local.bin.unfortunate.sh ${OVERLAY}/usr/local/bin
	cp usr.local.bin.unfortunate.sh ${OVERLAY}/usr/local/bin/unfortunate

#### Build go programs

# rainbow: lolcatjs, but in go
# Turns text pretty colors
# Only really good when 24 bit color enabled on the terminal
${OVERLAY}/usr/local/bin/rainbow: work/386bin/rainbow ${OVERLAY}/usr/local/bin
	cp work/386bin/rainbow ${OVERLAY}/usr/local/bin/rainbow
work/386bin/rainbow:
	go get ${RAINBOW_GO}
	cd ${GOPATH}/pkg/mod/${RAINBOW_GO} && \
		GOOS=linux GOARCH=386 go build -o $(CURDIR)/work/386bin/rainbow

# fortune-go: a Go reimplementation of the fortune command
# Happily, it does not require building fortune databases, but just parses the fortune files directly
${OVERLAY}/usr/local/bin/fortune: work/386bin/fortune ${OVERLAY}/usr/local/bin
	cp work/386bin/fortune ${OVERLAY}/usr/local/bin/fortune
work/386bin/fortune:
	go get ${FORTUNE_GO}
	cd ${GOPATH}/pkg/mod/${FORTUNE_GO} && \
		GOOS=linux GOARCH=386 go build -o $(CURDIR)/work/386bin/fortune fortune.go

# Figurine: rainbow + figlet
# Disabling as this is nearly 7MB currently (probably all the figlet fonts)
# ${OVERLAY}/usr/local/bin/figurine: work/386bin/figurine ${OVERLAY}/usr/local/bin
# 	cp work/386bin/figurine ${OVERLAY}/usr/local/bin/figurine
# work/386bin/figurine:
# 	go get ${FIGURINE_GO}
# 	cd ${GOPATH}/pkg/mod/${FIGURINE_GO} && \
# 		GOOS=linux GOARCH=386 go build -o $(CURDIR)/work/386bin/figurine

#### Build fortune databases from tweets
# This requires credentials so is not included in the 'all' target.

FORTUNE_TWEET_ACCOUNTS ?= ctrlcreep ActualPerson084 QuietPineTrees TheDoorTHEDOOR invisiblefonts mrled
# Removed: ThePatanoiac (went private)

# A space-separated list of generated tweet fortune databases inside the work/ directory
FORTUNE_TWEET_DB_TARGETS = $(foreach acct,$(FORTUNE_TWEET_ACCOUNTS),work/fortune/tweets/$(acct).tweets)

# A space-separated list of generated tweet fortune databases inside the root FS overlay
FORTUNE_TWEET_DB_OVERLAY_TARGETS = $(foreach acct,$(FORTUNE_TWEET_ACCOUNTS),${OVERLAY}/usr/share/fortune/$(acct).tweets)

${FORTUNE_TWEET_DB_TARGETS}:
	mkdir -p work/fortune/tweets
	for acct in ${FORTUNE_TWEET_ACCOUNTS}; do
		python3 fortunate/tweets/tweetfortune.py \
			--consumer-key ${TWITTER_CONSUMER_KEY} \
			--consumer-secret ${TWITTER_CONSUMER_SECRET} \
			--file work/fortune/tweets/$(acct).tweets \
			${acct}
		done

${FORTUNE_TWEET_DB_OVERLAY_TARGETS}: ${FORTUNE_TWEET_DB_TARGETS} ${OVERLAY}/usr/share/fortune
	cp ${FORTUNE_TWEET_DB_TARGETS} ${OVERLAY}/usr/share/fortune

.PHONY: tweets
tweets: ${FORTUNE_TWEET_DB_OVERLAY_TARGETS}

#### Install fortune databases

${OVERLAY}/usr/share/fortune/invisiblestates: ${OVERLAY}/usr/share/fortune
	cp fortunate/invisiblestates/invisiblestates ${OVERLAY}/usr/share/fortune/

#### Build the browser-vm iso image
# This will take a while

browser-vm/dist/v86-linux.iso: \
 ${OVERLAY}/etc/profile.d/99.fortune.sh \
 ${OVERLAY}/usr/local/bin/fortune \
 ${OVERLAY}/usr/local/bin/rainbow \
 ${OVERLAY}/usr/share/fortune/invisiblestates \
 ${OVERLAY}/usr/local/bin/unfortunate \
 browser-vm/buildroot-v86/configs/v86_defconfig \
 browser-vm/buildroot-v86/board/v86/linux.config \
 browser-vm/buildroot-v86/board/v86/busybox.config \
 $(shell find browser-vm/buildroot-v86 -type f)
	echo $(shell find browser-vm/buildroot-v86 -type f)
	cd $(CURDIR)/browser-vm && docker build -t buildroot .
	docker run \
		--rm \
		--name build-v86 \
		-v $(CURDIR)/browser-vm/dist:/build \
		-v $(CURDIR)/browser-vm/buildroot-v86:/buildroot-v86 \
		buildroot

#### Build the v86 emulator

v86/build/v86_all.js v86/build/v86_all.js.map v86/build/xterm.js v86/build/xterm.js.map v86/build/xterm.css v86/build/v86.wasm:
	cd $(CURDIR)/v86 && make && make all && make build/xterm.js

#### Copy everything to the public/ directory

public/unfortunate.iso: browser-vm/dist/v86-linux.iso
	cp browser-vm/dist/v86-linux.iso public/unfortunate.iso
public/index.html: index.html
	cp index.html public/index.html
public/favicon.ico: terminal.ico
	cp terminal.ico public/favicon.ico
public/_headers: _headers
	cp _headers public/_headers
public/build:
	mkdir -p public/build
public/build/v86_all.js: v86/build/v86_all.js public/build
	cp v86/build/v86_all.js public/build/v86_all.js
public/build/v86_all.js.map: v86/build/v86_all.js.map public/build
	cp v86/build/v86_all.js.map public/build/v86_all.js.map
# Note that the xterm.js artifacts apparently must be in the /build/ path on the webserver...
# other items could change location as they are specified directly in index.html,
# but xterm.js javascript/css files are referenced from something else that v86 builds,
# and the /build/ path is hard-coded.
public/build/xterm.js: v86/build/xterm.js public/build
	cp v86/build/xterm.js public/build/xterm.js
public/build/xterm.js.map: v86/build/xterm.js.map public/build
	cp v86/build/xterm.js.map public/build/xterm.js.map
public/build/xterm.css: v86/build/xterm.css public/build
	cp v86/build/xterm.css public/build/xterm.css
public/build/v86.wasm: v86/build/v86.wasm public/build
	cp v86/build/v86.wasm public/build/v86.wasm
public/v86.css: v86/v86.css
	cp v86/v86.css public/v86.css
public/bios:
	mkdir -p public/bios
public/bios/seabios.bin: v86/bios/seabios.bin public/bios
	cp v86/bios/seabios.bin public/bios
public/bios/vgabios.bin: v86/bios/vgabios.bin public/bios
	cp v86/bios/vgabios.bin public/bios