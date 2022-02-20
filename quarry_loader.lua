if not mainPath then
  local mainPathHandler = fs.open("/mainPath.dat", "r")
  mainPath = mainPathHandler.readLine()
  mainPathHandler.close()
end

if not mainPath then
  error("Cannot read mainPath file")
end

os.loadAPI(mainPath .. "turtle/quarry_mining/auto_quarry.lua")
