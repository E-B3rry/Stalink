local threads = {}
local starting = {}
local eventFilter = nil

rawset(os, "startThread", function(fn, blockTerminate)
    table.insert(starting, {
        cr = coroutine.create(fn),
        blockTerminate = blockTerminate or false,
        error = nil,
        dead = false,
        filter = nil
    })
end)

local function tick(t, evt, ...)
    if t.dead then return end
    if t.filter ~= nil and evt ~= t.filter then return end
    if evt == "terminate" and t.blockTerminate then return end

    coroutine.resume(t.cr, evt, ...)
    t.dead = (coroutine.status(t.cr) == "dead")
end

local function tickAll()
    if #starting > 0 then
        local clone = starting
        starting = {}
        for _,v in ipairs(clone) do
            tick(v)
            table.insert(threads, v)
        end
    end
    local e
    if eventFilter then
        e = {eventFilter(coroutine.yield())}
    else
        e = {coroutine.yield()}
    end
    local dead = nil
    for k,v in ipairs(threads) do
        tick(v, unpack(e))
        if v.dead then
            if dead == nil then dead = {} end
            table.insert(dead, k - #dead)
        end
    end
    if dead ~= nil then
        for _,v in ipairs(dead) do
            table.remove(threads, v)
        end
    end
end

rawset(os, "setGlobalEventFilter", function(fn)
    if eventFilter ~= nil then error("This can only be set once!") end
    eventFilter = fn
    rawset(os, "setGlobalEventFilter", nil)
end)

if type(threadMain) == "function" then
    os.startThread(threadMain)
else
    os.startThread(function() shell.run("shell") end)
end

while #threads > 0 or #starting > 0 do
    tickAll()
end

print("All threads terminated!")
print("Exiting thread manager")

shell.run("exit")
