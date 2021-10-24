# Unfortunate

Cursed Linux terminal in the browser

## How to build this?

* Make sure when cloning the repo, all submodules were pulled in as well
* Requires GNU Make (sorry)
* Requires Go to cross-compile `fortune` and one or two other commands for the virtual machine image
    * Did this with Go 1.17 in October 2021.
    * The fucking Go conventions change sometimes so, enjoy if you're trying to do this in the future I guess.
* Requires Docker to build the virtual machine image and the webassembly emulator

```sh
## Optional - build a list of tweet databases to include
# This requires Twitter credentials
export TWITTER_CONSUMER_KEY="your twitter consumer key"
export TWITTER_CONSUMER_SECRET="your twitter consumer secret"
# If you do not set this, a default list of some of my favorites + my account will be used
export FORTUNE_TWEET_ACCOUNTS="acct1 anotherAcct thirdAccountHere"
make tweets

# Build everything else
# * Some command-line programs in Go are cross-compiled
# * The v86 emulator is built
# * The ISO image is built that will boot Linux, including fortune databases
# * If generated above, the twitter fortune databases are included
make

# Run a simple webserver to use it locally
make serve
```

* It is a static site; `make serve` just runs an HTTP server.
* The site is built inside of the `public/` directory

### Troubleshooting the build

If you're seeing issues like `g++: internal compiler error: Killed (program cc1plus)`, your compiler may be running out of memory. Especially a problem on Docker for Mac, as it is running Docker in a Linux VM behind the scenes, and only has access to a small portion of your RAM.

## Configuring the `browser-vm` iso image

The `browser-vm` image is built from <https://github.com/mrled/unfortunate-browser-vm>.
The default will work out of the box, or you can change it like this.

To reconfigure, the instructions say to run docker with `--rm`, but don't do this and you can run the customization steps (per below) and then make. And you can do the same thing over and over again without killing your docker container. This lets you iterate much more quickly as rebuilding only takes a minute or two, at least if all you're changing is in the filesystem overlay.

The best thing to do is NOT to run the singular command, but run the one that lets you do `make menuconfig`, and **do not** use the `--rm` argument from the instructions. Even if you don't want to make any menuconfig changes, doing it that way lets you keep the build state, so you can add files to the rootfs and type `make` again and it'll only take a minute or so.

That said, buildroot doesn't detect when a full rebuild is needed - you need to figure this out yourself. See <https://buildroot.org/downloads/manual/manual.html#full-rebuild>.

I run a command like this inside the `browser-vm` directory:

```sh
docker run --name build-v86-menu-config -v $PWD/dist:/build -v $PWD/buildroot-v86/:/buildroot-v86 -it --entrypoint bash buildroot
```

That drops me to a shell inside the builder docker container. From there:

```sh
make BR2_EXTERNAL=/buildroot-v86 v86_defconfig
make menuconfig
#... edit as needed
make savedefconfig
make busybox-menuconfig
# ... edit as needed. Note that Unicode has to get enabled here.
# Also note that there is no 'make busybox-savedefconfig'... instead we copy manually:
cp /root/buildroot-2021.02-rc2/output/build/busybox-1.33.0/.config /buildroot-v86/board/v86/busybox.config
make linux-menuconfig
#... edit as needed
make linux-savedefconfig
# ... copy any necessary files in to $PWD/buildroot-v86/board/v86/rootfs_overlay
make
```

It looks like that saves the original config and your `make menuconfig` and `make linux-menuconfig` will use the original config as a base.

### Reusing the `browser-vm` build container

The best way to reuse the build container is to keep the container in the foreground --
that is, don't exit from the shell started by `docker run`.
If you exit, you won't be able to restart the container.

However, you can [commit the container to a new image and run that](https://stackoverflow.com/a/49204476/868206),
which means you won't lose your build artifacts.
That looks like this (run from the `browser-vm/` directory).
First, kill or exit the `build-v86-menu-config` container.
Then:

```
> docker exec -it build-v86-menu-config -v $PWD/dist:/build -v $PWD/buildroot-v86/:/buildroot-v86 bash
Error response from daemon: Container 6dc41679269ff6c50580f06932a1ecf0774809d81b4fcae5d42afc7668038db3 is not running

> docker commit 6dc41679269ff6c50580f06932a1ecf0774809d81b4fcae5d42afc7668038db3
sha256:d307f74458d6479d4a2515e0046bd6385fae62d8f70faa997906f8157b2e7885

> docker run  -v $PWD/dist:/build -v $PWD/buildroot-v86/:/buildroot-v86 --entrypoint bash -it d307f74458d6479d4a2515e0046bd6385fae62d8f70faa997906f8157b2e7885
```

You do have to remember to delete your committed container eventually so that it doesn't use up space on your filesystem forever, though.

## Notes

* Video console will never support true color: <https://github.com/copy/v86/issues/539>
* For this reason, we hide the video console, and use the virtual serial port with a console on it instead

## To do

* Hide the video console
* Save state so that it comes up instantly in the browser

### Enable Unicode

This is turning out to be difficult.
A collection of links:

* I filed a bug with the upstream browser-vm project: <https://github.com/humphd/browser-vm/issues/9>
* You can test that the upstream project also has trouble with unicode in the terminal at <https://humphd.github.io/browser-shell/>
* Notes describing the locale-gen stuff in that bug came from <https://github.com/foss-for-synopsys-dwc-arc-processors/toolchain/issues/207>
* There are lots of things to configure in Buildroot, see <https://buildroot.org/downloads/manual/manual.html#make-tips> for list of make targets you might want to investigate
* See also <https://buildroot.org/downloads/manual/manual.html#_configuration_of_other_components>
* This thread is relevant, but it didn't fix my issue: <https://lists.uclibc.org/pipermail/busybox/2014-August/081414.html>
* Apparently the Docker library busybox image was able to solve this <https://github.com/docker-library/busybox/issues/13>
