-- D2.5: These are supplied values, not an HTTP request.
local observed = tonumber(arg[1])
local expected = tonumber(arg[2] or "401")

local function valid_status(status)
  return status ~= nil and status % 1 == 0 and status >= 100 and status <= 599
end

if not valid_status(observed) or not valid_status(expected) then
  io.stderr:write("Usage: lua status-check.lua <observed 100-599> [expected 100-599]\n")
  os.exit(1)
end

local function compare_status(actual, wanted)
  if actual == wanted then
    return "matches expectation"
  end
  return "review required"
end

print(compare_status(observed, expected))
