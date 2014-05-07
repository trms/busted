package = "busted"
version = "2.0.0-0"
source = {
  url = "https://github.com/Olivine-Labs/busted/archive/v2.0.0.tar.gz",
  dir = "busted-2.0.0"
}
description = {
  summary = "Elegant Lua unit testing.",
  detailed = [[
    An elegant, extensible, testing framework.
    Ships with a large amount of useful asserts,
    plus the ability to write your own. Output
    in pretty or plain terminal format, JSON,
    or TAP for CI integration. Great for TDD
    and unit, integration, and functional tests.
  ]],
  homepage = "http://olivinelabs.com/busted/",
  license = "MIT <http://opensource.org/licenses/MIT>"
}
dependencies = {
  "lua >= 5.1",
  "lua_cliargs >= 2.0",
  "luafilesystem >= 1.5.0",
  "dkjson >= 2.1.0",
  "say >= 1.2-1",
  "luassert >= 1.7.0-0",
  "ansicolors >= 1.0-1",
  "penlight >= 1.0.0-1",
}
build = {
  type = "builtin",
  modules = {
  },
  install = {
    bin = {
      ["busted"] = "bin/busted.lua"
    }
  }
}
