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
--     5th & 6th bits: (unsigned, signed)
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
--- Load APIs and set constants --
os.unloadAPI("rednet")

local mainPath = fs.open("/mainPath.dat", "r")
A = mainPath.readLine()
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
        ["tcp keepalive-timeout"] = 60, -- delay in seconds after which keepalive packets are sent
        ["ensure_opened_reply_channel"] = 1 -- 0: do nothing, 1: open the replyChannel, 2: throw an error
    },
    ["other"] = {
        ["available_sides"] = {"left", "right", "top", "bottom", "front", "back"}, -- Order impact priority
        ["coroutine_yield_more"] = false,
        ["debug"] = true
    }
}

local meetingChannel = 0 -- Being replaced by a list of listened channels for tunneling
local meetingPrivateKey = nil

local channelsListened = {}
--- Table for each listened channels ---
-- First param is the uuid of the other device
-- Second param is the channel
-- Third param is the shared key

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


-- 64 bits uid (60 bits being random, likely unique)
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
function run_as_coroutine()
    while true do
        -- Add the receiving mechanism here (and make sure to yield)
        handle_tcp_connections()
    end
end


function save_data()
    local file = fs.open(A .. "redcom/IDs.dat", "w")
    file.write(textutils.serialize(ids_table))
    file.close()
end


-- Receive function
function receive()
    local channel, replyChannel, data, distance = receiveRaw()

    if not data then
        return nil
    end

    -- CRC32 checksum
    if CRC32_checksum_validation(data) then
        data = data:sub(5)
    else
        print("Info: CRC32 checksum error")
        return nil
    end

    local src_uid = data:sub(1, 8)
    local dest_uid = data:sub(9, 16)

    local redcom_flags = data:sub(17, 17):byte()
    local redcom_protocol = bit.band(redcom_flags, 0x03)
    local redcom_encryption = bit.band(bit.blshift(redcom_flags, 2), 0x0C)

    if dest_uid ~= ids_table["self"] then
        print("Info: Not the targeted recipient")
        return nil
    end

    local redcom_data = data:sub(18)

    if redcom_protocol == 0 then
        -- UDP protocol

        return {
            ["protocol"] = "udp",
            ["src"] = src_uid,
            ["is_src_approved"] = false, -- TODO: Implement
            ["content"] = redcom_data,
            ["distance"] = distance,
            ["channel"] = channel,
            ["reply_channel"] = replyChannel
        }
    elseif redcom_protocol == 1 then
        -- TCP protocol

        -- TODO: Implement
    elseif redcom_protocol == 2 then
        -- Tunnel protocol

        -- TODO: Implement
    elseif redcom_protocol == 3 then
        -- RedAuth protocol

        -- TODO: Implement
    end
end


-- Raw receive function
function receiveRaw()
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

    -- Unpack all the arguments and work with them
    local e, s, channel, replyChannel, data, distance = table.unpack(eventTable)

    if data then
        if type(data) == "string" then
            --print("Message : " .. tostring(msg))
        else
            for key, item in pairs(data) do
                print(tostring(key) .. " - " .. tostring(item))
            end
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
        if tcpConnections[key]["status"] == 0 then
            -- Set SEQ number
            tcpConnections[key]["seqNumber"] = math.random(0xFFFFFFFF)
            tcpConnections[key]["initSeqNumber"] = tcpConnections[key]["seqNumber"]

            -- Generate the headers
            local data = generate_redcom_header(recipient, 1, 0, 0)
            data = data .. generate_tcp_header(
                    false, true, false, false, false, false, false, false,
                    tcpConnections[key]["seqNumber"], nil, nil)

            -- Send the packet
            send_raw(tcpConnections[key]["channel"], tcpConnections[key]["replyChannel"], data, tcpConnections[key]["side"])
        end
    end
end


-- Send messages to established connections
function send_tcp(channel, recipient, msg, replyChannel, side)
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
    tcpConnections[next_tcp_id()] = {
        ["channel"] = channel,
        ["replyChannel"] = replyChannel,
        ["side"] = side,
        ["recipient"] = recipient,
        ["data"] = msg,
        ["sender"] = true,
        ["status"] = 0,
        ["last_communication"] = os.clock()
    }

    handle_tcp_connections()
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
    flags = flags + bit.blshift(data_offset, 12)

    -- Return the header
    return utils.convert32BitsToString(sequenceNumber) .. utils.convert32BitsToString(acknowledgmentNumber) .. string.char(flags) .. utils.convert16BitsToString(urgentPointer)
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
