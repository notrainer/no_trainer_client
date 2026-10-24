local http = require "http"
local shortport = require "shortport"
local stdnse = require "stdnse"

description = [[
Checks the HTTP status of one known maintenance endpoint against a site's
documented access policy. Reports observations for review, not vulnerabilities.
Does not authenticate, follow redirects, or change configuration.
]]

author = "Benjamin Akhras"
license = "GPLv2"
categories = { "discovery", "safe" }

-- @usage nmap -sV -p 80 --script ./scripts/http-shop-policy.nse appliance
-- @args http-shop-policy.path Endpoint to inspect (default: /maintenance/).
-- @args http-shop-policy.expected-status Expected HTTP status (default: 401).
-- @output
-- | http-shop-policy:
-- |   path: /maintenance/
-- |   observed_status: 200
-- |   expected_status: 401
-- |   review_required: yes
-- |_  interpretation: Response differs from the documented policy; verify access and device ownership.

portrule = shortport.http

action = function(host, port)
  local path = stdnse.get_script_args("http-shop-policy.path") or "/maintenance/"
  local expected = tonumber(stdnse.get_script_args("http-shop-policy.expected-status") or "401")

  if type(path) ~= "string" or not path:match("^/[^\r\n]*$") or path:match("^//") then
    return { error = "path must be a local absolute HTTP path without line breaks" }
  end
  if not expected or expected % 1 ~= 0 or expected < 100 or expected > 599 then
    return { error = "expected-status must be an integer from 100 to 599" }
  end

  local response = http.get(host, port, path, {
    timeout = 5000,
    redirect_ok = false,
    no_cache = true,
    max_body_size = 4096,
    truncated_ok = true
  })
  if not response or not response.status then
    return { error = "No HTTP status received; the access policy could not be assessed" }
  end

  local result = stdnse.output_table()
  result.path = path
  result.observed_status = response.status
  result.expected_status = expected
  result.review_required = response.status == expected and "no" or "yes"
  result.interpretation = response.status == expected
    and "Response matches this check; other endpoints and authentication still need separate assessment."
    or "Response differs from the documented policy; verify access and device ownership."
  return result
end
