json = require "json"
music = require "music"
utils = require "utils"

local Miti = {}

function Miti:new(args)
  local m = setmetatable({}, { __index = Miti })
  local args = args == nil and {} or args
  return m
end

function Miti:load(filename)
	lines = utils.lines_from(filename)
	notes = {}
	on = {}
	for i,line in ipairs(lines) do 
		notes[i],on = self:parse_line(line,on)
	end
	notes[1] = self:parse_line(lines[1],on) -- turn off notes from the end
	print(json.encode(notes))
end

function Miti:parse_line(line,on)
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
			beat = math.floor((i-1) * (96/l.division)-1)
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
			on = music.to_midi(b)
			beat = math.floor((i-1) * (96/l.division)+1)..""
			if l.emit[beat] ~= nil and l.emit[beat].on ~= nil then 
				table.insert(l.emit[beat].on,on)
			elseif l.emit[beat] ~= nil then
				l.emit[beat].on = on 
			else
				l.emit[beat] = {on=on} 
			end
		end 
		::continue::
	end
	return l,on
end


m = Miti:new()

m:load("test.miti")

-- print(json.encode(music.to_midi("Cm;6")))
