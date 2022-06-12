if not stalinkRoot then
  local mainPathHandler = fs.open("/mainPath.dat", "r")
  stalinkRoot = mainPathHandler.readLine()
  mainPathHandler.close()
end

if not stalinkRoot then
  error("Cannot read mainPath file")
end

os.loadAPI(stalinkRoot .. "turtle/quarry_mining/auto_quarry.lua")
