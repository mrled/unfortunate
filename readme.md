# Unfortunate

Cursed Linux terminal in the browser

## How to build this?

Currently much of the build process is manual




### Building the `browser-vm` iso image

Clone <https://github.com/humphd/browser-vm>.

To reconfigure, the instructions say to run docker with `--rm`, but don't do this and you can run the customization steps (per below) and then make. And you can do the same thing over and over again without killing your docker container. This lets you iterate much more quickly as rebuilding only takes a minute or two, at least if all you're changing is in the filesystem overlay.

The best thing to do is NOT to run the singular command, but run the one that lets you do `make menuconfig`, and **do not** use the `--rm` argument from the instructions. Even if you don't want to make any menuconfig changes, doing it that way lets you keep the build state, so you can add files to the rootfs and type `make` again and it'll only take a minute or so.

I run a command like this:

```sh
docker run --name build-v86-menu-config -v $PWD/dist:/build -v $PWD/buildroot-v86/:/buildroot-v86 -it --entrypoint bash buildroot
```

That drops me to a shell inside the builder docker container. From there:

```sh
make BR2_EXTERNAL=/buildroot-v86 v86_defconfig
make menuconfig
#... edit as needed
make savedefconfig
make linux-menuconfig
#... edit as needed
make linux-savedefconfig
# Copy any necessary files in to $PWD/buildroot-v86/board/v86/rootfs_overlay
make
```

Note that they next step - cross-compiling the golang binaries - needs to be done in the "Copy any necessary files..." step above.

It looks like that saves the original config and your `make menuconfig` and `make linux-menuconfig` will use the original config as a base. So I am only noting the changes I am making as of 20211014. Also note that the actual config has been modified a bit from the instructions, for instance it uses a pentium pro rather than a pentium M, so you should trust the actual config over the instructions.

My changes to `make menuconfig`:

* games:
  * ascii_invaders
  * sl
* utilities
  * screen

My changes to `make linux-menuconfig`:

* Disable the PCI debugging that is enabled by upstream

### Cross-compiling go fortune/coloration binaries

Did this with Go 1.17 in October 2021.
The fucking Go conventions change sometimes so, enjoy if you're trying to do this in the future I guess.

```sh
BROWSER_VM_LOCAL_BIN=/path/to/browser-vm/buildroot-v86/board/v86/rootfs_overlay/usr/local/bin/

go get github.com/arsham/rainbow
cd $GOPATH/pkg/mod/github.com/arsham/rainbow@v1.1.1
GOOS=linux GOARCH=386 go build -o $BROWSER_VM_LOCAL_BIN/rainbow

go get github.com/arsham/figurine
cd $GOPATH/pkg/mod/github.com/arsham/figurine@v1.0.1/
#GOOS=linux GOARCH=386 go build github.com/arsham/figurine/figurine
GOOS=linux GOARCH=386 go build -o $BROWSER_VM_LOCAL_BIN/figurine

go get github.com/bmc/fortune-go
cd $GOPATH/pkg/mod/github.com/bmc/fortune-go@*
GOOS=linux GOARCH=386 go build -o $BROWSER_VM_LOCAL_BIN/fortune fortune.go
```

This will copy them into the `browser-vm` overlay directory if you set `$BROWSER_VM_LOCAL_BIN` correctly.

### Copy `fortunate` repo to /root

Check out <https://github.com/mrled/fortunate> and copy the databases to `/root` inside the overlay.

You do not have to build the fortune databases, because the golang fortune implementation we use reads fortune cookie files directly. You should also skip copying the .git directory so the file doesn't get too big.

### Building v86

Clone <https://github.com/copy/v86>

Build it per instructions.

Copy results into this repo:

```sh
cp ../v86/build/v86_all.js* .
cp ../v86/build/xterm.js* build/
cp ../v86/build/v86.wasm .
cp ../v86/v86.css .
cp ../v86/bios/{seabios.bin,vgabios.bin} .
```

Also copy the output iso image from `browser-vm`'s `dist/v86-linux.iso` to `unfortunate.iso`.

## View locally

These are just static files, you can do it with any static webserver.

```sh
python3 -m http.server 42069
```

And then open <http://localhost:42069>

## To do

* Note: video console will never support true color: <https://github.com/copy/v86/issues/539>
* Hide video console?
* Save state so that it comes up instantly?
