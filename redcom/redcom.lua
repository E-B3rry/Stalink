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

--- RedCom UDP protocol (=0)
-- RedCom layer +
-- UDP bytes array: {
--   data: undefined length
-- }

--- RedCom TCP protocol (=1)
---   > The current implementation of the TCP protocol doesn't have a window size word in the header,
---   it also doesn't have a checksum as the redcom header already has a checksum.
---   > No TCP options are supported for now. Also it has a 4 bytes word for a remote connection uid
---   that allows the remote host to identify which connection is which. It had to be added because of the
---   RedCom implementation of networking
-- RedCom layer (168 bits) +
-- TCP bytes array (128 bits - 16 bytes): {
--   connection_id: 32 bits word
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

--- RedCom Tunnel protocol (=Routing protocol for faraway transmission, not implemented yet)
-- RedCom layer +
-- Tunnel bytes array: {
--   Protocol not defined yet
-- }

--- RedAuth protocol (Not implemented yet, but will work in symbiosis with Tunnel protocol)
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


--- (Un)load APIs and set constants --
os.unloadAPI("rednet")

-- Load stalink installation path
--if not StalinkInstallationPath then
--    local StalinkInstallationPathFile = fs.open("/stalink-path", "r")
--    StalinkInstallationPath = StalinkInstallationPathFile.readLine()
--    StalinkInstallationPathFile.close()
--end
StalinkInstallationPath = "Stalink/"

os.loadAPI(StalinkInstallationPath .. "utilities/ecc.lua")
os.loadAPI(StalinkInstallationPath .. "utilities/utils.lua")

-- Define constants
local __USABLE_RANGE__ = {0, 65532}

-- Set local variables (Reworking)
local ids_table = {}
-- TODO: Create the configuration utility for RedCom
local settings = {
    ["tcp"] = {
        ["max_packet_size"] = 2048,  -- Size in bytes (default: 2048)
        ["max_connections"] = 30,  -- maximum number of simultaneous TCP connections
        ["max_connections_per_uid"] = 3,  -- maximum number of simultaneous connections per UID

        ["keepalive_interval"] = 60,  -- delay in seconds after which keepalive packets are sent (default: 60s)
        ["keepalive_retransmission_timeout"] = 6,  -- delay in seconds after which another keepalive is sent
        ["timeout"] = 72,  -- delay in seconds after which a connection is considered dead (default: 12s later)
        ["ensure_opened_reply_channel"] = 1,  -- 0: do nothing, 1: open the replyChannel, 2: throw an error
        ["retransmission_timeout"] = 5,  -- delay in seconds before a packet is considered lost and sent again
        ["retransmission_attempts"] = 3,  -- number of attempts to send a packet before giving up
        ["debug"] = false  -- Print debug data specific to TCP protocol on console
    },
    ["udp"] = {

    },
    ["other"] = {
        ["available_sides"] = {"left", "right", "top", "bottom", "front", "back"},  -- Order impacts priority
        -- TODO: Implement the max queue size and behavior
        ["incoming_packets_queue_size"] = 256,
        ["outgoing_packets_queue_size"] = 256,
        ["behavior_on_full_incoming_queue"] = "drop",  -- Either drop the new packet or overwrite the oldest packet
        ["behavior_on_full_outgoing_queue"] = "error",  -- Either return an error or overwrite the oldest packet
        ["enable_timer_event_interval"] = true,  -- Enable timer events to make sure the coroutine runs enough
        ["timer_event_interval"] = 0.1,  -- Delay in seconds between timer events
        ["coroutine_yield_more"] = false,  -- If true redcom tries to yield more often, thus suspending itself ofter
        ["debug"] = false,  -- Print debug data on console
        ["dump_packet"] = false  -- Dump packets on console and other advanced information (flood notice)
    }
}

local packetsInQueue = {}
local msgWaitingQueue = {}
local packetsOutQueue = {}

local tunnels = {}
local isAcceptingTunneling = false
local lastTunnelID = 0

local tcpConnections = {}

local redComSides = {}
local lastTimer
local timestampTimer = 0

for i = 1, #settings["other"]["available_sides"] do
    redComSides[settings["other"]["available_sides"][i]] = {}
end


--- API's functions


-- 64 bits uid (60 bits being random, very likely unique)
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
    return requestUtils.convertBytesArrayToHexString(ids_table["self"])
end

-- Data loading and saving
function load_data()
    if fs.exists(StalinkInstallationPath .. "redcom/IDs.dat") then
        local file = fs.open(StalinkInstallationPath .. "redcom/IDs.dat", "r")
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
        handle_tcp_connections()

        -- Timer event system to make sure the coroutine runs enough
        if settings["other"]["enable_timer_event_interval"] then
            if timestampTimer < os.clock() + settings["other"]["timer_event_interval"] then
                if lastTimer then
                    os.cancelTimer(lastTimer)
                end

                lastTimer = os.startTimer(settings["other"]["timer_event_interval"])
            end
        end
    end
end


function save_data()
    local file = fs.open("Stalink/redcom/IDs.dat", "w")
    file.write(textutils.serialize(ids_table))
    file.close()
end


-- Process packet function
function process_packets(limit)
    if type(limit) ~= "number" then limit = 1 end  -- Ensure blocking parameter is a boolean

    for _ = 1, limit do
        repeat  -- Workaround to have a continue statement for the for loop (using: `do break end`)
            if #packetsInQueue > 0 then
                local packet = table.remove(packetsInQueue, 1)

                if not packet then
                    do break end
                end

                local channel, replyChannel, data, distance, timestamp = table.unpack(packet)

                -- CRC32 checksum
                if CRC32_checksum_validation(data) then
                    data = data:sub(5)
                else
                    if settings["other"]["debug"] then
                        print("[RedCom] CRC32 error packet on channel " .. channel .. ", dropped it.")
                    end
                    do break end
                end

                local src_uid = data:sub(1, 8)
                local dest_uid = data:sub(9, 16)

                local redcom_flags = data:sub(17, 17):byte()
                local redcom_protocol = bit.band(redcom_flags, 0x03)
                local redcom_encryption = bit.band(bit.blshift(redcom_flags, 2), 0x0C)

                if dest_uid ~= ids_table["self"] then
                    if settings["other"]["dump_packet"] then
                        print("[RedCom] Packet dropped: destination UID mismatch")
                    end
                    do break end
                end

                local redcom_data = data:sub(18)

                if redcom_protocol == 0 then
                    -- UDP protocol
                    if settings["other"]["dump_packet"] then
                        print("[RedCom] UDP packet received")
                    end

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
                    if settings["other"]["dump_packet"] then
                        print("[RedCom] TCP packet received")
                    end

                    local tcp_headers = decode_tcp_header(redcom_data:sub(1, 16))
                    local tcp_data = redcom_data:sub(17)

                    -- TODO: Rework connection identifying mechanism and ensure address and channel

                    if tcpConnections[tcp_headers["connectionUID"]] ~= nil then
                        local key = tcp_headers["connectionUID"]

                        -- Connection is already closed, lost or was reset
                        if tcpConnections[key]["status"] == "terminated" and tcpConnections[key]["status"] == "lost" and tcpConnections[key]["status"] == "reset" then
                            do break end
                        end

                        -- Connection already exists and is alive, process it
                        tcpConnections[key]["last_received"] = timestamp
                        tcpConnections[key]["packets_received"] = tcpConnections[key]["packets_received"] + 1
                        if settings["tcp"]["debug"] then
                            print("[RedCom-TCP] Connection " .. key .. " received packet #" .. tcpConnections[key]["packets_received"])
                        end

                        -- Gracefully close connection if FIN flag is set
                        if verify_tcp_header(tcp_headers, true) then
                            tcpConnections[key]["status"] = "terminating_ack"
                            do break end
                        end

                        if tcpConnections[key]["status"] == "handshaking" then
                            if verify_tcp_header(tcp_headers, false, true, false, nil, true) then
                                if tcpConnections[key]["seq"] ~= tcp_headers["ack"] then
                                    print("oh shit, we got a problem huston", tcpConnections[key]["seq"], tcp_headers["ack"])
                                    -- TODO: Handle the ack bs here
                                end

                                tcpConnections[key]["recipient_connection_uid"] = utils.convertStringTo32Bits(tcp_data:sub(1, 4))
                                tcpConnections[key]["ack"] = tcp_headers["seq"]
                                tcpConnections[key]["ack_offset"] = tcp_headers["seq"] - 1
                                tcpConnections[key]["status"] = "ack"
                            elseif verify_tcp_header(tcp_headers, false, false, false, nil, true) then
                                if tcpConnections[key]["seq"] ~= tcp_headers["ack"] then
                                    print("oh shit, we got another problem huston", tcpConnections[key]["seq"], tcp_headers["ack"])
                                    -- TODO: Handle the ack bs here
                                end

                                if tcpConnections[key]["has_data_to_send"] == true then
                                    tcpConnections[key]["status"] = "sending"
                                else
                                    tcpConnections[key]["status"] = "established"
                                end
                            end
                        elseif tcpConnections[key]["status"] == "established" then
                            if verify_tcp_header(tcp_headers, false, false, false, nil, false) then
                                if tcpConnections[key]["accept_data_in"] == true then
                                    -- TODO: Receive the data

                                    if #tcp_data > 0 then
                                        local relativeAck = tcp_headers["seq"] - tcpConnections[key]["ack_offset"] - 1

                                        local inBefore = tcpConnections[key]["in"]:sub(1, relativeAck - 1)
                                        local inAfter = tcpConnections[key]["in"]:sub(relativeAck + #tcp_data)
                                        tcpConnections[key]["in"] = inBefore .. tcp_data .. inAfter

                                        tcpConnections[key]["ack"] = math.min(tcpConnections[key]["ack"] + #tcp_data, tcp_headers["seq"] + #tcp_data)
                                    else
                                        if settings["tcp"]["debug"] then
                                            print("[RedCom-TCP] Connection " .. key .. " received keepalive")
                                        end
                                    end

                                    tcpConnections[key]["status"] = "receiving_ack"
                                else
                                    -- TODO: Properly deny the connection (Myb through a reset)
                                end
                            elseif verify_tcp_header(tcp_headers, false, false, false, nil, true) then
                                if tcpConnections[key]["seq"] ~= tcp_headers["ack"] then
                                    print("damn, keepalive failed", tcpConnections[key]["seq"], tcp_headers["ack"])
                                    -- TODO: Handle the ack bs here
                                end
                            end
                        -- Whenever it's waiting for an ack, except for terminating connection or sending keepalive
                        elseif tcpConnections[key]["status"] == "waiting_for_ack" then
                            -- Ensure it's an ack being received
                            if verify_tcp_header(tcp_headers, false, false, false, nil, true) then
                                if tcpConnections[key]["seq"] ~= tcp_headers["ack"] then
                                    print("oh shit, we still got a problem huston")
                                    -- TODO: Handle the ack desync here
                                else
                                    if settings["other"]["debug"] then
                                        print("[RedCom-TCP] Connection " .. key .. " sending progress is " .. ((tcpConnections[key]["seq"] - tcpConnections[key]["seq_offset"] - 1) / #tcpConnections[key]["out"] * 100) .. "%")
                                    end
                                    tcpConnections[key]["status"] = "sending"
                                end
                            end
                        elseif tcpConnections[key]["status"] == "terminating" then
                            if verify_tcp_header(tcp_headers, false, false, false, false, true) then
                                if tcpConnections[key]["seq"] + 1 ~= tcp_headers["ack"] then
                                    print("oh shit, we still got a problem huston")
                                end

                                if tcpConnections[key]["fin_received"] and tcpConnections[key]["fin_sent"] then
                                    tcpConnections[key]["status"] = "terminated"
                                else
                                    tcpConnections[key]["status"] = "terminating"
                                end
                                do break end
                            end
                        end
                    else
                        -- New or unknown connection incoming
                        if settings["tcp"]["debug"] then
                            print("[RedCom-TCP] New connection incoming")
                        end

                        if verify_tcp_header(tcp_headers, false, true, false, false, false) then
                            -- TODO: Add advanced connection acceptance behavior (size of queue, congestion detected)

                            local tcp_uid = new_tcp_uid()
                            local recipient_connection_uid = utils.convertStringTo32Bits(tcp_data:sub(1, 4))

                            if count_alive_tcp_connections() >= settings["tcp"]["max_connections"] or count_active_tcp_connections_per_recipient(src_uid) >= settings["tcp"]["max_connections_per_uid"] or not tcp_uid then
                                -- Create RST packet and add it to the outgoing queue
                                local rst_packet = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                                rst_packet = rst_packet .. generate_tcp_header(
                                        false, false, true, false, false, false,
                                        false, false, recipient_connection_uid
                                )
                                add_raw_packet(replyChannel, channel, rst_packet)
                                do break end
                            end

                            tcpConnections[tcp_uid] = {
                                ["recipient_connection_uid"] = recipient_connection_uid,
                                ["channel"] = replyChannel,
                                ["reply_channel"] = channel,
                                ["side"] = nil,
                                ["recipient"] = src_uid,
                                ["in"] = "",
                                ["out"] = "",
                                ["has_data_to_send"] = false,
                                ["accept_data_in"] = true,
                                ["terminate_after_sending"] = false,
                                ["status"] = "syn_ack",
                                ["ack"] = tcp_headers["seq"],
                                ["ack_offset"] = tcp_headers["seq"] - 1,
                                ["seq"] = 0,
                                ["seq_offset"] = 0,
                                ["last_received"] = timestamp,
                                ["last_sent"] = -1,
                                ["packets_received"] = 0,
                                ["before_seq"] = 0,
                                ["error"] = 0,
                                ["fin_sent"] = false,
                                ["fin_received"] = false,
                                -- Determines if the connection should be added to signals queue or not
                                ["should_queue_event"] = true,
                                ["was_event_queued"] = false
                            }

                            if settings["tcp"]["debug"] then
                                print("[RedCom-TCP] New connection " .. tcp_uid .. " established")
                            end
                        end
                    end

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
function reveiveRaw()
  
  return 0, 0, 0, 0
end


function receive(blocking)
    -- TODO: Clean TCP connections when their finished signal is fetch from the queue

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
    local now = os.clock()

    if evtType ~= "modem_message" then
        return nil
    end

    -- Dump packet to console if set to do so
    if settings["other"]["dump_packet"] then
        print("Packet dump:", evtType, s, channel, replyChannel, data, distance)
        if type(data) ~= "string" then
            print("Empty packet")
        end
    end

    -- If the receiving channel is not registered as opened on the receiving side then ignore
    if not isOpen(tonumber(channel), s) then
        if settings["other"]["debug"] then
            print("[RedCom] Packet dropped: channel " .. channel .. " not registered as opened in redcom on side " .. s)
        end
        return nil
    end

    return {channel, replyChannel, data, distance, now}
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

    -- Dump packet to console if set to do so
    if settings["other"]["dump_packet"] then
        print("Packet dump:", evtType, s, channel, replyChannel, data, distance)
        if type(data) ~= "string" then
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
        while true do
            -- Do not process tcpConnections if terminated
            if tcpConnections[key]["status"] == "terminated" or tcpConnections[key]["status"] == "lost" or tcpConnections[key]["status"] == "done" then
                -- But queue the connection for processing if set to do so and hasn't yet
                if tcpConnections[key]["should_queue_event"] and not tcpConnections[key]["was_event_queued"] then
                    table.insert(msgWaitingQueue,{
                        ["protocol"] = "tcp",
                        ["uid"] = key,
                        ["src"] = tcpConnections[key]["recipient"],
                        ["is_src_approved"] = false,  -- TODO: Implement
                        ["content"] = tcpConnections[key]["in"],
                        ["closed_timestamp"] = tcpConnections[key]["last_sent"],
                        ["channel"] = tcpConnections[key]["channel"],
                        ["reply_channel"] = tcpConnections[key]["reply_channel"]
                    })
                    tcpConnections[key]["was_event_queued"] = true
                end
                do break end
            end

            -- Debug print
            if settings["tcp"]["debug"] then
                print("[RedCom-TCP] Handling TCP connection " .. key .. ":")
                print("> State now:", tcpConnections[key]["status"])
            end

            -- Make sure the connection is not lost
            if tcpConnections[key]["last_received"] + settings["tcp"]["timeout"] < os.clock() and tcpConnections[key]["last_received"] > 0 then
                if settings["tcp"]["debug"] then
                    print("[RedCom-TCP] Connection " .. key .. " lost")
                end
                tcpConnections[key]["status"] = "lost"
            end

            -- Set connection as terminated when gracefully closed
            if tcpConnections[key]["fin_received"] and tcpConnections[key]["fin_sent"] then
                tcpConnections[key]["status"] = "terminated"
            end


            -- Send the first handshake packet
            if tcpConnections[key]["status"] == "syn" then
                -- Randomly set SEQ and ACK numbers
                tcpConnections[key]["seq_offset"] = utils.large_random_int(32)
                tcpConnections[key]["seq"] = tcpConnections[key]["seq_offset"]

                -- Generate the headers
                local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                data = data .. generate_tcp_header(
                        false, true, false, false, false, false, false, false,
                        0, tcpConnections[key]["seq_offset"], nil, nil)
                data = data .. utils.convert32BitsToString(key)

                -- Send the packet
                send_raw(tcpConnections[key]["channel"], tcpConnections[key]["reply_channel"], CRC32(data), tcpConnections[key]["side"])

                tcpConnections[key]["last_sent"] = os.clock()
                tcpConnections[key]["seq"] = tcpConnections[key]["seq_offset"] + 1
                tcpConnections[key]["before_seq"] = tcpConnections[key]["seq"]
                tcpConnections[key]["status"] = "handshaking"
            elseif tcpConnections[key]["status"] == "syn_ack" then
                -- Randomly set SEQ number and increment the ACK number
                tcpConnections[key]["seq_offset"] = utils.large_random_int(32)
                tcpConnections[key]["seq"] = tcpConnections[key]["seq_offset"]
                tcpConnections[key]["ack"] = tcpConnections[key]["ack"] + 1

                -- Generate the headers
                local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                data = data .. generate_tcp_header(
                        false, true, false, false, true, false, false, false,
                        tcpConnections[key]["recipient_connection_uid"], tcpConnections[key]["seq_offset"], tcpConnections[key]["ack"], nil)
                data = data .. utils.convert32BitsToString(key)

                -- Send the packet
                send_raw(tcpConnections[key]["channel"], tcpConnections[key]["reply_channel"], CRC32(data), tcpConnections[key]["side"])

                tcpConnections[key]["last_sent"] = os.clock()
                tcpConnections[key]["seq"] = tcpConnections[key]["seq_offset"] + 1
                tcpConnections[key]["before_seq"] = tcpConnections[key]["seq"]
                tcpConnections[key]["status"] = "handshaking"
            elseif tcpConnections[key]["status"] == "ack" then
                -- Increment ACK number
                tcpConnections[key]["ack"] = tcpConnections[key]["ack"] + 1

                -- Generate the headers
                local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                data = data .. generate_tcp_header(
                        false, false, false, false, true, false, false, false,
                        tcpConnections[key]["recipient_connection_uid"], nil, tcpConnections[key]["ack"], nil)

                -- Send the packet
                send_raw(tcpConnections[key]["channel"], tcpConnections[key]["reply_channel"], CRC32(data), tcpConnections[key]["side"])

                tcpConnections[key]["last_sent"] = os.clock()
                tcpConnections[key]["status"] = "established"
            elseif tcpConnections[key]["status"] == "established" then
                -- Terminate the connection if set to do so
                if not tcpConnections[key]["has_data_to_send"] and tcpConnections[key]["terminate_after_sending"] then
                    tcpConnections[key]["status"] = "terminating"
                end

                if tcpConnections[key]["has_data_to_send"] == true then
                    tcpConnections[key]["status"] = "sending"
                end

                if math.min(tcpConnections[key]["last_sent"], tcpConnections[key]["last_received"]) + settings["tcp"]["keepalive_interval"] < os.clock() then
                    if os.clock() + settings["tcp"]["keepalive_retransmission_timeout"] < tcpConnections[key]["last_sent"] then
                        -- Generate the headers
                        local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                        data = data .. generate_tcp_header(
                                false, false, false, false, false, false, false, false,
                                tcpConnections[key]["recipient_connection_uid"], tcpConnections[key]["seq"] - 1, nil, nil)

                        -- Send the packet
                        send_raw(tcpConnections[key]["channel"], tcpConnections[key]["reply_channel"], CRC32(data), tcpConnections[key]["side"])
                        tcpConnections[key]["last_sent"] = os.clock()
                    end
                end

                --local _in = CRC32(tcpConnections[key]["in"])
                --local _out = CRC32(tcpConnections[key]["out"])
                --print("In (" .. #_in .. "): " .. _in:sub(1, 4))
                --print("Out (" .. #_out .. "): " .. _out:sub(1, 4))
            elseif tcpConnections[key]["status"] == "sending" then
                local relativeSeq = tcpConnections[key]["seq"] - tcpConnections[key]["seq_offset"] - 1
                local payloadLen = math.min(#tcpConnections[key]["out"] - relativeSeq, settings["tcp"]["max_packet_size"])

                if payloadLen > 0 then
                    local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                    data = data .. generate_tcp_header(
                            false, false, false, false, false, false, false, false,
                            tcpConnections[key]["recipient_connection_uid"],
                            tcpConnections[key]["seq"],
                            nil, nil)
                    data = data .. string.sub(tcpConnections[key]["out"], relativeSeq + 1, relativeSeq + payloadLen)

                    -- Send the packet
                    send_raw(tcpConnections[key]["channel"], tcpConnections[key]["reply_channel"], CRC32(data), tcpConnections[key]["side"])

                    tcpConnections[key]["last_sent"] = os.clock()
                    tcpConnections[key]["before_seq"] = tcpConnections[key]["seq"]
                    tcpConnections[key]["seq"] = tcpConnections[key]["seq"] + payloadLen
                    tcpConnections[key]["status"] = "waiting_for_ack"
                else
                    tcpConnections[key]["has_data_to_send"] = false

                    if tcpConnections[key]["terminate_after_sending"] then
                        tcpConnections[key]["status"] = "terminating"
                    else
                        tcpConnections[key]["status"] = "established"
                    end
                end
            elseif tcpConnections[key]["status"] == "waiting_for_ack" then
                -- Handle potential packet loss and retransmission up to 3 times
                if tcpConnections[key]["last_sent"] + settings["tcp"]["retransmission_timeout"] < os.clock() then
                    if tcpConnections[key]["error"] < settings["tcp"]["retransmission_attempts"] then
                        tcpConnections[key]["error"] = tcpConnections[key]["error"] + 1
                        tcpConnections[key]["seq"] = tcpConnections[key]["before_seq"]
                        tcpConnections[key]["status"] = "sending"

                        if settings["tcp"]["debug"] then
                            print("[RedCom-TCP] Timeout " .. tcpConnections[key]["error"] .. "/" .. settings["tcp"]["retransmission_attempts"] .. " when awaiting ack for " .. key)
                        end
                    else
                        tcpConnections[key]["status"] = "lost"

                        if settings["tcp"]["debug"] then
                            print("[RedCom-TCP] Lost connection " .. key)
                        end
                    end
                end
            elseif tcpConnections[key]["status"] == "receiving_ack" then
                local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                data = data .. generate_tcp_header(
                        false, false, false, false, true, false, false, false,
                        tcpConnections[key]["recipient_connection_uid"], nil, tcpConnections[key]["ack"], nil
                )

                -- Send the packet
                send_raw(tcpConnections[key]["channel"], tcpConnections[key]["reply_channel"], CRC32(data), tcpConnections[key]["side"])
                tcpConnections[key]["last_sent"] = os.clock()
                tcpConnections[key]["status"] = "established"
            elseif tcpConnections[key]["status"] == "terminating" then
                if tcpConnections[key]["fin_sent"] == false then
                    -- Generate the headers
                    local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                    data = data .. generate_tcp_header(
                            true, false, false, false, false, false, false, false,
                            tcpConnections[key]["recipient_connection_uid"], tcpConnections[key]["seq"], nil, nil)
                    data = data .. utils.convert32BitsToString(key)

                    -- Send the packet
                    send_raw(tcpConnections[key]["channel"], tcpConnections[key]["reply_channel"], CRC32(data), tcpConnections[key]["side"])
                    tcpConnections[key]["last_sent"] = os.clock()
                    tcpConnections[key]["fin_sent"] = true
                end
            elseif tcpConnections[key]["status"] == "terminating_ack" then
                if tcpConnections[key]["fin_received"] == false then
                    -- Generate the headers
                    local data = generate_redcom_header(tcpConnections[key]["recipient"], 1, 0, 0)
                    data = data .. generate_tcp_header(
                            false, false, false, false, true, false, false, false,
                            tcpConnections[key]["recipient_connection_uid"], nil, tcpConnections[key]["ack"] + 1, nil)
                    data = data .. utils.convert32BitsToString(key)

                    -- Send the packet
                    send_raw(tcpConnections[key]["channel"], tcpConnections[key]["reply_channel"], CRC32(data), tcpConnections[key]["side"])
                    tcpConnections[key]["last_sent"] = os.clock()
                    tcpConnections[key]["fin_received"] = true
                end
                tcpConnections[key]["status"] = "terminating"
            end
            do break end
        end
    end
end


-- Send messages to established connections
function send_tcp(channel, recipient, msg, blocking, accept_data_in, terminate_after_sending, replyChannel, side)
    -- Validate channel and replyChannel, among terminate_after_sending parameter
    if channel == nil then
        error("Channel number isn't specified", 2)
    elseif channel < __USABLE_RANGE__[1] or channel > __USABLE_RANGE__[2] then
        error("Channel number must be between " .. tostring(__USABLE_RANGE__[1]) .. " and " .. tostring(__USABLE_RANGE__[2]), 2)
    end

    if terminate_after_sending == nil then
        terminate_after_sending = true
    else
        terminate_after_sending = terminate_after_sending
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
    local tcp_uid = new_tcp_uid()
    if not tcp_uid then
        error("Couldn't create a new TCP connection (can't generate uid)", 2)
    end
    tcpConnections[tcp_uid] = {
        ["recipient_connection_uid"] = 0,
        ["channel"] = channel,
        ["reply_channel"] = replyChannel,
        ["side"] = side,
        ["recipient"] = recipient,
        ["in"] = "",
        ["out"] = msg,
        ["has_data_to_send"] = #msg > 0,
        ["accept_data_in"] = accept_data_in,
        ["terminate_after_sending"] = terminate_after_sending,
        ["status"] = "syn",
        ["ack"] = 0,
        ["ack_offset"] = 0,
        ["seq"] = 0,
        ["seq_offset"] = 0,
        ["last_received"] = -1,
        ["last_sent"] = -1,
        ["packets_received"] = 0,
        ["before_seq"] = 0,
        ["error"] = 0,
        ["fin_sent"] = false,
        ["fin_received"] = false,
        -- Determines if the connection should be added to signals queue or not
        ["should_queue_event"] = not blocking,
        ["was_event_queued"] = false
    }

    if blocking then
        while is_tcp_connection_alive(tcp_uid) do
            coroutine.yield()
        end
        return tcpConnections[tcp_uid]["status"]
    end

    return tcp_uid
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


-- Add raw packet to the outgoing queue
function add_raw_packet(channel, replyChannel, data, side)
    if not side then
        side = getWorkingModemSide()

        if not side then
            return false
        end
    end

    table.insert(packetsOutQueue, {side, channel, replyChannel, data})
    return true
end


--- Modem side functions
-- Ensure one channel is opened on at least one ore more given side
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


-- Return a working wireless modem side for sending
function getWorkingModemSide()
    for side, _ in pairs(redComSides) do
        if peripheral.getType(side) == "modem" then
            if peripheral.call(side, "isWireless") then
                return side
            end
        end
    end

    return false
end


-- Get an openable channel on the given side
function getOpenableModemSide()
    for side, _ in pairs(redComSides) do
        if isSideOpenable(side) then
            return side
        end
    end

    return false
end


-- Make sure a side is openable by checking the channels opened restrictions
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


--- Future tunnelling protocol (not implemented yet and functions will change) ---
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


function next_tunnel_id()
    -- Unsafe, will be updated when the protocol will be implemented
    local last = lastTunnelID
    lastTunnelID = lastTunnelID + 1
    return last
end


--- TCP utilities ---
-- Ease the generation of TCP header
function generate_tcp_header(FIN, SYN, RST, PSH, ACK, URG, ECE, CWR, connectionUID, seq, ack, urgentPointer)
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
    local data_offset = 4  -- (32 bits words); Fixed for now, as we don't support options
    local offset = bit.blshift(data_offset, 4)

    -- Return the header
    return utils.convert32BitsToString(connectionUID) .. utils.convert32BitsToString(seq) .. utils.convert32BitsToString(ack) .. string.char(offset) .. string.char(flags) .. utils.convert16BitsToString(urgentPointer)
end


-- Ease the decoding of TCP header
function decode_tcp_header(data)
    local header = {}

    -- Get the connection uid
    header["connectionUID"] = utils.convertStringTo32Bits(data:sub(1, 4))

    -- Get the sequence number
    header["seq"] = utils.convertStringTo32Bits(data:sub(5, 8))

    -- Get the acknowledgment number
    header["ack"] = utils.convertStringTo32Bits(data:sub(9, 12))

    -- Get the data offset
    local offset = string.byte(data:sub(13, 13))
    header["dataOffset"] = bit.brshift(offset, 4)

    -- Get the flags and separate it
    local flags = string.byte(data:sub(14, 14))
    header["FIN"] = bit.band(flags, 1) ~= 0
    header["SYN"] = bit.band(flags, 2) ~= 0
    header["RST"] = bit.band(flags, 4) ~= 0
    header["PSH"] = bit.band(flags, 8) ~= 0
    header["ACK"] = bit.band(flags, 16) ~= 0
    header["URG"] = bit.band(flags, 32) ~= 0
    header["ECE"] = bit.band(flags, 64) ~= 0
    header["CWR"] = bit.band(flags, 128) ~= 0

    -- Get the urgent pointer
    header["urgentPointer"] = utils.convertStringTo16Bits(data:sub(15, 16))

    return header
end


-- Ease the verification of TCP header
function verify_tcp_header(header, FIN, SYN, RST, PSH, ACK, URG, ECE, CWR)
    if not header then
        return false
    end

    -- Check the flags
    if FIN ~= nil then
        if header["FIN"] ~= FIN then
            return false
        end
    end

    if SYN ~= nil then
        if header["SYN"] ~= SYN then
            return false
        end
    end

    if RST ~= nil then
        if header["RST"] ~= RST then
            return false
        end
    end

    if PSH ~= nil then
        if header["PSH"] ~= PSH then
            return false
        end
    end

    if ACK ~= nil then
        if header["ACK"] ~= ACK then
            return false
        end
    end

    if URG ~= nil then
        if header["URG"] ~= URG then
            return false
        end
    end

    if ECE ~= nil then
        if header["ECE"] ~= ECE then
            return false
        end
    end

    if CWR ~= nil then
        if header["CWR"] ~= CWR then
            return false
        end
    end

    return true
end


-- Return true if the connection is alive, false otherwise
function is_tcp_connection_alive(uid)
    if tcpConnections[uid] then
        if tcpConnections[uid]["status"] ~= "terminated" and tcpConnections[uid]["status"] ~= "lost" then
            return true
        end
    end

    return false
end


-- Count active tcp connections
function count_alive_tcp_connections()
    local count = 0
    for uid, _ in pairs(tcpConnections) do
        count = is_tcp_connection_alive(uid) and (count + 1) or count
    end
    return count
end


-- Count active tcp connections per recipient
function count_active_tcp_connections_per_recipient(recipient_uid)
    if not recipient_uid then
        return count_alive_tcp_connections()
    end

    local count = 0
    for uid, conn in pairs(tcpConnections) do
        count = (is_tcp_connection_alive(uid) and conn["recipient"] == recipient_uid) and (count + 1) or count
    end
    return count
end


-- Generate a new unique ID for a tcp connection
function new_tcp_uid()
    local id = 0
    for _ = 1, 300, 1 do
        id = utils.large_random_int(32)
        if not tcpConnections[id] then
            return id
        end
    end

    return nil
end


--- Checksum calculation and verification, ECC encryption and decryption and key encryption and decryption


--- CRC32
local __CRC32_DIVIDER__ = 0x04C11DB7
local crcTable = {}


function setupCRC32()
    -- Load cache file from redcom installation path
    local cache_path = StalinkInstallationPath .. "redcom/crc32-cache-table.dat"
    if not fs.exists(cache_path) then
        for i = 1, 256, 1 do
            local crc = i - 1

            for _ = 1, 8, 1 do
                local mask = bit.band(-bit.band(crc, 1), __CRC32_DIVIDER__)
                crc = bit.bxor(bit.brshift(crc, 1), mask)
            end

            table.insert(crcTable, crc)
        end

        local crc_file_handle = fs.open(cache_path, "w")
        crc_file_handle.write(textutils.serialize(crcTable))
        crc_file_handle.close()
    else
        local crc_file_handle = fs.open(cache_path, "r")
        crcTable = textutils.unserialize(crc_file_handle.readAll())
        crc_file_handle.close()
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


function only_CRC32(data)
    return utils.convert32BitsToString(CRC32_checksum(data))
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

setupCRC32() -- TODO: Optimize this, it's called at every launch and is resource intensive, just save it in a file at first launch and load it on startup
load_data()

print("> RedCom API Loaded")
