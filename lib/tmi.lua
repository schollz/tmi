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
  m.device = {}
  for i=1,4 do 
  	m.device[i] = {
	  	midi = midi.connect(i),
	  	notes_on = {},
	  	measure = 0,
	  	measures={},  		
		}
  end
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
		for i,dev in ipairs(self.device) do 
			self.device[i].measure = 0
			for k,_ in pairs(dev.notes_on) do 
				dev.midi:note_off(k)
				self.device[i].notes_on[k] = nil 
			end
		end
	else
		self.lattice:hard_sync()
	end
end


function Timi:emit_note(t)
	beat = t%ppm+1
	for i = 1,4 do 
		if #self.device[i].measures == 0 then 
			goto continue
		end
		if beat == 1 then 
			self.device[i].measure = self.device[i].measure + 1 
			if self.device[i].measure > #self.device[i].measures then 
				self.device[i].measure = 1 
			end
		end
		local notes = self.device[i].measures[self.device[i].measure].emit[beat..""]
		if notes ~= nil then 
			print(i,self.device[i].measure,beat,json.encode(notes))
			if notes.off ~= nil then 
				for _, note in ipairs(notes.off) do 
					if self.device[i].notes_on[note.m] ~= nil then
						self.device[i].midi:note_off(note.m)
						self.device[i].notes_on[note.m]=nil
					end
				end
			end
			if notes.on ~= nil then 
				for _, note in ipairs(notes.on) do 
					if note.m ~= nil then
						self.device[i].midi:note_on(note.m,127)
						self.device[i].notes_on[note.m]=true
					end
				end
			end			
		end
		::continue::
	end
end

function Timi:load(device_num,filename)
	lines = utils.lines_from(filename)
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
	self.device[device_num].measures = measures
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