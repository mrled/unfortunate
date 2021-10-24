# Unfortunate

Cursed Linux terminal in the browser

## How to build this?

Currently much of the build process is manual

### Building the `browser-vm` iso image

Clone <https://github.com/humphd/browser-vm>.

To reconfigure, the instructions say to run docker with `--rm`, but don't do this and you can run the customization steps (per below) and then make. And you can do the same thing over and over again without killing your docker container. This lets you iterate much more quickly as rebuilding only takes a minute or two, at least if all you're changing is in the filesystem overlay.

The best thing to do is NOT to run the singular command, but run the one that lets you do `make menuconfig`, and **do not** use the `--rm` argument from the instructions. Even if you don't want to make any menuconfig changes, doing it that way lets you keep the build state, so you can add files to the rootfs and type `make` again and it'll only take a minute or so.

That said, buildroot doesn't detect when a full rebuild is needed - you need to figure this out yourself. See <https://buildroot.org/downloads/manual/manual.html#full-rebuild>.

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
# ... copy any necessary files in to $PWD/buildroot-v86/board/v86/rootfs_overlay
make
```

Note that they next step - cross-compiling the golang binaries - needs to be done in the "Copy any necessary files..." step above.

It looks like that saves the original config and your `make menuconfig` and `make linux-menuconfig` will use the original config as a base. So I am only noting the changes I am making as of 20211014. Also note that the actual config has been modified a bit from the instructions, for instance it uses a pentium pro rather than a pentium M, so you should trust the actual config over the instructions.

### Reusing the build container

The best way to reuse the build container is to keep the container in the foreground --
that is, don't exit from the shell started by `docker run`.
If you exit, you won't be able to restart the container.

However, you can [commit the container to a new image and run that](https://stackoverflow.com/a/49204476/868206),
which means you won't lose your build artifacts.

```
> docker exec -it build-v86-menu-config -v $PWD/dist:/build     -v $PWD/buildroot-v86/:/buildroot-v86 bash
Error response from daemon: Container 6dc41679269ff6c50580f06932a1ecf0774809d81b4fcae5d42afc7668038db3 is not running

> docker commit 6dc41679269ff6c50580f06932a1ecf0774809d81b4fcae5d42afc7668038db3
sha256:d307f74458d6479d4a2515e0046bd6385fae62d8f70faa997906f8157b2e7885

> docker run  -v $PWD/dist:/build -v $PWD/buildroot-v86/:/buildroot-v86 --entrypoint bash -it d307f74458d6479d4a2515e0046bd6385fae62d8f70faa997906f8157b2e7885
```

You do have to remember to delete your committed container so that it doesn't use up space on your filesystem forever, though.

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
