# textual music instructions / tiny midi interface / too much information

*compose music with text, an add-on for any norns script*

*tmi* is a norns library for a file-based music tracker ported from [a version i previously wrote](https://github.com/schollz/miti). other norns trackers like [yggdrasil](https://llllllll.co/t/yggdrasil), [nisp](https://llllllll.co/t/nisp), [orca](https://llllllll.co/t/orca) all have great features and wonderful visual interfaces. *tmi* on the otherhand has very few features and essentially no visual interface. however, *tmi* **can be used within any other norns script** and with a few lines of code you can sequence multiple external devices.

*tmi* music tracks are written in `.tmi` files. when *tmi* is activated on a script, these files can be loaded via the `PARAMETERS > TMI` screen in the parameters menu. once loaded, any changes to files are hot-loaded so you could do live-coding (if you have a computer handy).

this script finalizes a trilogy of norns scripts i've been writing that can be imported into other norns scripts. my goals was to take a existing sample-based script be able to *also*...

- ...have command-mapping to single buttons (via [middy](https://llllllll.co/t/middy))
- ...be compatible with a grid-based drum machine (via [kolor](https://llllllll.co/t/kolor))
- ...be able to do midi sequencing (via [tmi](https://llllllll.co/t/tmi))

the importable scripts above work in a multitude of scripts ([barcode](https://llllllll.co/t/barcode), [oooooo](https://llllllll.co/t/oooooo), [cranes](https://llllllll.co/t/cranes), [otis](https://llllllll.co/t/otis), to name a few) but might not work with all (especially if the host script already uses midi or something).

## Demo/Tutorial

https://vimeo.com/503866942

## Install *tmi*

first install in maiden with 

```
;install https://github.com/schollz/tmi
```

then edit an existing script, like *cranes*. in the existing script add these lines of code somewhere (preferable near the top) of the script:

```lua
if util.file_exists(_path.code.."tmi") then 
  tmi=include("tmi/lib/tmi")
  m=tmi:new()
end
```

if you want *tmi* to play a certain file right away, you can add these two lines:

```lua
-- change "op-1" to the instrument your using
m:load("op-1","/home/we/dust/data/tmi/chords.tmi",1)
m:toggle_play()
```
## Documentation



for goto `PARAMETERS > TMI`. make sure you have your midi device plugged in before you start, otherwise `TMI` menu will not be available.

now you can load *tmi* files into any connected midi instrument (up to 4 tracks per instrument).

### how to make *tmi* files

*tmi* works with text files. by default these files are found in the `~/data/dust/tmi` directory. you need to make these files yourself using maiden or another text editor.

rules for these files:

- one line is one measure, and is subdivided according to how many things are in it. example: `C . . .` plays a C-major chord on beat 1 and rests for 3 beats
- chords start with an uppercase letter, inversions allowed with `/` and octaves allowed with `;`. examples: `Cmin`, `F#min/A;4`, `Db;5`)
- notes start with a lower case letter, with optional octave number, separated by commas. examples: `c`, `e5`, `f4,a,c`
- the `-` character sustains the last entry
- the `*` character re-plays the last entry
- the `.` character is a rest
- multiple sequences can be in one file with each below a line specifying `pattern X` where you fill in `X`
- if multiple sequences are in one file, chain them with `chain X Y`
- comments are specified by `#`

by default *tmi* uses a meter of 4, but this can be changed at startup using `m = tmi:new{meter=X}`.

### examples of *tmi* files

the following are valid *tmi* files

```
# a four chord song
C
G/B
Am/C
F/C
```

```
# switch between playing a chord for two measures 
# and an arpeggio of the chord

chain a b 

pattern a 
Cmaj7
-

pattern b
c4 e g b c e g b
c6 b g e c b g e
```

## License

MIT
