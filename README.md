# textual music instructions / tiny midi interface / too much information

*compose music with text, an add-on for any norns script*

*tmi* is a norns library for a file-based music tracker providing surprisingly simple sequencing using a text-editor. it is based off [miti](https://github.com/schollz/miti) which is a raspberry-pi based version i wrote about a year ago.

other norns trackers like [yggdrasil](https://llllllll.co/t/yggdrasil), [nisp](https://llllllll.co/t/nisp), [orca](https://llllllll.co/t/orca) all have great features and wonderful visual interfaces. *tmi* on the otherhand has very few features and basically no visual interface. however, *tmi* **can be used within any other norns script** with just a few lines of code. 

*tmi* tracks are written in `.tmi` files which can be loaded via the norns parameters menu into any attached midi device. changes to files are hot-loaded so you can even do live-coding if you have a computer handy.

this script is basically the third (and final?) in a trilogy of norns scripts that are importable into norns scripts. basically you can now take a random norns script and...

- ...add command-mapping to single buttons (via [middy](https://llllllll.co/t/middy))
- ...add a grid-based drum machine (via [kolor](https://llllllll.co/t/kolor))
- ...add now midi sequencing (via [tmi](https://llllllll.co/t/tmi))


## Install

add these lines of code somewhere (preferable near the top) of a script:

```lua
if util.file_exists(_path.code.."tmi") then 
  tmi=include("tmi/lib/tmi")
  m=tmi:new()
end
```

if you want *tmi* to play a certain file right away, you can add these two lines:

```lua
m:load("op-1","/home/we/dust/data/tmi/chords.tmi",1)m:toggle_play()
```
## Documentation

*tmi* works with text files. rules for these files:

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

### Examples

the following are valid `.tmi` files

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
