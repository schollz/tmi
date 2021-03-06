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
  m.functions=args.functions==nil and {} or args.functions
  -- sanitize functions
  for i,f in ipairs(m.functions) do
    if f.midi == nil then 
      m.functions[i].midi = false 
    end
    if f.hz == nil then 
      m.functions[i].hz = false 
    end
  end

  m.ppm=m.ppqn*m.meter
  m.playing=false
  m.loading=false

  -- add instruments
  m.instrument={}
  local found_instruments=false
  for _,dev in pairs(midi.devices) do
    if dev.port~=nil then
      local name = string.lower(dev.name)
      print("adding "..name.." to port "..dev.port)
      found_instruments=true
      m.instrument[name]={
        name=dev.name,
        port=dev.port,
        midi=midi.connect(dev.port),
        track={},
        is_midi=true,
        is_function=false,
      }
    end
  end

  -- add custom functions
  -- {name="enginehz",note_on="engine.hz(MusicUtil.note_num_to_freq(<note>),<velocity>)",note_off=""}
  for i,f in ipairs(m.functions) do 
    --TODO: add functions to save/load
    found_instruments = true
    m.instrument[f.name] = {
        name=f.name,
        note_on=f.note_on,
        note_off=f.note_off,
        track={},
        is_midi=false,
        is_function=true, -- is function!
    }
  end
  -- start lattice
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
  if not found_instruments then
    print("tmi: could not start, no midi instruments")
    do return m end
  end
  m:add_parameters()
  return m
end

function Tmi:add_parameters()
  local names={}
  for name,dev in pairs(self.instrument) do
    local name=string.lower(dev.name)
    table.insert(names,name)
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
  for _,name in ipairs(names) do
    params:add_separator(name)
    for i=1,4 do
      params:add_file(name..i.."load_name_tmi","slot "..i,name_folder)
      params:set_action(name..i.."load_name_tmi",function(x)
        if #x<=#name_folder then
          do return end
        end
        pathname,filename,ext=string.match(x,"(.-)([^\\/]-%.?([^%.\\/]*))$")
        print("loading "..filename.." into "..name..i)
        self:_load(name,x,i)
      end)
      params:add_control(name..i.."scaling","scaling",controlspec.new(0,10,"lin",0.01,1,"x",0.02/10))
      params:set_action(name..i.."scaling",function(x)
        if self.instrument[name].track[i]~=nil then
          self.instrument[name].track[i].mute=x==0
          if self.instrument[name].track[i].mute then
            self:stop_notes(name,i)
          end
        end
      end)
    end
  end
end

function Tmi:stop_notes(instrument_name,slot)
  for name,instrument in pairs(self.instrument) do
    if instrument_name==nil or (instrument_name==name) then
      for i,track in pairs(instrument.track) do
        if slot==nil or (slot==i) then
          for note,_ in pairs(track.notes_on) do
            print("stopping note "..note.." on instrument "..name.." on slot "..i)
            self:note_on_off(name,note)
            -- instrument.midi:note_off(note)
            self.instrument[name].track[i].notes_on[note]=nil
          end
        end
      end
    end
  end
end

function Tmi:note_on_off(instrument_name,note,velocity)
  if self.instrument[instrument_name] == nil then 
    print("tmi: note_off: could not find instrument "..instrument_name)
    do return end
  end
  if self.instrument[instrument_name].is_midi then 
    if velocity~=nil then 
      self.instrument[instrument_name].midi:note_on(note,velocity)
    else
      self.instrument[instrument_name].midi:note_off(note)
    end
  elseif self.instrument[instrument_name].is_function then 
    local f = self.instrument[instrument_name].note_on
    if velocity == nil then 
      f = self.instrument[instrument_name].note_off
    end
    if f == nil then 
      do return end 
    end
    f = f:gsub("%<note>",note.."")
    if velocity ~= nil then 
      f = f:gsub("%<velocity>",velocity.."")
    end
    frun = load(f)
    frun() -- runs function, whatever it is
  end
end

function Tmi:toggle_play()
  print("toggle_play")
  params:set('tmi_playing',1-params:get('tmi_playing'))
end

function Tmi:is_playing()
  return self.playing
end

function Tmi:live_reload()
  for i,instrument in pairs(self.instrument) do
    for slot,track in pairs(instrument.track) do
      if track.last_modified~=utils.last_modified(track.filename) then
        print("live reloading instrument "..i.." with filename "..track.filename)
        clock.run(function()
          notes_on={table.unpack(track.notes_on)}
          self:_load(i,track.filename,track.slot)
          self.instrument[i].track[slot].notes_on=notes_on
          -- check if any measures changed and turn those notes off
          -- if they are currently playing
          for note,notedat in pairs(notes_on) do
            local notes=self.instrument[i].track[slot].measures[notedat.measure].emit[notedat.beat..""]
            -- make sure note on is still in the ntoes
            if notes~=nil and notes.on~=nil and notes.on[notedat.notei]~=nil and notes.on[notedat.notei].m==note.m then
              -- all good
            else
              -- stop this particular note
              print("need to stop note "..note.m)
              self.instrument[i].midi:note_off(note.m)
              self.instrument[i].track[slot].notes_on[note.m]=nil
            end
          end
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
  for name,instrument in pairs(self.instrument) do
    for i,track in pairs(instrument.track) do
      if #track.measures==0 or track.mute then
        goto continue
      end
      local measure=(self.measure%#track.measures)+1
      local notes=self.instrument[name].track[i].measures[measure].emit[beat..""]
      if notes~=nil then
        -- turn off notes that are done
        if notes.off~=nil then
          for _,note in ipairs(notes.off) do
            if self.instrument[name].track[i].notes_on[note.m]~=nil then
              self:note_on_off(name,note.m)
              -- self.instrument[name].midi:note_off(note.m)
              self.instrument[name].track[i].notes_on[note.m]=nil
              note_off=true
            end
          end
        end
        if notes.cc~=nil then
          -- emit the ccs
          for _,cc in ipairs(notes.cc) do
            local val=math.floor(util.clamp(cc.val*params:get(name..track.slot.."scaling"),0,127))
            print("tmi: instrument "..name..", track "..i..", measure "..(self.measure+1)..", beat "..((beat-1)/self.ppqn+1)..", cc="..cc.num..", val="..val)
            self.instrument[name].midi:cc(cc.num,val)
          end
        end
        if notes.on~=nil then
          -- emit the notes
          for notei,note in ipairs(notes.on) do
            if note.m~=nil then
              local velocity=math.floor(util.clamp(note.v*params:get(name..track.slot.."scaling"),0,127))
              print("tmi: instrument "..name..", track "..i..", measure "..(self.measure+1)..", beat "..((beat-1)/self.ppqn+1)..", note_on="..note.m..", v="..velocity)
              self:note_on_off(name,note.m,velocity)
              -- self.instrument[name].midi:note_on(note.m,velocity)
              self.instrument[name].track[i].notes_on[note.m]={measure=measure,beat=beat,notei=notei}
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

function Tmi:load(instrument_name,filename,slot)
  local instrument_name_original=instrument_name
  if slot==nil then
    slot=1
  end
  if tonumber(instrument_name_original)==nil then
    instrument_name=nil
    -- find name
    for name,dev in pairs(self.instrument) do
      print(dev.name,dev.port)
      if ((dev.port~=nil and dev.is_midi) or not dev.is_midi) and string.find(string.lower(name),string.lower(instrument_name_original)) then
        print("tmi: connecting "..filename.." to "..instrument_name_original)
        instrument_name=name
      end
    end
  end
  if instrument_name~=nil then
    params:set(instrument_name..slot.."load_name_tmi",filename)
  else
    print("tmi: load: could not find "..instrument_name_original)
  end
end

function Tmi:_load(instrument_name,filename,slot)
  self.loading=true
  if self.instrument[instrument_name]==nil then
    print("tmi: _load: could not find instrument '"..instrument_name.."'")
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
  -- print(instrument_name,filename)
  if slot==nil then
    slot=filename
  end
  self:stop_notes(instrument_name,slot)
  self.instrument[instrument_name].track[slot]={
    measure=0,
    measures=measures,
    last_modified=utils.last_modified(filename),
    filename=filename,
    slot=slot,
    notes_on={},
    mute=params:get(instrument_name..slot.."scaling")==0,
    volume=1.0,
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
      local note_parts=utils.string_split(b,",")
      beat=math.floor((i-1)*(self.ppm/l.division)+1)..""
      for j,b0 in ipairs(note_parts) do
        if tonumber(b0)~=nil then
          -- part is a number, assume it is a cc
          -- ccs are pairs of integers, the cc number followed by value
          if (j-1)%2==1 then
            local cc_number=note_parts[j-1]
            local cc_value=note_parts[j]
            if l.emit[beat]==nil then
              l.emit[beat]={cc={}}
            end
            print(cc_number,cc_value)
            table.insert(l.emit[beat].cc,{num=cc_number,val=cc_value})
          end
        else
          on=music.to_midi(b0,last_note)
          for i,_ in pairs(on) do
            on[i]["v"]=velocity
          end
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
