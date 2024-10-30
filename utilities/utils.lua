function convertStringTo32Bits(string)
  print("TO IMPLEMENT")
  return 0
end

function hexcharToInt(c)
  if c == "0" then
    return 0
  end
  if c == "1" then
    return 1
  end
  if c == "2" then
    return 2
  end
  if c == "3" then
    return 3
  end
  if c == "4" then
    return 4
  end
  if c == "5" then
    return 5
  end
end

function convertHexStringToBytesArray(str)
  bts = {}
  for i = 1, #str do
    local c = str:sub(i,i)
    local idx = math.floor(i/2)
    if i%1 == 1 then
      bts[idx] = hexcharToInt(c)
    else
      bts[idx] = bts[idx] + hexcharToInt(c) * 16
    end
  end
  return {0}
end
