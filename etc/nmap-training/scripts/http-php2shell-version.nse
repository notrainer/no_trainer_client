local http = require "http"
local shortport = require "shortport"
local stdnse = require "stdnse"

description = [[
Reads one HTTP endpoint's X-Powered-By header and compares an exact PHP release
with the PHP2Shell upstream fixes (CVE-2026-109618 and CVE-2026-109619).
This is version triage, not an exploit or proof of vulnerability. Headers can
be hidden or forged and distribution packages may contain backported fixes.
No error-triggering payloads, authentication, or redirects are used.
Reference: https://www.php.net/archive/2026.php#2026-10-21-5
]]
author = "Benjamin Akhras"
license = "GPLv2"
categories = { "discovery", "safe" }

-- @usage nmap -sT -p 80 --script ./scripts/http-php2shell-version.nse appliance
-- @args http-php2shell-version.path Local HTTP path (default: /php-version.php).
-- @output
-- | http-php2shell-version:
-- |   observed_version: 8.5.11
-- |   assessment: potentially_affected
-- |_  interpretation: Verify the running web runtime and vendor package/backports; no exploit was attempted.

portrule = shortport.http

action = function(host, port)
  local path = stdnse.get_script_args("http-php2shell-version.path") or "/php-version.php"
  if type(path) ~= "string" or not path:match("^/[^\r\n]*$") or path:match("^//") then
    return { error = "path must be a local absolute HTTP path without line breaks" }
  end
  local result = stdnse.output_table()
  result.path = path
  result.assessment = "unknown"
  result.interpretation = "Verify the running web runtime and vendor package/backports; no exploit was attempted."
  local response = http.get(host, port, path, {
    timeout = 5000, redirect_ok = false, no_cache = true,
    max_body_size = 1024, truncated_ok = true
  })
  if not response or not response.status then
    result.reason = "No HTTP response"
    return result
  end
  result.observed_status = response.status
  if response.status ~= 200 then
    result.reason = "Expected endpoint did not return HTTP 200"
    return result
  end
  local header = (response.header or {})["x-powered-by"] or ""
  local major, minor, patch = header:match("^PHP/(%d+)%.(%d+)%.(%d+)$")
  if not major then
    result.reason = "No unambiguous PHP release header; PHP absence is not established"
    return result
  end
  result.observed_version = major .. "." .. minor .. "." .. patch
  major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
  local fixes = { [2] = 35, [3] = 36, [4] = 27, [5] = 12 }
  if major == 8 and fixes[minor] then
    result.fixed_release = "8." .. minor .. "." .. fixes[minor]
    result.assessment = patch < fixes[minor] and "potentially_affected" or "fixed_upstream_version"
  elseif (major == 5 and minor >= 4 and minor <= 6)
      or (major == 7 and minor <= 4) or (major == 8 and minor <= 1) then
    result.assessment = "potentially_affected"
    result.reason = "Legacy upstream branch; check vendor backports or upgrade"
  else
    result.reason = "Release branch outside this check's advisory table"
  end
  return result
end
