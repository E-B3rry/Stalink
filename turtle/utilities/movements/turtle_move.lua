-- DISABLED

local queue = {}
local queueID = {}

local completedID = {}
local failedID = {}

local lastID = 0
local isRunning = false

local movingActions = {
  [0] = turtle.forward(),
  [1] = turtle.back(),
  [2] = turtle.up(),
  [3] = turtle.down(),
  [4] = turtle.left(),
  [5] = turtle.right()
}

function run()
  if isRunning then
    return true
  else
    isRunning = true
  end

  while isRunning do
    if #queue > 0 then
      local action = queue.remove(1)
      local id = queueID.remove(1)

      if movingActions[action] then
        completedID.insert(id)
      else
        failedID.insert(id)
      end
    end

    isRunning = coroutine.yield() == false
  end
end

function front()
  queue.insert(0)
  queueID.insert(lastID)
  lastID = lastID + 1

  return lastID - 1
end

function back()
  queue.insert(1)
  queueID.insert(lastID)
  lastID = lastID + 1

  return lastID - 1
end

function up()
  queue.insert(2)
  queueID.insert(lastID)
  lastID = lastID + 1

  return lastID - 1
end

function down()
  queue.insert(3)
  queueID.insert(lastID)
  lastID = lastID + 1

  return lastID - 1
end

function left()
  queue.insert(4)
  queueID.insert(lastID)
  lastID = lastID + 1

  return lastID - 1
end

function right()
  queue.insert(5)
  queueID.insert(lastID)
  lastID = lastID + 1

  return lastID - 1
end
