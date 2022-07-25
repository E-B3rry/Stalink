-- Load stalink installation path
if not StalinkInstallationPath then
    local StalinkInstallationPathFile = fs.open("/stalink-path", "r")
    StalinkInstallationPath = StalinkInstallationPathFile.readLine()
    StalinkInstallationPathFile.close()
end

os.loadAPI(StalinkInstallationPath .. "turtle/utilities/mining/path_system.lua")


local pathObj = pathSystem.PathInit()

pathObj = pathSystem.TurnRight(pathObj)
pathObj = pathSystem.TurnRight(pathObj)
pathObj = pathSystem.TurnRight(pathObj)
pathObj = pathSystem.Forward(pathObj)
pathObj = pathSystem.Forward(pathObj)
pathObj = pathSystem.TurnLeft(pathObj)
pathObj = pathSystem.Upward(pathObj)
pathObj = pathSystem.Backward(pathObj)

sleep(5)

print(pathSystem.GoBack(pathObj))
