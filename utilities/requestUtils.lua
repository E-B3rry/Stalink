-- Load APIs and set constants --
--local mainPath = fs.open("/mainPath.dat", "r")
--root = mainPath.readLine()

print("Loading request utils")
root = "Stalink/"
os.loadAPI("Stalink/redcom/redcom.lua")



MEETING_CHANNEL = 65135

print("Request Utils System Loaded")

-- Initialization function --
function Init()


end

-- Request system --

stalinedVariables = {}
stalinedUpdated = false

function receive()
  r = redcom.receive()

  if not r then
    returnValue = nil
  else

  end

end

function get_stalined_variable(var, value)
  if not type(var) == "string" then
    error("The var argument must be a string.", 2)
  end

  stalinedVariables[var] = value
  stalinedUpdated = true
end

function remove_stalined_variable(var)
  if not type(var) == "string" then
    error("The var argument must be a string.", 2)
  end

  stalinedVariables[var] = nil
  stalinedUpdated = true
end
