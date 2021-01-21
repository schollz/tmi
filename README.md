# textual midi interface (tmi)

*easily compose music with text*

*tmi* is a norns library for a file-based music tracker providing surprisingly simple sequencing using a text-editor. it is based off [miti](https://github.com/schollz/miti) which is a raspberry-pi based version.


## Documentation

sequences are composed in `.tmi` files. rules for `.tmi` files:

- one line is one measure, and is subdivided according to how many things are in it. example: `C . . .` plays a C-major chord on beat 1 and rests for 3 beats
- chords start with an uppercase letter, inversions allowed with `/` and octaves allowed with `;`. examples: `Cmin`, `F#min/A;4`, `Db;5`)
- notes start with a lower case letter, with optional octave number, separated by commas. examples: `c`, `e5`, `f4,a,c`
- the `-` character sustains the last entry
- the `*` character re-plays the last entry
- the `.` character is a rest
- multiple sequences can be in one file with each below a line specifying `pattern X` where you fill in `X`
- if multiple sequences are in one file, chain them with `chain X Y`
- comments are specified by `#`

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