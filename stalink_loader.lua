mainPathHandle = fs.open("/mainPath.dat", "r")
mainPath = mainPathHandle.readLine()
mainPathHandle.close()

if not mainPath then
  error("Cannot load mainPath file")
end

os.loadAPI(mainPath .. "handler/master/master.lua")
