utils={}

function utils.last_modified(filename)
  local f = assert(io.popen("stat -c %Y "..filename))
  local last_modified = f:read()
  f:close()
  return last_modified
end

function utils.string_split(input_string,split_character)
  local s=split_character~=nil and split_character or "%s"
  local t={}
  if split_character=="" then
    for str in string.gmatch(input_string,".") do
      table.insert(t,str)
    end
  else
    for str in string.gmatch(input_string,"([^"..s.."]+)") do
      table.insert(t,str)
    end
  end
  return t
end

function utils.lines_from(file)
  if not utils.file_exists(file) then return {} end
  lines={}
  for line in io.lines(file) do
    lines[#lines+1]=line
  end
  return lines
end

-- see if the file exists
function utils.file_exists(file)
  local f=io.open(file,"rb")
  if f then f:close() end
  return f~=nil
end


return utils
