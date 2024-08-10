--- Load APIs ---

-- Load stalink installation path
--if not StalinkInstallationPath then
--  local StalinkInstallationPathFile = fs.open("/stalink-path", "r")
--  StalinkInstallationPath = StalinkInstallationPathFile.readLine()
--  StalinkInstallationPathFile.close()
--end
StalinkInstallationPath = "Stalink/"

os.loadAPI(StalinkInstallationPath .. "turtle/utilities/mining/path_system.lua")
os.loadAPI(StalinkInstallationPath .. "turtle/quarry_mining/quarry_mining.lua")
--Doesnt work yet
os.loadAPI(StalinkInstallationPath .. "utilities/requestUtils.lua")
os.loadAPI(StalinkInstallationPath .. "redcom/redcom.lua")


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
  c, rc, data, d = redcom.receiveRaw(true)
  writeF(data)
  Ask(data, rc)
end


-- Request System --

  --{id,msg (ex : QzrF0100 or SzrE1720 or QcrF0950 or QfrE0211)}
  --msg encryption// first char = first letter of the job in MAJ. thene zr = zone request // cr = chest request // fr = fuel request
  --E = empty inventory / F = full and M = space left in the inventory
  --Fuel level in 4 digits

  --Return code : {x,y,z(nil if no need), command}
