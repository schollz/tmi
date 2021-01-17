-- timi

timi = include("timi/lib/timi")
m = timi:new()

function init()
	m:load(1,"/home/we/dust/code/timi/test.miti")
end


function key(k,z)
	if z == 1 then 
		print("hard sync")
		m:toggle_play()
	end
end