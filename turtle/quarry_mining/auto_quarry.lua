if not mainPath then
  local mainPathHandler = fs.open("/mainPath.dat", "r")
  mainPath = mainPathHandler.readLine()
  mainPathHandler.close()
end

os.loadAPI(mainPath .. "turtle/quarry_mining/quarry_mining.lua")
os.loadAPI(mainPath .. "turtle/utilities/inv/inventory.lua.lua")
os.loadAPI(mainPath .. "turtle/utilities/actionsController/turtle_actions.lua")
os.loadAPI(mainPath .. "redcom/redcom.lua")

sizeX = nil
sizeY = nil
sizeZ = nil

redcom.open(10)
redcom.sendRaw(10, os.getComputerID(), "InitQuarry", nil)

while not sizeX do
  c, rc, msg, d = redcom.receiveRaw()
  if msg then
    print("Received : " .. tostring(msg))
    if msg["x"] then
      sizeX = msg["x"]
      sizeY = msg["y"]
      sizeZ = msg["z"]
    end
  end
end

local Q = quarry_mining.createQuarry(
  true,
  {["x"] = sizeX, ["y"] = sizeY, ["z"] = sizeZ},
  {["x"] = 0, ["y"] = 0, ["z"] = 0},
  true,
  10,
  {["x"] = 880, ["y"] = 62, ["z"] = -814}
)

print("Blobfish:")

while Q["status"] ~= "success" do
  print("Blobfish 1")
  Q = quarry_mining.run(Q)
  print("Blobfish 2")
  turtle_actions.execute()
end

print("-- FINISHED --")
