--- Emulator startup file (Automatically updated via artifact at every emulator start)
-- Only triggers if the instance is run in the standalone emulator.
if ccemux then
    local sides = {"left", "right", "front", "back", "top", "bottom"}
    local id = 0

    if type(os.getComputerID()) == "number" then
        id = os.getComputerID()
    else
        id = math.random(1, 4)
    end

    -- Attach a fake modem to a random side
    ccemux.attach(sides[math.random(1, #sides)], "wireless_modem", {
        range = 64,
        interdimensional = false,
        world = "main",
        posX = math.floor(id * math.random(4, 6)),
        posY = math.floor(id * math.random(4, 6)),
        posZ = 110,
    })

    print("[CCEMUX] Attached a fake modem to a random side")
end
