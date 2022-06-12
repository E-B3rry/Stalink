--- WIP

--- RedCom-based communication system explained:
--- RedCom layer
-- Bytes array: (168 bits) {
--   checksum: CRC32 - 32 bits
--   src: 64 bits uid
--   dest: 64 bits uid
--   flags: 8 bits word
--     1st & 2nd bits: (udp, tcp, tunnel, redauth)
--     3rd & 4th bits: (raw, asymmetric encryption, symmetric encryption, both)
--     5th bit: (unsigned, signed)
--     6th-8th bits: (nil)
--   data: (undefined length)
-- }

--- TCP protocol
---   > The current implementation of the TCP protocol doesn't have a window size word in the header,
---   it also doesn't have a checksum as the redcom header already has a checksum.
---   > No TCP options are supported for now.
-- RedCom layer (168 bits) +
-- TCP bytes array (96 bits - 3 bytes): {
--   seq: 32 bits word
--   ack: 32 bits word
--   flags: 16 bits word (8 booleans, 4 empty bits and 4 bits data offset)
--     1st bit: FIN
--     2nd bit: SYN,
--     3rd bit: RST,
--     4th bit: PSH,
--     5th bit: ACK,
--     6th bit: URG,
--     7th bit: ECE,
--     8th bit: CWR,
--     9th to 12th bits: reserved,
--     13st to 16th bits: data offset (4 bits word, representing number of 32 bits words before the data),
--   urgent pointer: 16 bits word
--   options: nil (will be added later)
--   data: (undefined length)
-- }

--- UDP protocol
-- RedCom layer +
-- UDP bytes array: {
--   data: undefined length
-- }

--- Tunnel protocol (Not implemented yet)
-- RedCom layer +
-- Tunnel bytes array: {
--   Protocol not defined yet
-- }

--- RedAuth protocol
-- RedCom layer +
-- RedAuth bytes array: {
--   flags: 8 bits word (8 booleans)
--     1st bit: ASK,
--     2nd bit: KNOWN,
--     3rd bit: RENEW,
--     4th bit: CLAIM,
--     5th bit: FORGET_ME,
--     6th bit: ERROR,
--     7th bit: ACK,
--     8th bit: NONE
--   public_key: 168 bits

-- ! TODO: Rework the API loading system
--- (Un)load APIs and set constants --
os.unloadAPI("rednet")

local mainPath = fs.open("/mainPath.dat", "r")
local A = mainPath.readLine()
mainPath.close()

os.loadAPI(A .. "utilities/ecc.lua")

-- Define constants
local __USABLE_RANGE__ = {0, 65532}


-- Set local variables (Reworking)
local ids_table = {}
-- TODO: Create the configuration utility for RedCom
local settings = {
    ["tcp"] = {
        ["max_packet_size"] = 1024,
        ["tcp_keepalive_timeout"] = 60,  -- delay in seconds after which keepalive packets are sent
        ["ensure_opened_reply_channel"] = 1  -- 0: do nothing, 1: open the replyChannel, 2: throw an error
    },
    ["udp"] = {

    },
    ["other"] = {
        ["available_sides"] = {"left", "right", "top", "bottom", "front", "back"},  -- Order impacts priority
        -- TODO: Implement the max queue size and behavior
        ["awaiting_processing_queue_size"] = 128,
        ["incoming_packets_queue_size"] = 256,
        ["outgoing_packets_queue_size"] = 256,
        ["behavior_on_full_processing_queue"] = "wait",  -- Wait in the incoming queue until there is no more space
        ["behavior_on_full_incoming_queue"] = "drop",  -- Either drop the new packet or overwrite the oldest packet
        ["behavior_on_full_outgoing_queue"] = "error",  -- Either return an error or overwrite the oldest packet
        ["coroutine_yield_more"] = false,  -- If true redcom tries to yield more often, thus suspending itself ofter
        ["debug"] = true
    }
}

local meetingChannel = 0 -- Being replaced by a list of listened channels for tunneling
local meetingPrivateKey = nil

local packetsInQueue = {}
local msgWaitingQueue = {}
local packetsOutQueue = {}

local tunnels = {}
local isAcceptingTunneling = false
local lastTunnelID = 0;

local tcpConnections = {}
local lastTCPID = 0

local redComSides = {}
for i = 1, #settings["other"]["available_sides"] do
    redComSides[settings["other"]["available_sides"][i]] = {}
end


--- API's functions


-- 64 bits uid (60 bits being random, very likely unique)
-- TODO: Optimize and return a 64 bits blob, with another function that easily converts to viewable string
function generate_uid()
    local hex_chars = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'}
    local info_bit = 8

    if turtle then
        info_bit = info_bit + 1
    elseif pocket then
        info_bit = info_bit + 2
    elseif commands then
        info_bit = info_bit + 3
    end

    if term.isColor() then
        info_bit = info_bit + 4
    end

    local uid = hex_chars[info_bit + 1]

    for _ = 1, 15, 1 do
        uid = uid .. hex_chars[math.random(1, #hex_chars)]
    end

    return uid
end


-- Return the uid of this device in a readable format
function get_my_uid()
    return utils.convertBytesArrayToHexString(ids_table["self"])
end


-- Data loading and saving
function load_data()
    if fs.exists(A .. "redcom/IDs.dat") then
        local file = fs.open(A .. "redcom/IDs.dat", "r")
        ids_table = textutils.unserialize(file.readAll())
        file.close()
    else
        ids_table["self"] = utils.convertHexStringToBytesArray(generate_uid())
        ids_table["secure_provider"] = nil
        ids_table["uid_tables"] = {}
        save_data()
    end
end


-- Main run function
local isRunning = false
function run_parallel()
    if isRunning then return "Already running" end
    isRunning = true

    while isRunning do
        table.insert(packetsInQueue, async_fetch_modem_event())
        process_packets()
        --handle_tcp_connections()  -- Not ready yet
    end
end


function save_data()
    local file = fs.open(A .. "redcom/IDs.dat", "w")
    file.write(textutils.serialize(ids_table))
    file.close()
end


-- Process packet function
function process_packets(limit)
    if type(limit) ~= "number" then limit = 1 end  -- Ensure blocking parameter is a boolean

    for i = 1, limit do
        repeat  -- Workaround to have a continue statement for the for loop (using: `do break end`)
            if #packetsInQueue > 0 then
                local packet = table.remove(packetsInQueue, 1)

                if not packet then
                    do break end
                end

                local channel, replyChannel, data, distance = table.unpack(packet)

                -- CRC32 checksum
                if CRC32_checksum_validation(data) then
                    data = data:sub(5)
                else
                    if settings["other"]["debug"] then
                        print("[RedCom] Packet dropped: CRC32 checksum error")
                    end
                    do break end
                end

                local src_uid = data:sub(1, 8)
                local dest_uid = data:sub(9, 16)

                local redcom_flags = data:sub(17, 17):byte()
                local redcom_protocol = bit.band(redcom_flags, 0x03)
                local redcom_encryption = bit.band(bit.blshift(redcom_flags, 2), 0x0C)

                if dest_uid ~= ids_table["self"] then
                    if settings["other"]["debug"] then
                        print("[RedCom] Packet dropped: destination UID mismatch")
                    end
                    do break end
                end

                local redcom_data = data:sub(18)

                if redcom_protocol == 0 then
                    -- UDP protocol

                    table.insert(msgWaitingQueue,{
                        ["protocol"] = "udp",
                        ["src"] = src_uid,
                        ["is_src_approved"] = false, -- TODO: Implement
                        ["content"] = redcom_data,
                        ["distance"] = distance,
                        ["channel"] = channel,
                        ["reply_channel"] = replyChannel
                    })
                    do break end
                elseif redcom_protocol == 1 then
                    -- TCP protocol

                    -- TODO: Implement
                    do break end
                elseif redcom_protocol == 2 then
                    -- Tunnel protocol

                    -- TODO: Implement
                    do break end
                elseif redcom_protocol == 3 then
                    -- RedAuth protocol

                    -- TODO: Implement
                    do break end
                end
            else
                do break end
            end

            do break end
        until true
    end
end


-- Receive function
function receive(blocking)
    if isRunning then coroutine.yield() end

    if type(blocking) ~= "boolean" then blocking = true end  -- Ensure blocking parameter is a boolean

    if #msgWaitingQueue > 0 then
        local msg = table.remove(msgWaitingQueue, 1)
        return msg
    elseif blocking then
        while #msgWaitingQueue == 0 do
            if isRunning then coroutine.yield() end
        end

        local msg = table.remove(msgWaitingQueue, 1)
        return msg
    end
end


-- Work with parallel API
function async_fetch_modem_event()
    -- Pulling event from os queue and unpack all the arguments
    local evtType, s, channel, replyChannel, data, distance = os.pullEvent("modem_message")

    if evtType ~= "modem_message" then
        return nil
    end

    print("debug event:", evtType, s, channel, replyChannel, data, distance)

    -- If the receiving channel is not registered as opened on the receiving side then ignore
    if not isOpen(tonumber(channel), s) then
        if settings["other"]["debug"] then
            print("[RedCom] Packet dropped: channel " .. channel .. " not registered as opened in redcom on side " .. s)
        end
        return nil
    end

    if settings["other"]["debug"] then
        print("[RedCom] Received packet from " .. s .. " side on channel " .. channel .. ":")
        if type(data) == "string" then
            print(tostring(data))
        else
            print("Empty packet")
        end
    end

    return {channel, replyChannel, data, distance}
end


-- Function to fetch the modem_message event
function sync_fetch_modem_event()
    -- Pulling event from os queue (Using a specific way so that os.pullEvent doesn't block the program)
    local timer = os.startTimer(0.15)
    local eventTable = table.pack(os.pullEvent())

    -- Verify that the event is related to receive() function
    if eventTable[1] ~= "modem_message" and eventTable[2] ~= timer then
        -- Take actions to put back the wrong event back in queue
        os.cancelTimer(timer)
        os.queueEvent(table.unpack(eventTable))
        return nil
    end

    if eventTable[1] == "timer" and eventTable[2] == timer then
        -- If the timer event is triggered, return nil
        return nil
    end

    -- Unpack all the arguments
    local _, s, channel, replyChannel, data, distance = table.unpack(eventTable)

    if settings["other"]["debug"] then
        print("[RedCom] Received packet from " .. s .. " side on channel " .. channel .. ":")
        if type(data) == "string" then
            print(tostring(data))
        else
            print("Empty packet")
        end
    end

    -- If the receiving channel is not registered as opened on the receiving side then ignore
    if not isOpen(tonumber(channel), s) then
        print("Blobby must have fucked up there...\nThe channel " .. channel .. " is not registered as opened on " .. s .. " side, but it is receiving data from it.")
        return nil
    end

    return channel, replyChannel, data, distance
end


-- Handle all the ongoing TCP connections
function handle_tcp_connections()
    for key, _ in pairs(tcpConnections) do
        -- Send the first handshake packet
        if tcpConnections[key]["status"] == "syn" then
            -- Randomly set SEQ and ACK numbers
            tcpConnections[key]["seqOffest"] = math.random(0xFFFFFFFF)
            tcpConnections[key]["seq"] = tcpConnections[key]["seqOffest"]

            -- Generate the headers
            local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
            data = data .. generate_tcp_header(
                    false, true, false, false, false, false, false, false,
                    tcpConnections[key]["seq"], nil, nil)

            -- Send the packet
            send_raw(tcpConnections[key]["channel"], tcpConnections[key]["replyChannel"], CRC32(data), tcpConnections[key]["side"])

            tcpConnections[key]["status"] = "handshaking"
            tcpConnections[key]["seq"] = tcpConnections[key]["seqOffset"] + 1
        elseif tcpConnections[key]["status"] == "synack" then
            -- Randomly set SEQ number and increment the ACK number
            tcpConnections[key]["seqOffest"] = math.random(0xFFFFFFFF)
            tcpConnections[key]["seq"] = tcpConnections[key]["seqOffest"]
            tcpConnections[key]["ack"] = tcpConnections[key]["ack"] + 1

            -- Generate the headers
            local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
            data = data .. generate_tcp_header(
                    false, true, false, false, true, false, false, false,
                    tcpConnections[key]["seq"], tcpConnections[key]["ack"], nil)

            -- Send the packet
            send_raw(tcpConnections[key]["channel"], tcpConnections[key]["replyChannel"], CRC32(data), tcpConnections[key]["side"])

            tcpConnections[key]["status"] = "handshaking"
            tcpConnections[key]["seq"] = tcpConnections[key]["seqOffset"] + 1
        elseif tcpConnections[key]["status"] == "ack" then
            -- Increment ACK number
            tcpConnections[key]["ack"] = tcpConnections[key]["ack"] + 1

            -- Generate the headers
            local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
            data = data .. generate_tcp_header(
                    false, false, false, false, true, false, false, false,
                    nil, tcpConnections[key]["ack"], nil)

            -- Send the packet
            send_raw(tcpConnections[key]["channel"], tcpConnections[key]["replyChannel"], CRC32(data), tcpConnections[key]["side"])

            tcpConnections[key]["status"] = "waiting"
        elseif tcpConnections[key]["status"] == "waiting" then
        elseif tcpConnections[key]["status"] == "sending" then
        elseif tcpConnections[key]["status"] == "receiving" then
        elseif tcpConnections[key]["status"] == "terminating" then
        end
    end
end


-- Send messages to established connections
function send_tcp(channel, recipient, msg, blocking, side)
    -- Validate channel and replyChannel
    if channel == nil then
        error("Channel number isn't specified", 2)
    elseif channel < __USABLE_RANGE__[1] or channel > __USABLE_RANGE__[2] then
        error("Channel number must be between " .. tostring(__USABLE_RANGE__[1]) .. " and " .. tostring(__USABLE_RANGE__[2]), 2)
    end

    if replyChannel == nil then
        replyChannel = channel
    elseif replyChannel < __USABLE_RANGE__[1] or replyChannel > __USABLE_RANGE__[2] then
        error("Reply channel number must be between " .. tostring(__USABLE_RANGE__[1]) .. " and " .. tostring(__USABLE_RANGE__[2]) .. " or nil", 2)
    end

    if settings["tcp"]["ensure_opened_reply_channel"] == 2 then
        if not isOpen(replyChannel, side) then
            if side then
                error("Reply channel " .. tostring(replyChannel) .. " must be opened on specified side: " .. side, 2)
            else
                error("Reply channel " .. tostring(replyChannel) .. " must be opened", 2)
            end
        end
    elseif settings["tcp"]["ensure_opened_reply_channel"] == 1 then
        if not isOpen(replyChannel, side) then
            open(replyChannel, side)
        end
    end

    -- Validate recipient UID
    if recipient == nil then
        error("Recipient UID isn't specified", 2)
    elseif type(recipient) == "string" then
        if #recipient == 16 then
            recipient = utils.convertHexStringToBytesArray(recipient)
        elseif #recipient ~= 8 then
            error("Recipient UID must be a 8-bytes bin or 16 chars hex string", 2)
        end
    else
        error("Recipient UID must be a 8-bytes bin or 16 chars hex string", 2)
    end

    -- Create TCP connection
    local tcp_id = next_tcp_id()
    tcpConnections[tcp_id] = {
        ["channel"] = channel,
        ["replyChannel"] = replyChannel,
        ["side"] = side,
        ["recipient"] = recipient,
        ["data"] = msg,
        ["sender"] = true,
        ["status"] = "syn",
        ["ack"] = 0,
        ["seq"] = 0,
        ["seqOffset"] = 0,
        ["last_communication"] = -1
    }

    if blocking then
        -- TODO: Replace this with a function to fetch the status of a current or past TCP packet
        while tcpConnections[tcp_id]["status"] ~= "done" or tcpConnections[tcp_id]["status"] ~= "failed" or tcpConnections[tcp_id]["status"] ~= "timed_out" do
            coroutine.yield()
        end

        return tcpConnections[tcp_id]["status"]
    end

    return tcp_id
end


function send_udp(channel, recipient, msg, replyChannel, side)
    -- Validate channel and replyChannel
    if channel == nil then
        error("Channel number isn't specified", 2)
    elseif channel < __USABLE_RANGE__[1] or channel > __USABLE_RANGE__[2] then
        error("Channel number must be between " .. tostring(__USABLE_RANGE__[1]) .. " and " .. tostring(__USABLE_RANGE__[2]), 2)
    end

    if replyChannel == nil then
        replyChannel = channel
    elseif replyChannel < __USABLE_RANGE__[1] or replyChannel > __USABLE_RANGE__[2] then
        error("Reply channel number must be between " .. tostring(__USABLE_RANGE__[1]) .. " and " .. tostring(__USABLE_RANGE__[2]) .. " or nil", 2)
    end

    -- Validate recipient UID
    if recipient == nil then
        error("Recipient UID isn't specified", 2)
    elseif type(recipient) == "string" then
        if #recipient == 16 then
            recipient = utils.convertHexStringToBytesArray(recipient)
        elseif #recipient ~= 8 then
            error("Recipient UID must be a 8-bytes bin or 16 chars hex string", 2)
        end
    else
        error("Recipient UID must be a 8-bytes bin or 16 chars hex string", 2)
    end

    -- Create RedCom header & UDP packet
    local data = generate_redcom_header(recipient, 0, 0, 0) .. msg

    send_raw(channel, replyChannel, CRC32(data), side)
end


-- Ease the generation of RedCom header
function generate_redcom_header(recipient, protocol, encryption, signed)
    -- Validate parameters
    if protocol < 0 or protocol > 3 then
        protocol = 0
    end

    if encryption < 0 or encryption > 3 then
        encryption = 0
    end

    if signed < 0 or signed > 1 then
        signed = 0
    end

    local flags = protocol
    -- TODO: Support encryption and signature flags

    return ids_table["self"] .. recipient .. string.char(flags)
end


-- Ease the generation of TCP header
function generate_tcp_header(FIN, SYN, RST, PSH, ACK, URG, ECE, CWR, sequenceNumber, acknowledgmentNumber, urgentPointer)
    local flags = 0

    -- Add the flags
    if FIN then flags = flags + 1 end
    if SYN then flags = flags + 2 end
    if RST then flags = flags + 4 end
    if PSH then flags = flags + 8 end
    if ACK then flags = flags + 16 end
    if URG then flags = flags + 32 end
    if ECE then flags = flags + 64 end
    if CWR then flags = flags + 128 end

    -- Add the data offset
    local data_offset = 3  -- (32 bits words); Fixed for now, as we don't support options
    local offset = bit.blshift(data_offset, 4)

    -- Return the header
    return utils.convert32BitsToString(sequenceNumber) .. utils.convert32BitsToString(acknowledgmentNumber) .. string.char(offset) .. string.char(flags) .. utils.convert16BitsToString(urgentPointer)
end


-- Ease the decoding of TCP header
function decode_tcp_header(data)
    local header = {}

    -- Get the sequence number
    header["sequenceNumber"] = utils.convertStringTo32Bits(data:sub(1, 4))

    -- Get the acknowledgment number
    header["acknowledgmentNumber"] = utils.convertStringTo32Bits(data:sub(5, 8))

    -- Get the flags and separate it
    local flags = string.byte(data:sub(10, 10))
    header["FIN"] = bit.band(flags, 1) ~= 0
    header["SYN"] = bit.band(flags, 2) ~= 0
    header["RST"] = bit.band(flags, 4) ~= 0
    header["PSH"] = bit.band(flags, 8) ~= 0
    header["ACK"] = bit.band(flags, 16) ~= 0
    header["URG"] = bit.band(flags, 32) ~= 0
    header["ECE"] = bit.band(flags, 64) ~= 0
    header["CWR"] = bit.band(flags, 128) ~= 0

    -- Get the data offset
    local offset = string.byte(data:sub(9, 9))
    header["dataOffset"] = bit.brshift(offset, 4)

    -- Get the urgent pointer
    header["urgentPointer"] = utils.convertStringTo16Bits(data:sub(11, 12))

    return header
end


-- Get the next available channel for tunneling
function getNextFreeChannel()
    -- Temporary; need a real system
    return math.random(__USABLE_RANGE__[1], __USABLE_RANGE__[2])
end


-- Get connection ID
function retrieveConnection(channel)
    for k, connection in pairs(tunnels) do
        if connection["channel"] == channel then
            return connection, k
        end
    end
end


-- Send raw data
function send_raw(channel, replyChannel, data, side)
  if not side then
    side = getWorkingModemSide()

    if not side then
      return false
    end
  end

  peripheral.call(side, "transmit", channel, replyChannel, data)
  return true
end


function isOpen(channel, sides)
  if type(channel) ~= "number" then
    error("Channel argument must be a number.", 2)
  elseif channel < 0 or channel > 65535 then
    error("Channel out of range [0:65535], got " .. channel .. ".", 2)
  end

  if type(sides) == "string" then
    sides = {sides}
  elseif type(sides) ~= "table" then
    sides = settings["other"]["available_sides"]
  end

  for i = 0, #sides do
    if redComSides[sides[i]] then
      for _, openedChannel in pairs(redComSides[sides[i]]) do
        if channel == openedChannel then
          return sides[i]
        end
      end
    end
  end

  return false
end


function getWorkingModemSide()
    for side, channels in pairs(redComSides) do
        if peripheral.getType(side) == "modem" then
            if peripheral.call(side, "isWireless") then
                return side
            end
        end
    end

    return false
end


function getOpenableModemSide()
    for side, channels in pairs(redComSides) do
        if isSideOpenable(side) then
            return side
        end
    end

    return false
end


function isSideOpenable(side)
  if peripheral.getType(side) == "modem" then
    if #(redComSides[side]) < 128 then
      return true
    end
  end

  return false
end


function open(channels, side)
    local notSpecifiedSide = false

    -- TODO: Implement a protocol parameter for channel opening (tcp, udp or both)

    if side then
        local t = peripheral.getType(side)
        if t == nil then
          error("No peripheral detected on side " .. side .. ".", 2)
        elseif t ~= "modem" then
          error("The peripheral connected to side " .. side .. " is not a modem.", 2)
        end

        if #(redComSides[side]) > 127 then
          error("The " .. side .. " modem cannot open another channel (128 already in use).", 2)
        end
    else
        side = getOpenableModemSide()
        notSpecifiedSide = true

        if not side then
          error("There aren't any modem connected to the computer that can open channel.", 2)
        end
    end

    if type(channels) == "number" then
        peripheral.call(side, "open", channels)
        table.insert(redComSides[side], channels)
    elseif type(channels) == "table" then
        for channel in channels do
            if not isOpen(channel) then
                if #(redComSides[side]) > 127 then
                    if notSpecifiedSide then
                        side = getOpenableModemSide()

                        if not side then
                            error("Couldn't open all channels because there aren't any modems connected to the computer that can open channel anymore. (All the modems have 128 channels in use)", 3)
                        end
                    else
                        error("Couldn't open all channels because " .. side .. " modem cannot open another channel (128 already in use).", 3)
                    end
                end

                peripheral.call(side, "open", channel)
                redComSides[side].insert(channel)
            end
        end
    else
        error("Expected number or table of numbers for channels argument.", 2)
    end

    return true
end


function close(channels)
    -- TODO: Close any tunnels that are using the channels

    -- TODO: Implement a protocol parameter for channel closing (tcp, udp or both)

    if type(channels) == "number" then
        side = isOpen(channels)
        if side then
            peripheral.call(side, "close", channels)
            for i = 0, #(redComSides[side]) do
                if redComSides[side][i] == channels then
                    table.remove(redComSides[side], i)
                    break
                end
            end
        end
    elseif type(channels) == "table" then
        for channel in channels do
            side = isOpen(channel)
            if side then
                peripheral.call(side, "close", channel)
                for i = 0, #(redComSides[side]) do
                    if redComSides[side][i] == channel then
                        table.remove(redComSides[side], i)
                        break
                    end
                end
            end
        end
    else
        error("Expected number or table of numbers for channels argument.", 2)
    end

    return true
end


function next_tunnel_id()
    local last = lastTunnelID
    lastTunnelID = lastTunnelID + 1
    return last
end


function next_tcp_id()
    local last = lastTCPID
    lastTCPID = lastTCPID + 1
    return last
end

--- Reworking this, prone to disappear

function openMeetingChannel(channel, privateKey)
    if isOpen(meetingChannel) then
        close(meetingChannel)
    end

    if privateKey then
        meetingPrivateKey = tostring(privateKey)
    else
        meetingPrivateKey = nil
    end

    open(channel)
    meetingChannel = channel
    isAcceptingTunneling = true
end

function closeMeetingChannel()
    if isOpen(meetingChannel) then
        close(meetingChannel)
    end

    meetingPrivateKey = nil
    meetingChannel = nil
    isAcceptingTunneling = false
end


--- Checksum calculation and verification, ECC encryption and decryption and key encryption and decryption


--- CRC32
local __CRC32_DIVIDER__ = 0x04C11DB7
local crcTable = {}


function setupCRC32()
    for i = 1, 256, 1 do
        local crc = i - 1

        for _ = 1, 8, 1 do
            local mask = bit.band(-bit.band(crc, 1), __CRC32_DIVIDER__)
            crc = bit.bxor(bit.brshift(crc, 1), mask)
        end

        table.insert(crcTable, crc)
    end
end


function CRC32_checksum(data)
    if #(crcTable) == 0 then
        setupCRC32()
    end

    local crc = bit.bnot(0)

    for i = 1, #data, 1 do
        local byte = string.byte(data, i)

        crc = bit.bxor(bit.brshift(crc, 8), crcTable[bit.band(bit.bxor(crc, byte), 0xFF) + 1])
    end

    return bit.bnot(crc)
end


function CRC32(data)
    return utils.convert32BitsToString(CRC32_checksum(data)) .. data
end


function CRC32_checksum_validation(data)
    return string.sub(data, 1, 4) == utils.convert32BitsToString(CRC32_checksum(string.sub(data, 5)))
end


--- ECC


function ECC_generate_keypair()
    private_key, public_key = ecc.keypair()

    return private_key, public_key
end


function ECC_encrypt(data, public_key)
    return ecc.encrypt(data, public_key)
end


function ECC_decrypt(data, private_key)
    return ecc.decrypt(data, private_key)
end


function ECC_exchange(private_key, public_key)
    return ecc.exchange(private_key, public_key)
end


--- Run startup functions

setupCRC32() -- TODO: Optimize this, it's called at every launch and is ressource intensive, just save it in a file at first launch and load it on startup
load_data()

print("> RedCom API Loaded")
