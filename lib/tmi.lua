json=include("tmi/lib/json")
music=include("tmi/lib/music")
utils=include("tmi/lib/utils")
lattice=include("kolor/lib/lattice")

local Tmi={}
local velocities={
  pp=30,
  p=40,
  mp=50,
  mf=60,
  f=80,
  ff=100,
  fff=127,
}

function Tmi:new(args)
  local m=setmetatable({},{__index=Tmi})
  local args=args==nil and {} or args
  m.meter=args.meter==nil and 4 or args.meter
  m.ppqn=args.ppqn==nil and 48 or args.ppqn
  m.ppm=m.ppqn*m.meter
  m.playing=false
  m.loading=false
  m.instrument={}
  for _,dev in pairs(midi.devices) do
    tab.print(dev)
    if dev.port~=nil then
      m.instrument[dev.port]={
        name=dev.name,
        port=dev.port,
        midi=midi.connect(dev.port),
        track={},
      }
    end
  end
  m.lattice=lattice:new({
    ppqn=m.ppqn,
    meter=m.meter,
  })
  m.timer=m.lattice:new_pattern{
    action=function(t)
      m:emit_note(t)
    end,
    division=1/m.ppm
  }
  m.measure=-1
  if #m.instrument==0 then
    print("tmi: could not start, no midi instruments")
    do return m end
  end
  m:add_parameters()
  return m
end

function Tmi:add_parameters()
  local names={}
  for _,dev in ipairs(self.instrument) do
    local name=string.lower(dev.name)
    table.insert(names,{port=dev.port,name=dev.name})
  end
  if #names==0 then
    print("tmi: no midi devices")
    do return end
  end
  params:add_group("TMI",#names*9+1)
  params:add{type='binary',name="playing",id='tmi_playing',behavior='toggle',
    action=function(value)
      self.playing=value==1
      if not self.playing then
        print("tmi: stopping")
        self.lattice:stop()
        self:stop_notes()
        self.measure=-1
      else
        self.lattice:hard_sync()
      end
    end
  }
  local name_folder=_path.data.."tmi/"
  print("tmi: name_folder: "..name_folder)
  for _,dev in ipairs(names) do
    params:add_separator(dev.name)
    for i=1,4 do
      params:add_file(dev.port..i.."load_name_tmi","slot "..i,name_folder)
      params:set_action(dev.port..i.."load_name_tmi",function(x)
        if #x<=#name_folder then
          do return end
        end
        pathname,filename,ext=string.match(x,"(.-)([^\\/]-%.?([^%.\\/]*))$")
        print("loading "..filename.." into "..dev.name..i)
        self:_load(dev.port,x,i)
      end)
      params:add{type='binary',name="mute slot "..i,id=dev.port..i.."load_name_tmi_mute",behavior='toggle',
        action=function(value)
          if self.instrument[dev.port].track[i]~=nil then
            self.instrument[dev.port].track[i].mute=value==1
            if self.instrument[dev.port].track[i].mute then
              self:stop_notes(dev.port,i)
            end
          end
        end
      }
    end
  end
end

function Tmi:stop_notes(instrument_id,slot)
  for k,instrument in ipairs(self.instrument) do
    if instrument_id==nil or (instrument_id==k) then
      for i,track in pairs(instrument.track) do
        if slot==nil or (slot==i) then
          for note,_ in pairs(track.notes_on) do
            print("stopping note "..note.." on instrument "..k.." on slot "..i)
            instrument.midi:note_off(note)
            self.instrument[k].track[i].notes_on[note]=nil
          end
        end
      end
    end
  end
end

function Tmi:toggle_play()
  print("toggle_play")
  params:set('tmi_playing',1-params:get('tmi_playing'))
end

function Tmi:is_playing()
  if #self.instrument == 0 then 
    return false 
  else
    return params:get("tmi_playing")==1 
  end
end

function Tmi:live_reload()
  for i,instrument in ipairs(self.instrument) do
    for slot,track in pairs(instrument.track) do
      if track.last_modified~=utils.last_modified(track.filename) then
        print("live reloading instrument "..i.." with filename "..track.filename)
        clock.run(function()
          self:_load(i,track.filename,track.slot)
          self:stop_notes(i,slot)
        end)
      end
    end
  end
end

function Tmi:emit_note(t)
  beat=t%self.ppm+1
  if beat==1 then
    self.measure=self.measure+1
  end
  if self.loading then
    do return end
  end
  local note_off=false
  for k,instrument in ipairs(self.instrument) do
    for i,track in pairs(instrument.track) do
      if #track.measures==0 or track.mute then
        goto continue
      end
      local measure=(self.measure%#track.measures)+1
      local notes=self.instrument[k].track[i].measures[measure].emit[beat..""]
      if notes~=nil then
        -- print(k,i,measure,beat,json.encode(notes))
        if notes.off~=nil then
          for _,note in ipairs(notes.off) do
            if self.instrument[k].track[i].notes_on[note.m]~=nil then
              self.instrument[k].midi:note_off(note.m)
              self.instrument[k].track[i].notes_on[note.m]=nil
              note_off=true
            end
          end
        end
        if notes.cc~=nil then
          -- TODO: emit the ccs
        end
        if notes.on~=nil then
          for _,note in ipairs(notes.on) do
            if note.m~=nil then
              print("tmi: instrument "..k..", track "..i..", measure "..(self.measure+1)..", beat "..((beat-1)/self.ppqn+1)..", note_on="..note.m)
              self.instrument[k].midi:note_on(note.m,note.v)
              self.instrument[k].track[i].notes_on[note.m]=true
            end
          end
        end
      end
      ::continue::
    end
  end
  if note_off then
    self:live_reload()
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
    if #s>0 and s[1]~="#" then -- comment
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

function Tmi:load(instrument_id,filename,slot)
  local instrument_id_original=instrument_id
  if slot==nil then
    slot=1
  end
  if tonumber(instrument_id_original)==nil then
    instrument_id=nil
    -- find name
    for i,dev in ipairs(self.instrument) do
      print(dev.name,dev.port)
      if dev.port~=nil and string.find(string.lower(dev.name),string.lower(instrument_id_original)) then
        print("tmi: connecting "..filename.." to "..instrument_id_original)
        instrument_id=i
      end
    end
  end
  if instrument_id~=nil then
    params:set(instrument_id..slot.."load_name_tmi",filename)
  else
    print("could not find "..instrument_id_original)
  end
end

function Tmi:_load(instrument_id,filename,slot)
  self.loading=true
  if self.instrument[instrument_id]==nil then
    print("tmi: could not find instrument '"..instrument_id.."'")
    self.loading=false
    do return end
  end
  lines=Tmi:load_pattern(filename)
  if lines==nil or #lines==0 then
    print("tmi: no filename "..filename)
    self.loading=false
    do return end
  end
  measures={}
  on={}
  last_note=nil
  first_line=nil
  for i,line in ipairs(lines) do
    if line~=nil and #line>0 then
      if string.find(line,"#") then
        -- remove comment
        local foo=utils.string_split(line,"#")
        line=foo[1]
      end
      if first_line==nil then
        first_line=line
      end
      measures[i],on,last_note=self:parse_line(line,on,last_note)
      -- print(json.encode(measures[i]))
    end
  end
  if first_line~=nil then
    measures[1]=self:parse_line(first_line,on) -- turn off notes from the end
  end
  -- print(json.encode(measures))
  -- print(instrument_id,filename)
  if slot==nil then
    slot=filename
  end
  self:stop_notes(instrument_id,slot)
  self.instrument[instrument_id].track[slot]={
    measure=0,
    measures=measures,
    last_modified=utils.last_modified(filename),
    filename=filename,
    slot=slot,
    notes_on={},
    mute=params:get(instrument_id..slot.."load_name_tmi_mute")==1,
  }
  self.loading=false
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
    velocity=127
    if string.find(b,"_") then
      foo=utils.string_split(b,"_")
      if tonumber(foo[2])==nil then
        velocity=velocities[foo[2]]
      else
        velocity=tonumber(foo[2])
      end
      b=foo[1]
    end

    if #on>0 and b~="-" then
      -- turn off last beat
      beat=math.floor((i-1)*(self.ppm/l.division)-1)
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
          for i,_ in pairs(on) do
            on[i]["v"]=velocity
          end
          beat=math.floor((i-1)*(self.ppm/l.division)+1)..""
          if l.emit[beat]~=nil and l.emit[beat].on~=nil then
            for i,_ in ipairs(on) do
              table.insert(l.emit[beat].on,on[i])
            end
            on=l.emit[beat].on
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
