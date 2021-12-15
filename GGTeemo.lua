if Player.CharName ~= "Teemo" then return end

local Teemo = {}
local Script = {
    Name = "GG" .. Player.CharName,
    Version = "1.0.0",
    LastUpdated = "15/12/2021",
    Changelog = {
        [1] = "[15/12/2021 - Version 1.0.0]: Initial release",
    }
}

module(Script.Name, package.seeall, log.setup)
clean.module(Script.Name, clean.seeall, log.setup)
CoreEx.AutoUpdate("https://robur.site/shulepin/robur/raw/branch/master/" .. Script.Name .. ".lua", Script.Version)
