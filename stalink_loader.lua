
-- Loads Stalink 
-- Sets up main Path

if not fs.exists("Stalink/mainPath.dat") then 
  print("There is no file \"mainPath.dat\"")
  print("Make a file named \"mainPath.dat\" which contains the full path to this folder on your os")
  return
end

local h = fs.open("Stalink/mainPath.dat", "r")
mainPath = h.readLine()
if not mainPath then
  error("Cannot load mainPath file")
else
  print("Loading Stalink ...")
end

os.loadAPI("Stalink/handler/master/master.lua")
