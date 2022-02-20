-- Load APIs --
local mainPath = fs.open("/mainPath.dat", "r")

A = mainPath.readLine()
os.loadAPI(A .. "turtle/utilities/mining/path_system.lua")
os.loadAPI(A .. "turtle/quarry_mining/quarry_mining.lua")
os.loadAPI(A .. "handler/utilities/requestUtils.lua")
os.loadAPI(A .. "redcom/redcom.lua")

mainPath.close()


--getmetatable('').__index = function(str,i) return string.sub(str,i,i) end

function writeF(txt)
  --print(tostring(txt))
  peripheral.call("left", "write", (tostring(txt).."\n"))
end


function Ask(RequestObj, rc)
  if RequestObj == "InitQuarry" then
    --redcom.lua.open(rc)
    redcom.sendRaw(10, os.getComputerID(), {["x"] = 10, ["y"] = 10, ["z"] = 10}, nil)
  end
end


-- Master Stalin --
redcom.open(10)

while true do
  c, rc, data, d = redcom.receiveRaw()
  writeF(data)
  Ask(data, rc)
end


-- Request System --

  --{id,msg (ex : QzrF0100 or SzrE1720 or QcrF0950 or QfrE0211)}
  --msg encryption// first char = first letter of the job in MAJ. thene zr = zone request // cr = chest request // fr = fuel request
  --E = empty inventory / F = full and M = space left in the inventory
  --Fuel level in 4 digits

  --Return code : {x,y,z(nil if no need), command}
