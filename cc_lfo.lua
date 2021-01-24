
-- 1. edit these variables
-- how many steps total? (no more than 48)
steps = 4
-- how many measures total?
measures = 4
-- specify which ccs, and their lfo modulation
ccs = {
	-- example:
	{
		cc=74,from=100,to=60,period=64,
	},
	{
		cc=24,from=40,to=100,period=32,
	},
}

-- 2. run this script into a file, e.g.
-- > lua ~/dust/code/tmi/cc_lfo.lua > ~/dust/data/tmi/ccs
--

-- the code...
s = ""
t = 0
for i=1,measures do 
	for j=1,steps do 
		for k, cc in ipairs(ccs) do 
			val = (-1*math.cos(2*3.14159/cc.period*t)+1)/2*(cc.to-cc.from) + cc.from
			val = math.floor(val)
			s = s..cc.cc..","..val 
			if #ccs > 1 and k~= #ccs then 
				s = s..","
			else
				s = s.." "
			end
		end
		t = t + 1
	end
	s = s.."\n"
end
print(s)