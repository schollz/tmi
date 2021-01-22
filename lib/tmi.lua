json=include("tmi/lib/json")
music=include("tmi/lib/music")
utils=include("tmi/lib/utils")
lattice=include("kolor/lib/lattice")

local ppqn=48
local meter=4
local ppm=ppqn*meter
local Tmi={}
local velocities = {
  pp = 30,
  p = 40,
  mp = 50,
  mf = 60,
  f = 80,
  ff = 100,
  fff = 127,
}

function Tmi:new(args)
  local m=setmetatable({},{__index=Tmi})
  local args=args==nil and {} or args
  m.playing=false
  m.instrument={}
  for i=1,4 do
    m.instrument[i]={
      midi=midi.connect(i),-- TODO also get midi name
      track={},
      notes_on={},
    }
  end
  m.lattice=lattice:new({
    ppqn=ppqn,
    meter=meter,
  })
  m.timer=m.lattice:new_pattern{
    action=function(t)
      m:emit_note(t)
    end,
    division=1/ppm
  }
  return m
end

function Tmi:toggle_play()
  print("toggle_play")
  self.playing=not self.playing
  if not self.playing then
    print("stopping")
    self.lattice:stop()
    for k,instrument in ipairs(self.instrument) do
      for j,_ in pairs(instrument.notes_on) do
        instrument.midi:note_off(j)
        self.instrument[k].notes_on[j]=nil
      end
      for i,track in pairs(instrument.track) do
        self.instrument[k].track[i].measure=0
      end
    end
  else
    self.lattice:hard_sync()
  end
end


function Tmi:emit_note(t)
  beat=t%ppm+1
  for k,instrument in ipairs(self.instrument) do
    for i,track in pairs(instrument.track) do
      if #track.measures==0 then
        goto continue
      end
      if beat==1 then
        self.instrument[k].track[i].measure=self.instrument[k].track[i].measure+1
        if self.instrument[k].track[i].measure>#self.instrument[k].track[i].measures then
          self.instrument[k].track[i].measure=1
        end
      end
      local notes=self.instrument[k].track[i].measures[self.instrument[k].track[i].measure].emit[beat..""]
      if notes~=nil then
        print(i,self.instrument[k].track[i].measure,beat,json.encode(notes))
        if notes.off~=nil then
          for _,note in ipairs(notes.off) do
            if self.instrument[k].notes_on[note.m]~=nil then
              self.instrument[k].midi:note_off(note.m)
              self.instrument[k].notes_on[note.m]=nil
            end
          end
        end
        if notes.cc~=nil then
          -- TODO: emit the ccs
        end
        if notes.on~=nil then
          for _,note in ipairs(notes.on) do
            if note.m~=nil then
              self.instrument[k].midi:note_on(note.m,note.v)
              self.instrument[k].notes_on[note.m]=true
            end
          end
        end
      end
      ::continue::
    end
  end
end

function Tmi:load_pattern(filename)
  local f=assert(io.open(filename,"rb"))
  local content=f:read("*all")
  f:close()

  local current_pattern="none"
  local pattern={none={}}
  local chain={}
  for s in content:gmatch("[^\r\n]+") do
    if #s > 0 and s[1] ~= "#" then -- comment 
      words=utils.string_split(s)
      if words[1]=="pattern" then
        pattern[words[2]]={}
        current_pattern=words[2]
      elseif words[1]=="chain" then
        chain={table.unpack(words,2,#words)}
      elseif current_pattern~=nil then
        table.insert(pattern[current_pattern],s)
      end
    end
  end
  if #chain==0 then
    table.insert(chain,current_pattern)
  end

  local s=""
  for _,c in ipairs(chain) do
    if pattern[c]~=nil then
      for _,p in ipairs(pattern[c]) do
        s=s..p.."\n"
      end
    end
  end
  local lines={}
  for t in s:gmatch("[^\r\n]+") do
    table.insert(lines,t)
  end
  return lines
end

function Tmi:load(instrument_id,filename)
  if tonumber(instrument_id) == nil then 
    -- find name 
    for _, dev in ipairs(midi.devices) do
      local name = string.lower(dev.name) 
      if dev.port ~= nil and string.find(name,string.lower(instrument_id)) then
        print("connecting "..filename.." to "..instrument_id)
        instrument_id = dev.port
      end
    end
  end
  if self.instrument[instrument_id]==nil then 
    print("tmi: could not find instrument '"..instrument_id.."'")
    do return end
  end
  lines=Tmi:load_pattern(filename)
  if lines==nil or #lines==0 then
    print("no filename "..filename)
    do return end
  end
  measures={}
  on={}
  last_note=nil
  first_line=nil
  for i,line in ipairs(lines) do
    if line~=nil and #line>0 then
      if first_line==nil then
        first_line=line
      end
      measures[i],on,last_note=self:parse_line(line,on,last_note)
      print(json.encode(measures[i]))
    end
  end
  if first_line~=nil then
    measures[1]=self:parse_line(first_line,on) -- turn off notes from the end
  end
  print(json.encode(measures))
  print(instrument_id,filename)
  self.instrument[instrument_id].track[filename]={
    measure=0,
    measures=measures,
  }
end

function Tmi:parse_line(line,on,last_note)
  beats={}
  for substring in line:gmatch("%S+") do
    table.insert(beats,substring)
  end
  l={}
  l.line=line
  l.division=#beats
  l.emit={}
  if on==nil then
    on={}
  end
  for i,b in ipairs(beats) do
    local emit={}
    velocity = 127
    if string.find(b,"_") then 
      foo = utils.string_split(b,"_")
      if tonumber(foo[2]) == nil then 
        print(foo[2])
        velocity = velocities[foo[2]]
      else
        velocity = tonumber(foo[2])
      end
      b = foo[1]
    end

    if #on>0 and b~="-" then
      -- turn off last beat
      beat=math.floor((i-1)*(ppm/l.division)-1)
      if beat<0 then
        beat=1
      end
      beat=""..beat
      if l.emit[beat]~=nil and l.emit[beat].off~=nil then
        table.insert(l.emit[beat].off,on)
      elseif l.emit[beat]~=nil then
        l.emit[beat].off=on
      else
        l.emit[beat]={off=on}
      end
      on={}
    end

    if b=="." then
    elseif b=="-" then
    else
      if b=="*" then
        b=beats[i-1]
      end
      for _,b0 in ipairs(utils.string_split(b,",")) do
        if tonumber(b0)~=nil then
          -- check if it is a cc, i.e. a number
          if l.emit[beat]==nil then
            l.emit[beat]={}
          elseif l.emit[beat].cc==nil then
            l.emit[beat].cc={}
          end
          table.insert(l.emit[beat].cc,b0)
        else
          on=music.to_midi(b0,last_note)
          tab.print(on)
          for i,_ in ipairs(on) do
            print("velocity"..velocity)
            on[i]["v"] = velocity 
            print("on[i]: "..json.encode(on[i]))
          end
          print("on: "..json.encode(on))
          beat=math.floor((i-1)*(ppm/l.division)+1)..""
          if l.emit[beat]~=nil and l.emit[beat].on~=nil then
            for i,_ in ipairs(on) do
              table.insert(l.emit[beat].on,on[i])
            end
            on = l.emit[beat].on
          elseif l.emit[beat]~=nil then
            l.emit[beat].on=on
          else
            l.emit[beat]={on=on}
          end
          last_note=on[1].m
        end
      end
    end
    ::continue::
  end
  return l,on,last_note
end


return Tmi
