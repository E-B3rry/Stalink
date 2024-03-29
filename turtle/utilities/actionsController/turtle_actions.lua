local TOOL_SIDE = "right"

local queue = {}
local queueID = {}
local lastID = 0

local completedID = {}
local failedID = {}

local turtleActions = {
  [0] = turtle.forward,
  [1] = turtle.back,
  [2] = turtle.turnLeft,
  [3] = turtle.turnRight,
  [4] = turtle.up,
  [5] = turtle.down,
  [6] = turtle.dig,
  [7] = turtle.digUp,
  [8] = turtle.digDown
}

function execute()
  print("Action queue : " .. tostring(#queue))
  while #queue > 0 do
    local action = table.remove(queue, 1)
    local id = table.remove(queueID, 1)
    print("Last element : " .. tostring(action) .. " - " .. tostring(id))

    if turtleActions[action](TOOL_SIDE) then
      completedID[id] = true
    else
      failedID[id] = true
    end
  end
end

function getResult(id)
  if completedID[id] then
    completedID[id] = nil
    return 1
  elseif failedID[id] then
    failedID[id] = nil
    return -1
  else
    return 0
  end
end

function fwd()
  table.insert(queue, 0)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 0}
end

function back()
  table.insert(queue, 1)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 1}
end

function left()
  table.insert(queue, 2)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 2}
end

function right()
  table.insert(queue, 3)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 3}
end

function up()
  table.insert(queue, 4)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 4}
end

function down()
  table.insert(queue, 5)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 5}
end

function dig()
  table.insert(queue, 6)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 6}
end

function digUp()
  table.insert(queue, 7)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 7}
end

function digDown()
  table.insert(queue, 8)
  table.insert(queueID, lastID)
  lastID = lastID + 1

  return {lastID - 1, 8}
end

print("Turtle Actions API Loaded")
