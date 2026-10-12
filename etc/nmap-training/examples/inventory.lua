-- D2.5: Fixed teaching data; this script performs no network requests.
local devices = {
  { name = "appliance", status = 200 },
  { name = "appliance-managed", status = 401 },
  { name = "missing-page", status = 404 }
}

local function needs_review(device)
  return device.status ~= 401
end

local reviews = 0
for index, device in ipairs(devices) do
  local verdict = "matches expectation"
  if needs_review(device) then
    verdict = "review required"
    reviews = reviews + 1
  end
  print(index .. ": " .. device.name .. " -> " .. verdict)
end
print("Reviews: " .. reviews .. "/" .. #devices)
