local mainPath = fs.open("/mainPath.dat", "r")
mPath = mainPath.readLine() .. "turtle/utilities/mining/pathSystem"
os.loadAPI(mPath)

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
