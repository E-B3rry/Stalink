local mainPathHandle = fs.open("/mainPath.dat", "r")
mainPath = mainPathHandle.readLine()
mainPathHandle.close()

os.loadAPI(mainPath .. "turtle/utilities/inv/inventory.lua")
os.loadAPI(mainPath .. "turtle/quarry_mining/quarry_mining.lua")

function RunQuarry(quarryObj)
  if not quarryObj then
    return false
  end

  while (quarryObj["status"] ~= "success") do
    quarryObj = quarryMining.run(quarryObj)
  end

  return true
end



--quarryObj = quarry_mining.createQuarry(
--  true,
--  {["x"] = 10, ["y"] = 50, ["z"] = 10},
--  {["x"] = 0, ["y"] = 0, ["z"] = -1},
--  true,
--  1,
--  nil
--)

--while (quarryObj["status"] ~= "success") do
--  quarryObj = quarry_mining.run(quarryObj)
--end
