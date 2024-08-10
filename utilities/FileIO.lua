local FileIO = {}

-- Check if files exists 
function FileIO.file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

--Read lines from a file 
--Return an empty list if files does not exist 
function FileIO.readFile(file) 
  print("reading " .. file)
  if not FileIO.file_exists(file) then return {} end 
  local lines = {}
  for line in io.lines(file) do 
    print(line) 
    lines[#lines + 1] = line 
  end 
  return lines 
end


return FileIO
