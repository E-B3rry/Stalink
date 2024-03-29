--- =======================
--- Path Interpreter Class (A class?)
--- =======================

-- TODO: Path system needs complete rework, it's horribly made.

-- Declaration as a Class

function PathInit()
  local pathObj = {}

  pathObj["pathList"] = {}
  pathObj["pathListSize"] = 0

  return pathObj
end

-- Path tracing functions

function TurnRight(pathObj)
  if pathObj["pathListSize"] ~= 0 then
    local pos = pathObj["pathListSize"]

    if string.find(pathObj["pathList"][pos], "r") then
      if pathObj["pathList"][pos] == "r1" then
        pathObj["pathList"][pos] = "r2"
      elseif pathObj["pathList"][pos] == "r2" then
        pathObj["pathList"][pos] = "l1"
      else
        pathObj["pathListSize"] = pos
      end

    elseif string.find(pathObj["pathList"][pos], "l") then
      if pathObj["pathList"][pos] == "l1" then
        pathObj["pathListSize"] = pos
      elseif pathObj["pathList"][pos] == "l2" then
        pathObj["pathList"][pos] = "l1"
      else
        pathObj["pathList"][pos] = "l2"
      end

    else
      pathObj["pathList"][pos + 1] = "r1"
      pathObj["pathListSize"] = pathObj["pathListSize"] + 1
    end
  else
    pathObj["pathList"] = {"r1"}
    pathObj["pathListSize"] = 1
  end

  turtle.turnRight()
  return pathObj
end


function TurnLeft(pathObj)
  if pathObj["pathListSize"] ~= 0 then
    local pos = pathObj["pathListSize"]

    if string.find(pathObj["pathList"][pos], "l") then
      if pathObj["pathList"][pos] == "l1" then
        pathObj["pathList"][pos] = "l2"
      elseif pathObj["pathList"][pos] == "l2" then
        pathObj["pathList"][pos] = "r1"
      else
        pathObj["pathListSize"] = pos
      end

    elseif string.find(pathObj["pathList"][pos], "r") then
      if pathObj["pathList"][pos] == "r1" then
        pathObj["pathListSize"] = pos
      elseif pathObj["pathList"][pos] == "r2" then
        pathObj["pathList"][pos] = "r1"
      else
        pathObj["pathList"][pos] = "r2"
      end

    else
      pathObj["pathList"][pos + 1] = "l1"
      pathObj["pathListSize"] = pathObj["pathListSize"] + 1
    end
  else
    pathObj["pathList"] = {"l1"}
    pathObj["pathListSize"] = 1
  end

  turtle.turnLeft()
  return pathObj
end


function Forward(pathObj)
  if pathObj["pathListSize"] ~= 0 then
    local pos = pathObj["pathListSize"]

    if string.find(pathObj["pathList"][pos], "f") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))

      if step then
        pathObj["pathList"][pos] = "f" .. tostring(step + 1)
      else
        pathObj["pathList"][pos] = "f1"
      end
    elseif string.find(pathObj["pathList"][pos], "b") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))

      if step then
        if step > 1 then
          pathObj["pathList"][pos] = "b" .. tostring(step - 1)
        else
          pathObj["pathListSize"] = pathObj["pathListSize"] - 1
        end
      else
        pathObj["pathList"][pos] = "f1"
      end
    else
      pathObj["pathList"][pos + 1] = "f1"
      pathObj["pathListSize"] = pathObj["pathListSize"] + 1
    end
  else
    pathObj["pathList"] = {"f1"}
    pathObj["pathListSize"] = 1
  end

  turtle.forward()
  return pathObj
end


function Backward(pathObj)
  if pathObj["pathListSize"] ~= 0 then
    local pos = pathObj["pathListSize"]

    if string.find(pathObj["pathList"][pos], "b") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))

      if step then
        pathObj["pathList"][pos] = "b" .. tostring(step + 1)
      else
        pathObj["pathList"][pos] = "b1"
      end
    elseif string.find(pathObj["pathList"][pos], "f") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))

      if step then
        if step > 1 then
          pathObj["pathList"][pos] = "f" .. tostring(step - 1)
        else
          pathObj["pathListSize"] = pathObj["pathListSize"] - 1
        end
      else
        pathObj["pathList"][pos] = "b1"
      end
    else
      pathObj["pathList"][pos + 1] = "b1"
      pathObj["pathListSize"] = pathObj["pathListSize"] + 1
    end
  else
    pathObj["pathList"] = {"b1"}
    pathObj["pathListSize"] = 1
  end

  turtle.back()
  return pathObj
end


function Upward(pathObj)
  if pathObj["pathListSize"] ~= 0 then
    local pos = pathObj["pathListSize"]

    if string.find(pathObj["pathList"][pos], "u") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))

      if step then
        pathObj["pathList"][pos] = "u" .. tostring(step + 1)
      else
        pathObj["pathList"][pos] = "u1"
      end
    elseif string.find(pathObj["pathList"][pos], "d") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))

      if step then
        if step > 1 then
          pathObj["pathList"][pos] = "d" .. tostring(step - 1)
        else
          pathObj["pathListSize"] = pathObj["pathListSize"] - 1
        end
      else
        pathObj["pathList"][pos] = "u1"
      end
    else
      pathObj["pathList"][pos + 1] = "u1"
      pathObj["pathListSize"] = pathObj["pathListSize"] + 1
    end
  else
    pathObj["pathList"] = {"u1"}
    pathObj["pathListSize"] = 1
  end

  turtle.up()
  return pathObj
end


function Downward(pathObj)
  if pathObj["pathListSize"] ~= 0 then
    local pos = pathObj["pathListSize"]

    if string.find(pathObj["pathList"][pos], "d") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))

      if step then
        pathObj["pathList"][pos] = "d" .. tostring(step + 1)
      else
        pathObj["pathList"][pos] = "d1"
      end
    elseif string.find(pathObj["pathList"][pos], "u") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))

      if step then
        if step > 1 then
          pathObj["pathList"][pos] = "u" .. tostring(step - 1)
        else
          pathObj["pathListSize"] = pathObj["pathListSize"] - 1
        end
      else
        pathObj["pathList"][pos] = "d1"
      end
    else
      pathObj["pathList"][pos + 1] = "d1"
      pathObj["pathListSize"] = pathObj["pathListSize"] + 1
    end
  else
    pathObj["pathList"] = {"d1"}
    pathObj["pathListSize"] = 1
  end

  turtle.down()
  return pathObj
end

function GoBack(pathObj)
  while pathObj["pathListSize"] > 0 do
    write("run " .. pathObj["pathListSize"])
    pos = pathObj["pathListSize"]

    if string.find(pathObj["pathList"][pos], "l") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))
      write(" - right : " .. tostring(step) .. " - " .. string.sub(pathObj["pathList"][pos], 2))

      if step then
        for i = 1, step do
          if not turtle.turnRight() then return false, "r", step - i end
        end
      end

      pathObj["pathListSize"] = pathObj["pathListSize"] - 1

    elseif string.find(pathObj["pathList"][pos], "r") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))
      write(" - left : " .. tostring(step) .. " - " .. string.sub(pathObj["pathList"][pos], 2))

      if step then
        for i = 1, step do
          if not turtle.turnLeft() then return pathObj, false, "l", step - i end
        end
      end

      pathObj["pathListSize"] = pathObj["pathListSize"] - 1

    elseif string.find(pathObj["pathList"][pos], "f") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))
      write(" - backward : " .. tostring(step) .. " - " .. string.sub(pathObj["pathList"][pos], 2))

      if step then
        for i = 1, step do
          if not turtle.back() then return pathObj, false, "b", step - i end
        end
      end

      pathObj["pathListSize"] = pathObj["pathListSize"] - 1

    elseif string.find(pathObj["pathList"][pos], "b") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))
      write(" - forward : " .. tostring(step) .. " - " .. string.sub(pathObj["pathList"][pos], 2))

      if step then
        for i = 1, step do
          if not turtle.forward() then return pathObj, false, "f", step - i end
        end
      end

      pathObj["pathListSize"] = pathObj["pathListSize"] - 1

    elseif string.find(pathObj["pathList"][pos], "u") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))
      write(" - down : " .. tostring(step) .. " - " .. string.sub(pathObj["pathList"][pos], 2))

      if step then
        for i = 1, step do
          if not turtle.down() then return pathObj, false, "d", step - i end
        end
      end

      pathObj["pathListSize"] = pathObj["pathListSize"] - 1

    elseif string.find(pathObj["pathList"][pos], "d") then
      step = tonumber(string.sub(pathObj["pathList"][pos], 2))
      write(" - up : " .. tostring(step) .. " - " .. string.sub(pathObj["pathList"][pos], 2))

      if step then
        for i = 1, step do
          if not turtle.up() then return pathObj, false, "u", step - i end
        end
      end

      pathObj["pathListSize"] = pathObj["pathListSize"] - 1

    elseif string.find(pathObj["pathList"][pos], "w") then
      return pathObj, true
    end

    write("\n")
  end

  return pathObj, true, "end"
end

function Waypoint(pathObj)
  pathObj["pathList"][pathObj["pathListSize"]] = "w"
  pathObj["pathListSize"] = pathObj["pathListSize"] + 1
end

-- Path retracing functions


print("Path System Loaded")
