#!/usr/bin/env node
"use strict";

const path = require("path");

// Not using this for now as it builds a ~70MB state file

console.log("Don't forget to run `make all` before running this script");

var fs = require("fs");
var V86 = require("./v86/build/libv86.js").V86;

var OUTPUT_FILE = "work/unfortunate-state-base.bin";

process.stdin.setRawMode(true);
process.stdin.resume();
process.stdin.setEncoding("utf8");
process.stdin.on("data", handle_key);

var emulator = new V86({
    bios: { url: "./public/bios/seabios.bin" },
    vga_bios: { url: "./public/bios/vgabios.bin" },
    autostart: true,
    memory_size: 512 * 1024 * 1024,
    vga_memory_size: 8 * 1024 * 1024,
    network_relay_url: "<UNUSED>",
    cdrom: { url: "public/unfortunate.iso" },
    screen_dummy: true,
});

console.log("Now booting, please stand by ...");

var boot_start = Date.now();
var serial_text = "";
let booted = false;

emulator.add_listener("serial0-output-char", function(c)
{
    process.stdout.write(c);

    serial_text += c;

    if(!booted && serial_text.endsWith("unfortunate # "))
    {
        console.error("\nBooted in %d", (Date.now() - boot_start) / 1000);
        booted = true;

        // sync and drop caches: Makes it safer to change the filesystem as fewer files are rendered
        emulator.serial0_send("sync;echo 3 >/proc/sys/vm/drop_caches\n");

        setTimeout(function ()
            {
                emulator.save_state(function(err, s)
                    {
                        if(err)
                        {
                            throw err;
                        }

                        fs.writeFile(OUTPUT_FILE, new Uint8Array(s), function(e)
                            {
                                if(e) throw e;
                                console.error("Saved as " + OUTPUT_FILE);
                                stop();
                            });
                    });
            }, 10 * 1000);
    }
});

function handle_key(c)
{
    if(c === "\u0003")
    {
        // ctrl c
        stop();
    }
    else
    {
        emulator.serial0_send(c);
    }
}

function stop()
{
    emulator.stop();
    process.stdin.pause();
}
