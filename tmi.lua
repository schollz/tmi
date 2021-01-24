-- tmi
if util.file_exists(_path.code.."tmi") then 
  tmi=include("tmi/lib/tmi")
  m=tmi:new()
  m:load("bou","/home/we/dust/data/tmi/ccs",1)
  m:load("bou","/home/we/dust/data/tmi/untitled1.lua",2)
  -- m:toggle_play()
end


function init()
  counter = metro.init()
  counter.time = 0.2
  counter.count = -1
  counter.event = function() 
    -- redraw()
  end
  counter:start()
end


function key(k,z)
  if z==1 then
    print("hard sync")
    m:toggle_play()
  end
end


function redraw()
  screen.clear()
  screen.level(15)
  screen.rect(1, 1, 7, 64, 15)
  screen.fill()
  screen.level(0)
  screen.text_rotate(7, 62, "TMI", -90)

  screen.level(15)
  screen.move(64,7)
  screen.text_right("STATUS")

  screen.move(70,7)
  screen.text((m:is_playing()) and "PLAYING" or "STOPPED", 15)

  screen.move(15,30)
  screen.text("goto PARAMETERS > TMI")
  screen.move(15,40)
  screen.text("to load .tmi into device")
  screen.update()
  screen.ping()
end