-- tmi

tmi=include("tmi/lib/tmi")
m=tmi:new()

function init()
  m:load("plinky","/home/we/dust/code/tmi/songs/test.tmi")
  m:load("plinky","/home/we/dust/code/tmi/songs/test3.tmi")
end


function key(k,z)
  if z==1 then
    print("hard sync")
    m:toggle_play()
  end
end
