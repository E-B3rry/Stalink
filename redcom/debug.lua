-- Load APIs and set constants --
local mainPath = fs.open("/mainPath.dat", "r")
A = mainPath.readLine()
mainPath.close()

os.loadAPI(A .. "redcom/redcom.lua")
os.loadAPI(A .. "utilities/utils.lua")


-- Screen cleared and disclaimer --
term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.red)
print("DISCLAIMER : This is a debug tool, it is not of any use in production.\
Furthermore, it only allows you to use or test basic functionalities of the redcom API, at least for now.\n")
term.setTextColor(colors.white)

-- Open redcom channel --
redcom.open(135)

-- Wait for acknowledgement --
print("\n\nWaiting for keypress...")
os.pullEvent("key")

-- Help and init message --
local function print_msg()
    term.setTextColor(colors.pink)
    print("List of commands :")
    term.setTextColor(colors.blue)
    print("- help : displays this message\
- open/close <port> : opens/closes a redcom channel\
- listen : listen for any incoming traffic on opened channels\
- udp_send : send udp packets on one or more channel\
- tcp_send : send tcp packets on one or more channel\
- tunnel : create a secure tunnel to another machine\
- crc : test CRC\
- ecc : test ECC encryption/decryption\
- uid : generate an unique id\
- exit : exit the program")
end

term.clear()
term.setCursorPos(1,1)

print_msg()

-- Main loop --
function main()
    while true do
        -- Ask for user input --
        term.setTextColor(colors.white)
        print("\nEnter command : ")
        local choice = read()
        print("\n")

        if choice == "listen" then
            print("Your own UID: " .. redcom.get_my_uid())

            -- Receive data --

            while true do
                local data = redcom.receive()

                if data then
                    print("\nReceived " .. data["protocol"] .. " packet from " .. utils.convertBytesArrayToHexString(data["src"]) .. ":")
                    print("- Channel used: " .. data["channel"] .. "\n- Msg received: " .. data["content"] .. "\n- Replying channel: " .. data["reply_channel"] .. "\n- With a distance of: " .. data["distance"] .. "\n")
                end
            end
        elseif choice == "udp_send" then
            term.clear()
            term.setCursorPos(1,1)

            print("Your own UID: " .. redcom.get_my_uid())

            while true do
                -- Send data --
                print("\n\nEnter the data to be sent: ")
                local data = read()

                print("\nEnter the recipient UID: ")
                local recipient = read()

                redcom.send_udp(135, recipient, data, nil, nil)

                print("Data sent me boi!\n")
            end
        elseif choice == "tcp_send" then
            term.clear()
            term.setCursorPos(1,1)

            print("Your own UID: " .. redcom.get_my_uid())

            while true do
                -- Send data --
                print("\n\nEnter the data to be sent: ")
                local data = read()

                print("\nEnter the recipient UID: ")
                local recipient = read()

                redcom.send_tcp(135, recipient, data, nil, nil)

                print("Data sent me boi!\n")
            end
        elseif choice == "crc" then
            math.randomseed(os.time())

            term.clear()
            term.setCursorPos(1,1)

            print("Enter the error strength [0-255]: ")
            local error_strength = tonumber(read())
            print("\nSet max string length [0-BeforeMemoryOutage]: ")
            local string_length = tonumber(read())
            print("\nSet iterations count [0-PleaseBeReasonable]:")
            local iterations = tonumber(read())
            print("\n")

            local messages_corrupted = 0
            local success = 0
            local false_negative = 0
            local false_positive = 0

            local data = ""
            local data_corrupted = ""

            for i = 1, iterations, 1 do
                -- Generate random data, (probably) corrupt it and check CRC --
                data = ""

                -- Generate random data with specified length
                for _ = 1, math.random(1, string_length) do
                    data = data .. string.char(math.random(32, 126))
                end

                data = redcom.CRC32(data)
                data_corrupted = data

                -- Corrupt data based on error strength
                for j = 1, #data_corrupted, 1 do
                    if math.random(0, 255) < error_strength then
                        data_corrupted = string.sub(data_corrupted, 1, j - 1) .. string.char(math.random(32, 126)) .. string.sub(data_corrupted, j + 1)
                    end
                end

                -- Check CRC
                if data ~= data_corrupted then
                    messages_corrupted = messages_corrupted + 1

                    if redcom.CRC32_checksum_validation(data_corrupted) then
                        false_positive = false_positive + 1
                    else
                        success = success + 1
                    end
                else
                    if redcom.CRC32_checksum_validation(data_corrupted) then
                        success = success + 1
                    else
                        false_negative = false_negative + 1
                    end
                end

                -- Display progress
                if i % 500 == 0 then
                    term.clear()
                    term.setCursorPos(1,1)
                    term.setTextColor(colors.fromRGB(math.floor(255 - i / iterations * 255), math.floor(i / iterations * 255), math.floor(i / iterations * 155)))
                    print(i .. "/" .. iterations .. " iterations done.")
                end

                -- Yield to avoid crashing if the operations are taking too long
                os.queueEvent("yield");
                os.pullEvent();
            end

            -- Display results
            term.clear()
            term.setCursorPos(1,1)
            term.setTextColor(colors.white)

            print("CRC-32 test results:\n* Total messages: " .. iterations .. " (corrupted: " .. messages_corrupted .. ")\n- Success: " .. success .. "\n- False positive: " .. false_positive .. "\n- False negative: " .. false_negative)
        elseif choice == "ecc.lua" then
            -- Generate two ECC keypair --
            term.clear()
            term.setCursorPos(1,1)

            term.setTextColor(colors.blue)
            print("== Generating two ECC keypair ==")
            term.setTextColor(colors.orange)
            local bob_private_key, bob_public_key = redcom.ECC_generate_keypair()
            local alice_private_key, alice_public_key = redcom.ECC_generate_keypair()

            print("\nGenerated new keypair for Bob :",
                    "\n- private key: " .. tostring(bob_private_key),
                    "\n- public key: " .. tostring(bob_public_key))

            term.setTextColor(colors.purple)
            print("\nGenerated new keypair for Alice :",
                    "\n- private key: " .. tostring(alice_private_key),
                    "\n- public key: " .. tostring(alice_public_key))

            term.setTextColor(colors.white)
            print("\n\nWaiting for keypress...")
            os.pullEvent("key")

            -- Generate shared secret --
            term.clear()
            term.setCursorPos(1,1)
            term.setTextColor(colors.blue)
            print("== Comparing shared secret ==")

            term.setTextColor(colors.orange)
            bob_shared_key = redcom.ECC_exchange(bob_private_key, alice_public_key)
            print("\nShared secret from Bob:", tostring(bob_shared_key))

            term.setTextColor(colors.purple)
            alice_shared_key = redcom.ECC_exchange(alice_private_key, bob_public_key)
            print("\nShared secret from Alice:", tostring(alice_shared_key))

            if tostring(bob_shared_key) == tostring(alice_shared_key) then
                term.setTextColor(colors.green)
                print("\n> Shared secret is the same between Bob and Alice.")
                term.setTextColor(colors.white)
                print("\n\nWaiting for keypress...")
                os.pullEvent("key")

                -- Ask for a message to encrypt
                term.clear()
                term.setCursorPos(1,1)
                term.setTextColor(colors.blue)
                print("== Testing encryption and decryption ==")
                term.setTextColor(colors.white)
                print("\nEnter the message to encrypt: ")
                local message = read()

                if message ~= "" then
                    term.setTextColor(colors.yellow)
                    -- Encrypt the message --
                    encrypted_msg = redcom.ECC_encrypt(message, bob_shared_key)
                    print("\nEncrypted message: " .. tostring(encrypted_msg))

                    -- Decrypt the message --
                    decrypted_msg = redcom.ECC_decrypt(encrypted_msg, alice_shared_key)
                    print("Decrypted message: " .. tostring(decrypted_msg))

                    -- Compare the decrypted message with the original one --
                    if tostring(decrypted_msg) == tostring(message) then
                        term.setTextColor(colors.green)
                        print("\n> Message is the same after decryption.")
                        term.setTextColor(colors.white)
                    else
                        term.setTextColor(colors.red)
                        print("\n> ERROR: Message is different after decryption.")
                        term.setTextColor(colors.white)
                    end
                else
                    print("\nNo message entered...")
                end
            else
                term.setTextColor(colors.red)
                print("\n> ERROR: Shared secret is different between Bob and Alice.")
                term.setTextColor(colors.white)
            end
        elseif choice == "uid" then
            term.clear()
            term.setCursorPos(1,1)

            local orig_uid = redcom.generate_uid()
            local base4_uid = utils.convertHexStringToBytesArray(orig_uid)
            local base8_uid = utils.convertBytesArrayToHexString(base4_uid)

            print("base8 hex string generated uid:" .. orig_uid)
            print("base4 string converted uid:" .. base4_uid)
            print("base8 converted back uid:" .. base8_uid)

            if orig_uid == nil or base4_uid == nil or base8_uid == nil then
                term.setTextColor(colors.red)
                print("\n> ERROR: Something went wrong while generating or converting UID, got nil.")
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.green)
                print("\n> UID generated and converted without any errors.")
                term.setTextColor(colors.white)
            end

            if #orig_uid == 16 then
                term.setTextColor(colors.green)
                print("\n> Generated 16 hex chars UID has valid length.")
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.red)
                print("\n> ERROR: Generated hex chars UID isn't 16 chars long, but " .. #orig_uid .. ".")
                term.setTextColor(colors.white)
            end

            if #base4_uid == 8 then
                term.setTextColor(colors.green)
                print("> Converted 8 chars UID has valid length.")
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.red)
                print("> ERROR: Converted base-4 UID isn't 8 chars long, but " .. #base4_uid .. ".")
                term.setTextColor(colors.white)
            end

            if base8_uid == orig_uid then
                term.setTextColor(colors.green)
                print("> UID is the same after two-ways conversion.")
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.red)
                print("> ERROR: UID is different after two-ways conversion.")
                term.setTextColor(colors.white)
            end

            print("\n\nWaiting for keypress...")
            os.pullEvent("key")

            term.clear()
            term.setCursorPos(1,1)
        elseif choice == "help" then
            -- Display help --
            term.clear()
            term.setCursorPos(1,1)

            print_msg()
        elseif choice == "exit" then
            -- Exit --
            redcom.close(135)

            term.clear()
            local w = term.getSize()
            term.setCursorPos(math.floor(w / 2) - 5,3)
            term.setTextColor(colors.green)

            print("Goodbye! :)\n")

            os.sleep(1.47)
            term.clear()
            term.setCursorPos(1,1)

            break
        else
            -- Invalid choice --
            term.clear()
            term.setCursorPos(1,1)
            term.setTextColor(colors.red)

            print("Invalid choice, try again.")
        end
    end
end

-- Start the program --
parallel.waitForAny(main, redcom.run_parallel)
