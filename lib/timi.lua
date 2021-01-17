json = include("timi/lib/json")
music = include("timi/lib/music")
utils = include("timi/lib/utils")

local Timi = {}

function Timi:new(args)
  local m = setmetatable({}, { __index = Timi })
  local args = args == nil and {} or args
  return m
end

function Timi:load(filename)
	lines = utils.lines_from(filename)
	if lines == nil or #lines == 0  then 
		print("no filename "..filename)
		do return end
	end
	notes = {}
	on = {}
	first_line = nil 
	for i,line in ipairs(lines) do 
		if line ~= nil then
			if first_line == nil then 
				first_line = line
			end
			notes[i],on = self:parse_line(line,on)
		end
	end
	if first_line ~= nil then 
		notes[1] = self:parse_line(first_line,on) -- turn off notes from the end
	end
	print(json.encode(notes))
end

function Timi:parse_line(line,on)
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


return Timi