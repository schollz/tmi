json = include("tmi/lib/json")
music = include("tmi/lib/music")
utils = include("tmi/lib/utils")
lattice = include("kolor/lib/lattice")

local ppqn = 48
local meter = 4
local ppm = ppqn*meter
local Timi = {}

function Timi:new(args)
  local m = setmetatable({}, { __index = Timi })
  local args = args == nil and {} or args
  m.playing = false 
  m.track = {}
  m.lattice = lattice:new({
  	ppqn=ppqn,
  	meter=meter,
  })
  m.timer = m.lattice:new_pattern{
  	action=function(t)
  		m:emit_note(t)
  	end,
  	division=1/ppm
  }
  return m
end

function Timi:toggle_play()
	self.playing = not self.playing 
	if not self.playing then 
		self.lattice:stop()
		for i,track in ipairs(self.track) do 
			self.track[i].measure = 0
			for k,_ in pairs(track.notes_on) do 
				track.midi:note_off(k)
				self.track[i].notes_on[k] = nil 
			end
		end
	else
		self.lattice:hard_sync()
	end
end


function Timi:emit_note(t)
	beat = t%ppm+1
	for i,track in ipairs(self.track) do 
		if #track.measures == 0 then 
			goto continue
		end
		if beat == 1 then 
			self.track[i].measure = self.track[i].measure + 1 
			if self.track[i].measure > #self.track[i].measures then 
				self.track[i].measure = 1 
			end
		end
		local notes = self.track[i].measures[self.track[i].measure].emit[beat..""]
		if notes ~= nil then 
			print(i,self.track[i].measure,beat,json.encode(notes))
			if notes.off ~= nil then 
				for _, note in ipairs(notes.off) do 
					if self.track[i].notes_on[note.m] ~= nil then
						self.track[i].midi:note_off(note.m)
						self.track[i].notes_on[note.m]=nil
					end
				end
			end
			if notes.on ~= nil then 
				for _, note in ipairs(notes.on) do 
					if note.m ~= nil then
						self.track[i].midi:note_on(note.m,127)
						self.track[i].notes_on[note.m]=true
					end
				end
			end			
		end
		::continue::
	end
end

function Timi:load_pattern(filename)
    local f = assert(io.open(filename, "rb"))
    local content = f:read("*all")
    f:close()

    local current_pattern = "none"
    local pattern = {none={}}
    local chain = {}
    for s in content:gmatch("[^\r\n]+") do
        words = split_str(s)
        if words[1] == "pattern" then
            pattern[words[2]] = {}
            current_pattern = words[2]
        elseif words[1] == "chain" then 
            chain = {table.unpack(words, 2, #words)}
        elseif current_pattern ~= nil then
            table.insert(pattern[current_pattern],s)
        end
    end
    if #chain==0 then 
        table.insert(chain,current_pattern)
    end

    local s = ""
    for _,c in ipairs(chain) do
        if pattern[c] ~= nil then
            for _,p in ipairs(pattern[c]) do 
                s = s..p.."\n"
            end
        end
    end
    local lines = {}
    for t in s:gmatch("[^\r\n]+") do
        table.insert(lines,t)
    end
    return lines
end

function Timi:load(midi_id,filename)
	lines = Timi:load_pattern(filename)
	if lines == nil or #lines == 0  then 
		print("no filename "..filename)
		do return end
	end
	measures = {}
	on = {}
	last_note = nil
	first_line = nil 
	for i,line in ipairs(lines) do 
		if line ~= nil and #line > 1 then
			if first_line == nil then 
				first_line = line
			end
			measures[i],on,last_note = self:parse_line(line,on,last_note)
		end
	end
	if first_line ~= nil then 
		measures[1] = self:parse_line(first_line,on) -- turn off notes from the end
	end
	print(json.encode(measures))
	self.track[#self.track+1] = {
  		id=midi_id,
	  	midi = midi.connect(midi_id),
	  	notes_on = {},
	  	measure = 0,
	  	measures= measures,  		
	}
end

function Timi:parse_line(line,on,last_note)
	beats = {}
	for substring in line:gmatch("%S+") do 
		table.insert(beats,substring)
	end
	l = {}
	l.line = line
	l.division = #beats
	l.emit = {}
	if on == nil then 
		on = {}
	end
	for i,b in ipairs(beats) do 
		local emit = {}

		if #on > 0 and b ~= "-" then 
			-- turn off last beat
			beat = math.floor((i-1) * (ppm/l.division)-1)
			if beat < 0 then 
				beat = 1
			end
			beat = ""..beat 
			if l.emit[beat] ~= nil and l.emit[beat].off ~= nil then 
				table.insert(l.emit[beat].off,on)
			elseif l.emit[beat] ~= nil then
				l.emit[beat].off = on 
			else
				l.emit[beat] = {off=on} 
			end
			on = {}
		end

		if b == "." then 
		elseif b == "-" then
		else
			if b == "*" then 
				b = beats[i-1]
			end
			on = music.to_midi(b,last_note)
			beat = math.floor((i-1) * (ppm/l.division) + 1)..""
			if l.emit[beat] ~= nil and l.emit[beat].on ~= nil then 
				table.insert(l.emit[beat].on,on)
			elseif l.emit[beat] ~= nil then
				l.emit[beat].on = on 
			else
				l.emit[beat] = {on=on} 
			end
			last_note = on[1].m
		end 
		::continue::
	end
	return l,on,last_note
end


return Timi