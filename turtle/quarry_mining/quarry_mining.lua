local TOOL_SIDE = "left"
local LIQUIDS = {"minecraft:water", "minecraft:lava"}

local lastID = 0

function tableContains(table, element)
    for k, value in ipairs(table) do
        if value == element then return true end
    end

    return false
end

function createQuarry(running, size, relativesToChest, doRefuelWithMaterials, priority, realCoordinates)
  quarryObject = {
    ["id"] = {os.getComputerID(), lastID},
    ["status"] = "mining",

    ["actualX"] = 0,
    ["actualY"] = 0,
    ["actualZ"] = 0,
    ["facing"] = 0,

    ["lastAction"] = nil,
    ["lastErrors"] = {},

    ["realX"] = (realCoordinates and realCoordinates["x"] or nil),
    ["realY"] = (realCoordinates and realCoordinates["y"] or nil),
    ["realZ"] = (realCoordinates and realCoordinates["z"] or nil),

    ["xSize"] = size["x"] - 1,
    ["ySize"] = size["y"] - 1,
    ["zSize"] = size["z"] - 1,

    ["chestX"] = relativesToChest["x"],
    ["chestY"] = relativesToChest["y"],
    ["chestZ"] = relativesToChest["z"],

    ["selfRefuel"] = doRefuelWithMaterials,
    ["priority"] = (priority and priority or 0),
  }

  lastID = lastID + 1

  return quarryObject
end

function returnToMainPos(quarryObject)
  if quarryObject["facing"] ~= 0 and (quarryObject["actualY"] > 0 or quarryObject["actualZ"] > 0) then
    if quarryObject["facing"] < 3 then
      quarryObject["lastAction"] = turtle_actions.left()
    else
      quarryObject["lastAction"] = turtle_actions.right()
    end
  elseif quarryObject["actualY"] > 0 then
    quarryObject["lastAction"] = turtle_actions.up()
  elseif quarryObject["actualZ"] > 0 then
    quarryObject["lastAction"] = turtle_actions.back()
  elseif quarryObject["actualX"] > 0 then
    if quarryObject["facing"] < 2 then
      quarryObject["lastAction"] = turtle_actions.left()
    elseif quarryObject["facing"] == 2 then
      quarryObject["lastAction"] = turtle_actions.right()
    else
      quarryObject["lastAction"] = turtle_actions.fwd()
    end
  end

  if quarryObject["actualX"] == 0 and quarryObject["actualY"] == 0 and quarryObject["actualZ"] == 0 then
    if quarryObject["status"] == "ended" then
      if quarryObject["facing"] > 1 then
        quarryObject["lastAction"] = turtle_actions.right()
      elseif quarryObject["facing"] == 1 then
        quarryObject["lastAction"] = turtle_actions.left()
      else
        quarryObject["status"] = "success"
      end
    else
      quarryObject["status"] = "atStartingPoint"
    end
  end

  return quarryObject
end

function mining(quarryObject)
  inspect = turtle.detectDown()
  print(tostring(inspect))

  if quarryObject["actualX"] == (quarryObject["xSize"] * ((quarryObject["actualY"] + 1) % 2)) and quarryObject["actualZ"] == (quarryObject["zSize"] * ((quarryObject["actualX"] + quarryObject["actualY"] + 1) % 2)) then
    if quarryObject["actualY"] >= quarryObject["ySize"] then
      quarryObject["status"] = "ended"

      return quarryObject
    end

    if inspect then
      quarryObject["lastAction"] = turtle_actions.digDown(TOOL_SIDE)
    else
      quarryObject["lastAction"] = turtle_actions.down()
    end

    return quarryObject
  end

  inspect = turtle.detect()
  print(tostring(inspect))

  if (math.abs(quarryObject["actualX"] + quarryObject["actualY"]) % 2 == 1) then
    if quarryObject["actualZ"] > 0 then
      if quarryObject["facing"] == 2 then
        if inspect then
          quarryObject["lastAction"] = turtle_actions.dig()
        else
          quarryObject["lastAction"] = turtle_actions.fwd()
        end
      elseif quarryObject["facing"] == 0 or quarryObject["facing"] == 1 then
        quarryObject["lastAction"] = turtle_actions.right()
      elseif quarryObject["facing"] == 3 then
        quarryObject["lastAction"] = turtle_actions.left()
      end
    else
      if quarryObject["actualY"] % 2 == 1 then
        if quarryObject["facing"] == 2 then
          quarryObject["lastAction"] = turtle_actions.right()
        elseif inspect then
          quarryObject["lastAction"] = turtle_actions.dig()
        else
          quarryObject["lastAction"] = turtle_actions.fwd()
        end
      else
        if quarryObject["facing"] == 2 then
          quarryObject["lastAction"] = turtle_actions.left()
        elseif inspect then
          quarryObject["lastAction"] = turtle_actions.dig()
        else
          quarryObject["lastAction"] = turtle_actions.fwd()
        end
      end
    end
  else
    if quarryObject["actualZ"] < quarryObject["zSize"] then
      if quarryObject["facing"] == 0 then
        if inspect then
          quarryObject["lastAction"] = turtle_actions.dig()
        else
          quarryObject["lastAction"] = turtle_actions.fwd()
        end
      elseif quarryObject["facing"] == 1 or quarryObject["facing"] == 2 then
        quarryObject["lastAction"] = turtle_actions.left()
      elseif quarryObject["facing"] == 3 then
        quarryObject["lastAction"] = turtle_actions.right()
      end
    else
      if quarryObject["actualY"] % 2 == 1 then
        if quarryObject["facing"] == 0 then
          quarryObject["lastAction"] = turtle_actions.left()
        elseif inspect then
          quarryObject["lastAction"] = turtle_actions.dig()
        else
          quarryObject["lastAction"] = turtle_actions.fwd()
        end
      else
        if quarryObject["facing"] == 0 then
          quarryObject["lastAction"] = turtle_actions.right()
        elseif inspect then
          quarryObject["lastAction"] = turtle_actions.dig()
        else
          quarryObject["lastAction"] = turtle_actions.fwd()
        end
      end
    end
  end

  return quarryObject
end

function run(quarryObject)
  -- Check if the last action has been correctly executed --
  if quarryObject["lastAction"] then
    if turtle_actions.getResult(quarryObject["lastAction"][1]) > 0 then
      local action = quarryObject["lastAction"][2]

      if action == 0 then
        local facing = quarryObject["facing"]

        if facing == 0 then
          quarryObject["actualZ"] = quarryObject["actualZ"] + 1
        elseif facing == 1 then
          quarryObject["actualX"] = quarryObject["actualX"] + 1
        elseif facing == 2 then
          quarryObject["actualZ"] = quarryObject["actualZ"] - 1
        elseif facing == 3 then
          quarryObject["actualX"] = quarryObject["actualX"] - 1
        end
      elseif action == 1 then
        local facing = quarryObject["facing"]

        if facing == 0 then
          quarryObject["actualZ"] = quarryObject["actualZ"] - 1
        elseif facing == 1 then
          quarryObject["actualX"] = quarryObject["actualX"] - 1
        elseif facing == 2 then
          quarryObject["actualZ"] = quarryObject["actualZ"] + 1
        elseif facing == 3 then
          quarryObject["actualX"] = quarryObject["actualX"] + 1
        end
      elseif action == 2 then
        quarryObject["facing"] = (quarryObject["facing"] - 1) % 4
      elseif action == 3 then
        quarryObject["facing"] = (quarryObject["facing"] + 1) % 4
      elseif action == 4 then
        quarryObject["actualY"] = quarryObject["actualY"] - 1
      elseif action == 5 then
        quarryObject["actualY"] = quarryObject["actualY"] + 1
      end

      quarryObject["lastErrors"] = {}
    else
      -- Register the error if the last action failed
      quarryObject["lastErrors"][1] = (quarryObject["lastErrors"][2] == quarryObject["lastAction"][2]) and (quarryObject["lastErrors"][1] + 1) or 0
      quarryObject["lastErrors"][2] = quarryObject["lastAction"][2]
    end

    quarryObject["lastAction"] = nil
  end

  -- Check if the turtle still has place --
  --hasPlace = inventory.hasTurtleInvHasEmptySlots()

  --if not hasPlace then
  --  quarryObject["status"] = "returning"
  --  return quarryObject
  --end

  local fuelLevel = turtle.getFuelLevel()
  local processedStepsLeftFuel = quarryObject["actualX"] + quarryObject["actualY"] + quarryObject["actualZ"] + math.abs(quarryObject["chestX"]) + math.abs(quarryObject["chestY"]) + math.abs(quarryObject["chestZ"])

  if processedStepsLeftFuel > fuelLevel - 10 then
    if quarryObject["doRefuelWithMaterials"] then
      if not inventory.refuelTurtle() then
        quarryObject["status"] = "returning"
      end
    else
      quarryObject["status"] = "returning"
    end
  end

  if quarryObject["status"] == "ended" or quarryObject["status"] == "returning" then
    quarryObject = returnToMainPos(quarryObject)
  elseif quarryObject["status"] == "mining" then
    quarryObject = mining(quarryObject)
  end

  return quarryObject
end

print("Quarry Mining Loaded")
