-- tmi

tmi = include("tmi/lib/tmi")
m = tmi:new()

function init()
	m:load(1,"/home/we/dust/code/tmi/test.tmi")
	m:load(2,"/home/we/dust/code/tmi/test2.tmi")
end


function key(k,z)
	if z == 1 then 
		print("hard sync")
		m:toggle_play()
	end
end
