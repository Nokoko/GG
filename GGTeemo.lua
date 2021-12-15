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
CoreEx.AutoUpdate("https://github.com/Nokoko/GG/blob/main/" .. Script.Name .. ".lua", Script.Version)

local SDK = _G.CoreEx
local Player = _G.Player
local DreamEvade = _G.DreamEvade

local DamageLib, CollisionLib, DashLib, HealthPred, ImmobileLib, Menu, Orbwalker, Prediction, Profiler, Spell, TargetSelector =
_G.Libs.DamageLib, _G.Libs.CollisionLib, _G.Libs.DashLib, _G.Libs.HealthPred, _G.Libs.ImmobileLib, _G.Libs.NewMenu,
_G.Libs.Orbwalker, _G.Libs.Prediction, _G.Libs.Profiler, _G.Libs.Spell, _G.Libs.TargetSelector()

local AutoUpdate, Enums, EvadeAPI, EventManager, Game, Geometry, Input, Nav, ObjectManager, Renderer =
SDK.AutoUpdate, SDK.Enums, SDK.EvadeAPI, SDK.EventManager, SDK.Game, SDK.Geometry, SDK.Input, SDK.Nav, SDK.ObjectManager, SDK.Renderer

local AbilityResourceTypes, BuffTypes, DamageTypes, Events, GameMaps, GameObjectOrders, HitChance, ItemSlots, 
ObjectTypeFlags, PerkIDs, QueueTypes, SpellSlots, SpellStates, Teams = 
Enums.AbilityResourceTypes, Enums.BuffTypes, Enums.DamageTypes, Enums.Events, Enums.GameMaps, Enums.GameObjectOrders,
Enums.HitChance, Enums.ItemSlots, Enums.ObjectTypeFlags, Enums.PerkIDs, Enums.QueueTypes, Enums.SpellSlots, Enums.SpellStates,
Enums.Teams

local Vector, BestCoveringCircle, BestCoveringCone, BestCoveringRectangle, Circle, CircleCircleIntersection,
Cone, LineCircleIntersection, Path, Polygon, Rectangle, Ring =
Geometry.Vector, Geometry.BestCoveringCircle, Geometry.BestCoveringCone, Geometry.BestCoveringRectangle, Geometry.Circle,
Geometry.CircleCircleIntersection, Geometry.Cone, Geometry.LineCircleIntersection, Geometry.Path, Geometry.Polygon,
Geometry.Rectangle, Geometry.Ring

local abs, acos, asin, atan, ceil, cos, deg, exp, floor, fmod, huge, log, max, min, modf, pi, rad, random, randomseed, sin,
sqrt, tan, type, ult = 
_G.math.abs, _G.math.acos, _G.math.asin, _G.math.atan, _G.math.ceil, _G.math.cos, _G.math.deg, _G.math.exp,
_G.math.floor, _G.math.fmod, _G.math.huge, _G.math.log, _G.math.max, _G.math.min, _G.math.modf, _G.math.pi, _G.math.rad,
_G.math.random, _G.math.randomseed, _G.math.sin, _G.math.sqrt, _G.math.tan, _G.math.type, _G.math.ult

local byte, char, dump, ends_with, find, format, gmatch, gsub, len, lower, match, pack, packsize, rep, reverse,
starts_with, sub, unpack, upper = 
_G.string.byte, _G.string.char, _G.string.dump, _G.string.ends_with, _G.string.find, _G.string.format,
_G.string.gmatch, _G.string.gsub, _G.string.len, _G.string.lower, _G.string.match, _G.string.pack, _G.string.packsize,
_G.string.rep, _G.string.reverse, _G.string.starts_with, _G.string.sub, _G.string.unpack, _G.string.upper

local clock, date, difftime, execute, exit, getenv, remove, rename, setlocale, time, tmpname = 
_G.os.clock, _G.os.date, _G.os.difftime, _G.os.execute, _G.os.exit, _G.os.getenv, _G.os.remove, _G.os.rename, _G.os.setlocale,
_G.os.time, _G.os.tmpname

local Resolution = Renderer.GetResolution()

local LMBPressed = false
local HitChanceList = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" }

local AddWhiteListMenu = function(id, name)
    local name = name or "White List"
    Menu.NewTree(id, name, function()
        for k, hero in pairs(ObjectManager.Get("enemy", "heroes")) do
            local heroAI = hero.AsAI
            Menu.Checkbox(id .. heroAI.CharName, heroAI.CharName, true)
        end
    end)
end

local CursorIsUnder = function(x, y, sizeX, sizeY)
    local mousePos = Renderer.GetCursorPos()
    if not mousePos then
        return false
    end
    local posX, posY = mousePos.x, mousePos.y
    if sizeY == nil then
        sizeY = sizeX
    end
    if sizeX < 0 then
        x = x + sizeX
        sizeX = -sizeX
    end
    if sizeY < 0 then
        y = y + sizeY
        sizeY = -sizeY
    end
    return posX >= x and posX <= x + sizeX and posY >= y and posY <= y + sizeY
end

local InfoPanel = {
    X = 100,
    Y = 100,
    Size = Vector(200, 22),
    Color = 0x000000AA,
    Font = Renderer.CreateFont("Bahnschrift.ttf", 20),
    Options = {
        [1] = {
            Text = "Spell Farm",
            Type = 0,
        }
    },
    SpellFarmStatus = Menu.Get("GGScript.InfoPanel.SpellFarmStatus", true),
    SpellFarmStatusT = 0,
    MoveOffset = {},
    MenuCreated = false,
	
	}

function InfoPanel.CreateMenu()
    Menu.NewTree("GGScript.InfoPanel", "Information Panel", function()
        Menu.Checkbox("GGScript.InfoPanel.SpellFarmStatus", "Spell Farm Status", true)
        Menu.Text("X - "); Menu.SameLine(); Menu.Slider("GGScript.InfoPanel.X", "", 100, 0, Resolution.x, 1)
        Menu.Text("Y - "); Menu.SameLine(); Menu.Slider("GGScript.InfoPanel.Y", "", 100, 0, Resolution.y, 1)
    end)
    InfoPanel.MenuCreated = true
end

function InfoPanel.AddOption(option)
    InfoPanel.Options[#InfoPanel.Options + 1] = option
end

EventManager.RegisterCallback(Events.OnDraw, function()
    if not InfoPanel.MenuCreated then return end

    InfoPanel.X = Menu.Get("GGScript.InfoPanel.X")
    InfoPanel.Y = Menu.Get("GGScript.InfoPanel.Y")
    local font = InfoPanel.Font

    InfoPanel.Size.y = 22 + (#InfoPanel.Options * 20)

    Renderer.DrawFilledRect(Vector(InfoPanel.X, InfoPanel.Y), InfoPanel.Size, 0, InfoPanel.Color)

    local text = "GGTeemo"
    local textExtent = font:CalcTextSize(tostring(text))
    local textPosition = Vector(InfoPanel.X + ((InfoPanel.Size.x / 2) - (textExtent.x / 2)), InfoPanel.Y)
    font:DrawText(textPosition, text, 0xFFFFFFFF)

    for k, v in ipairs(InfoPanel.Options) do
        local text = v.Text
        local textPosition = Vector(InfoPanel.X + 5, InfoPanel.Y + (k * 20))
        
        if v.Type == 0 then
            local menuValue = Menu.Get("GGScript.InfoPanel.SpellFarmStatus", true)
            local status = menuValue and "Enabled" or "Disabled"
            local color = menuValue and 0x28cf4cFF or 0xdf2626FF
            local textExtent = font:CalcTextSize(tostring(text))
            font:DrawText(textPosition, text, color)
            font:DrawText(Vector(textPosition.x + textExtent.x , textPosition.y), " [Scroll Down]", 0xa9a7a7FF  )
        elseif v.Type == 1 then
            font:DrawText(textPosition, text, 0xFFFFFFFF)
        end
    end

    do
        local cursorPos = Renderer.GetCursorPos()
        local rect = {x = InfoPanel.X - 5, y = InfoPanel.Y - 5, z = InfoPanel.Size.x, w = InfoPanel.Size.y}
        if not InfoPanel.MoveOffset and rect and CursorIsUnder(rect.x, rect.y, rect.z, rect.w) and LMBPressed then
            InfoPanel.MoveOffset = {
                x = rect.x - cursorPos.x + 5,
                y = rect.y - cursorPos.y + 5
            }
        elseif InfoPanel.MoveOffset and not LMBPressed then
            InfoPanel.MoveOffset = nil
        end

        if InfoPanel.MoveOffset and rect and rect.x and rect.y then
            rect.x = InfoPanel.MoveOffset.x + cursorPos.x
            rect.x = rect.x > 0 and rect.x or 0
            rect.x = rect.x < Resolution.x - rect.z and rect.x or Resolution.x - rect.z
    
            rect.y = InfoPanel.MoveOffset.y + cursorPos.y
            rect.y = rect.y > 0 and rect.y or 0
            rect.y = rect.y < (Resolution.y - rect.w + 6) and rect.y or (Resolution.y - rect.w + 6)
    
            if LMBPressed then
                InfoPanel.X = rect.x
                InfoPanel.Y = rect.y
                Menu.Set("GGScript.InfoPanel.X", rect.x)
                Menu.Set("GGScript.InfoPanel.Y", rect.y)
            end
        end
    end
end)

EventManager.RegisterCallback(Events.OnMouseEvent, function(e, message, wparam, lparam)
    LMBPressed = e == 513
    if e == 522 and InfoPanel.SpellFarmStatusT + 0.25 < Game.GetTime() then
        InfoPanel.SpellFarmStatus = not InfoPanel.SpellFarmStatus
        Menu.Set("GGScript.InfoPanel.SpellFarmStatus", InfoPanel.SpellFarmStatus)
        InfoPanel.SpellFarmStatusT = Game.GetTime()
    end
end)*

function Teemo.Initialize()
    Teemo.CreateMenu()
    Teemo.CreateSpells()
    Teemo.CreateEvents()
end

local Menu = _G.Libs.NewMenu

function GGTeemoMenu()
	Menu.NewTree("GGTeemoCombo", "Combo", function ()
		Menu.Checkbox("Combo.CastQ","Cast Q",true)
		Menu.Checkbox("Combo.CastAAQ","Cast Q After AA",true)
		Menu.Checkbox("Combo.CastW","Cast W",true)
		Menu.Checkbox("Combo.CastR","Cast R",true)
		Menu.Slider("Combo.CastRHC", "R Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Combo.CastRHR", "R Hit Range", 400, 400, 900, 10)
		Menu.Slider("Combo.CastRMinMana", "R % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("GGTeemoHarass", "Harass", function ()
		Menu.Checkbox("Harass.CastQ","Cast Q",true)
		Menu.Checkbox("Harass.CastAAQ","Cast Q After AA",true)
		Menu.Checkbox("Harass.CastR","Cast R",true)
		Menu.Slider("Harass.CastRHC", "R Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Harass.CastRHR", "R Hit Range", 400, 400, 900, 10)
		Menu.Slider("Harass.CastRMinMana", "R % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("GGTeemoWave", "Waveclear", function ()
		Menu.ColoredText("Wave", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastQ","Cast Q",true)
		Menu.Checkbox("Waveclear.CastR","Cast R",true)
		Menu.Slider("Waveclear.CastRHC", "R Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastRMinMana", "R % Min. Mana", 0, 1, 100, 1)
		Menu.Separator()
		Menu.ColoredText("Jungle", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastQJg","Cast Q",true)
		Menu.Checkbox("Waveclear.CastRJg","Cast R",true)
		Menu.Slider("Waveclear.CastRHCJg", "R Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastRMinManaJg", "R % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("GGTeemoLasthit", "Lasthit", function ()
		Menu.Checkbox("Lasthit.CastQ","Cast Q",true)
	end)
	Menu.NewTree("GGTeemoFlee", "Flee", function ()
		Menu.Checkbox("Flee.CastW","Cast W",true)
	end)
	Menu.NewTree("GGTeemoMisc", "Misc.", function ()
		Menu.Checkbox("Misc.CastQKS","Auto-Cast Q Killable",true)
		Menu.Checkbox("Misc.CastRGap","Auto-Cast R GapCloser",true)
	end)
	Menu.NewTree("GGTeemoDrawing", "Drawing", function ()
		Menu.Checkbox("Drawing.DrawQ","Draw Q Range",true)
		Menu.ColorPicker("Drawing.DrawQColor", "Draw Q Color", 0xEF476FFF)
		Menu.Checkbox("Drawing.DrawR","Draw R Range",true)
		Menu.ColorPicker("Drawing.DrawRColor", "Draw R Color", 0xFFD166FF)
	end)
end

Menu.RegisterMenu("GGTeemo","GGTeemo",GGTeemoMenu)

-- Global vars
local spells = {
	Q = Spell.Targeted({
		Slot = Enums.SpellSlots.Q,
		Delay = 0.25,
		Range = 680,
	}),
	W = Spell.Active({
		Slot = Enums.SpellSlots.W,
	}),
	R = Spell.Skillshot({
		Slot = Enums.SpellSlots.R,
		Range = 400, -- initial range
		Speed = 1550,
		Delay = 0.25,
		Radius = 75,
		Type = "Circular",
	}),
}

local lastTick = 0

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function CountShrooms()
	return Player:GetSpell(SpellSlots.R).Ammo
end

-- dynamic R Range
local function GetRRange()
	local rLevel = Player:GetSpell(SpellSlots.R).Level
	local rRange = 150 + rLevel * 250
	local baseBounceRange = 200 + rLevel * 100

	local nShrooms = CountShrooms()
	local bounceRange = 0

	--if nShrooms >= 2 then
	--	bounceRange = nShrooms * baseBounceRange
	--end

	finalRange = rRange + bounceRange
	spells.R.Range = finalRange
	return finalRange
end

local function GetQDmg(target)
	local playerAI = Player.AsAI
	local dmgQ = 35 + 45 * Player:GetSpell(SpellSlots.Q).Level
	local bonusDmg = playerAI.TotalAP * 0.8
	local totalDmg = dmgQ + bonusDmg
	return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

local function CastQ(target)
	if spells.Q:IsReady() then
		if spells.Q:Cast(target) then
			return
		end
	end
end

local function CastW()
	if spells.W:IsReady() then
		if spells.W:Cast() then
			return
		end
	end
end

local function CastR(target, hitChance)
	if spells.R:IsReady() then
		if spells.R:CastOnHitChance(target, hitChance)  then
			return
		end
	end
end

local function AutoQKS()
	if not spells.Q:IsReady() then return end

	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, qRange = Player.Position, (spells.Q.Range + Player.BoundingRadius)

	for handle, obj in pairs(enemies) do
		local hero = obj.AsHero
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			local healthPred = HealthPred.GetHealthPrediction(hero, spells.Q.Delay)
			if dist <= qRange and GetQDmg(hero) > healthPred then
				CastQ(hero) -- Q KS
			end
		end
	end
end

local function Waveclear()

	if spells.Q:IsReady() or spells.R:IsReady() then

		local pPos, pointsR, minionQ = Player.Position, {}, nil
		local isJgCS = false

		-- Enemy Minions
		for k, v in pairs(ObjManager.GetNearby("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posR = minion:FastPrediction(spells.R.Delay)
				if posR:Distance(pPos) < spells.R.Range and minion.IsTargetable then
					table.insert(pointsR, posR)
				end

				if minion:Distance(pPos) <= spells.Q.Range then
					if minionQ then
						local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
						if minionQ.Health >= healthPred then
							minionQ = minion
						end
					else
						minionQ = minion
					end
				end
			end
		end

		-- Jungle Minions
		if #pointsR == 0 or not minionQ then
			for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) then
					local posR = minion:FastPrediction(spells.R.Delay)
					if posR:Distance(pPos) < spells.R.Range and minion.IsTargetable then
						isJgCS = true
						table.insert(pointsR, posR)
					end

					if minion:Distance(pPos) <= spells.Q.Range then
						isJgCS = true
						if minionQ then
							local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
							if minionQ.Health >= healthPred then
								minionQ = minion
							end
						else
							minionQ = minion
						end
					end
				end
			end
		end

		local castQMenu = nil
		local castRMenu = nil
		local castRHCMenu = nil
		local castRMinManaMenu = nil

		if not isJgCS then
			castQMenu = Menu.Get("Waveclear.CastQ")
			castRMenu = Menu.Get("Waveclear.CastR")
			castRHCMenu = Menu.Get("Waveclear.CastRHC")
			castRMinManaMenu = Menu.Get("Waveclear.CastRMinMana")
		else
			castQMenu = Menu.Get("Waveclear.CastQJg")
			castRMenu = Menu.Get("Waveclear.CastRJg")
			castRHCMenu = Menu.Get("Waveclear.CastRHCJg")
			castRMinManaMenu = Menu.Get("Waveclear.CastRMinManaJg")
		end

		local bestPosR, hitCountR = spells.R:GetBestCircularCastPos(pointsR)
		if bestPosR and hitCountR >= castRHCMenu
				and spells.R:IsReady() and castRMenu
				and Player.Mana >= (castRMinManaMenu / 100) * Player.MaxMana then
			spells.R:Cast(bestPosR)
			return
		end
		if minionQ and spells.Q:IsReady() and castQMenu then
			if minionQ.Health <= GetQDmg(minionQ) then
				CastQ(minionQ)
				return
			end
		end

	end
end

local function LasthitQ()
	if spells.Q:IsReady() then
		local pPos, minionQ = Player.Position, nil

		-- Enemy Minions
		for k, v in pairs(ObjManager.GetNearby("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				if minion:Distance(pPos) <= spells.Q.Range then
					if minionQ then
						local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
						if minionQ.Health >= healthPred then
							minionQ = minion
						end
					else
						minionQ = minion
					end
				end
			end
		end

		-- Jungle Minions
		if not minionQ then
			for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) then
					if minion:Distance(pPos) <= spells.Q.Range then
						if minionQ then
							local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
							if minionQ.Health >= healthPred then
								minionQ = minion
							end
						else
							minionQ = minion
						end
					end
				end
			end
		end

		if minionQ then
			if minionQ.Health <= GetQDmg(minionQ) then
				CastQ(minionQ)
				return
			end
		end

	end

end

local function OnHighPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	AutoQKS()
end

local function OnNormalPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	local gameTime = Game.GetTime()
	if gameTime < (lastTick + 0.25) then return end
	lastTick = gameTime

	-- update R range
	GetRRange()

	-- Combo
	if Orbwalker.GetMode() == "Combo" then

		if Menu.Get("Combo.CastQ") and not Menu.Get("Combo.CastAAQ") then
			if spells.Q:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, false)
				if target then
					CastQ(target)
					return
				end
			end
		end
		if Menu.Get("Combo.CastW") then
			if spells.W:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(Player.AttackRange + Player.BoundingRadius, false)
				if target then
					CastW()
					return
				end
			end
		end
		if Menu.Get("Combo.CastR") then
			if spells.R:IsReady() then
				local realRRange = GetRRange()
				local target = Orbwalker.GetTarget() or TS:GetTarget(realRRange + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= Menu.Get("Combo.CastRHR")
						and Player.Mana >= (Menu.Get("Combo.CastRMinMana") / 100) * Player.MaxMana then
					CastR(target,Menu.Get("Combo.CastRHC"))
					return
				end
			end
		end

		-- Waveclear
	elseif Orbwalker.GetMode() == "Waveclear" then

		Waveclear()

		-- Harass
	elseif Orbwalker.GetMode() == "Harass" then

		if Menu.Get("Harass.CastQ") then
			if spells.Q:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, false)
				if target then
					CastQ(target)
					return
				end
			end
		end
		if Menu.Get("Harass.CastR") then
			if spells.R:IsReady() then
				local realRRange = GetRRange()
				local target = Orbwalker.GetTarget() or TS:GetTarget(realRRange + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= Menu.Get("Harass.CastRHR")
						and Player.Mana >= (Menu.Get("Harass.CastRMinMana") / 100) * Player.MaxMana then
					CastR(target,Menu.Get("Harass.CastRHC"))
					return
				end
			end
		end

		-- Lasthit
	elseif Orbwalker.GetMode() == "Lasthit" then
		if Menu.Get("Lasthit.CastQ") then
			LasthitQ()
		end

		-- Flee
	elseif Orbwalker.GetMode() == "Flee" then
		if Menu.Get("Flee.CastW") then
			CastW()
		end
	end

end

local function OnDraw()

	-- Draw Q Range
	if Player:GetSpell(SpellSlots.Q).IsLearned and Menu.Get("Drawing.DrawQ") then
		Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 30, 1.0, Menu.Get("Drawing.DrawQColor"))
	end
	-- Draw R Range
	if Player:GetSpell(SpellSlots.R).IsLearned and Menu.Get("Drawing.DrawR") then
		Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 1.0, Menu.Get("Drawing.DrawRColor"))
	end

end

local function OnGapclose(source, dash)
	if not source.IsEnemy then return end

	local paths = dash:GetPaths()
	local endPos = paths[#paths].EndPos
	local pPos = Player.Position
	local pDist = pPos:Distance(endPos)
	if pDist > 400 or pDist > pPos:Distance(dash.StartPos) or not source:IsFacing(pPos) then return end

	if Menu.Get("Misc.CastRGap") and spells.R:IsReady() then
		Input.Cast(SpellSlots.R, endPos)
	end
end

local function OnPostAttack(target)

	if Orbwalker.GetMode() == "Combo" then
		if Menu.Get("Combo.CastQ") and Menu.Get("Combo.CastAAQ") then
			if spells.Q:IsReady() then
				if target then
					CastQ(target)
					return
				end
			end
		end
	elseif Orbwalker.GetMode() == "Harass" then
		if Menu.Get("Harass.CastQ") and Menu.Get("Harass.CastAAQ") then
			if spells.Q:IsReady() then
				if target then
					CastQ(target)
					return
				end
			end
		end
	end

end

function OnLoad()
    Teemo.Initialize()
    return true
end
