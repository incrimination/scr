local players = game:GetService("Players")
local textservice = game:GetService("TextService")
local repstorage = game:GetService("ReplicatedStorage")
local lplr = players.LocalPlayer
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local textchatservice = game:GetService("TextChatService")
local httpservice = game:GetService("HttpService")
local cam = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	cam = (workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera") or Instance.new("Camera"))
end)
local uis = game:GetService("UserInputService")
local requestfunc = syn and syn.request or http and http.request or http_request or fluxus and fluxus.request or request or function(tab)
	if tab.Method == "GET" then
		return {
			Body = game:HttpGet(tab.Url, true),
			Headers = {},
			StatusCode = 200
		}
	end
	return {
		Body = "bad exploit",
		Headers = {},
		StatusCode = 404
	}
end 

local pf = {}
local votekicked = 0
local votekickedsuccess = 0
local kills = 0
local tpstring
local RunLoops = {RenderStepTable = {}, StepTable = {}, HeartTable = {}}
do
	function RunLoops:BindToRenderStep(name, num, func)
		if RunLoops.RenderStepTable[name] == nil then
			RunLoops.RenderStepTable[name] = game:GetService("RunService").RenderStepped:Connect(func)
		end
	end

	function RunLoops:UnbindFromRenderStep(name)
		if RunLoops.RenderStepTable[name] then
			RunLoops.RenderStepTable[name]:Disconnect()
			RunLoops.RenderStepTable[name] = nil
		end
	end

	function RunLoops:BindToStepped(name, num, func)
		if RunLoops.StepTable[name] == nil then
			RunLoops.StepTable[name] = game:GetService("RunService").Stepped:Connect(func)
		end
	end

	function RunLoops:UnbindFromStepped(name)
		if RunLoops.StepTable[name] then
			RunLoops.StepTable[name]:Disconnect()
			RunLoops.StepTable[name] = nil
		end
	end

	function RunLoops:BindToHeartbeat(name, num, func)
		if RunLoops.HeartTable[name] == nil then
			RunLoops.HeartTable[name] = game:GetService("RunService").Heartbeat:Connect(func)
		end
	end

	function RunLoops:UnbindFromHeartbeat(name)
		if RunLoops.HeartTable[name] then
			RunLoops.HeartTable[name]:Disconnect()
			RunLoops.HeartTable[name] = nil
		end
	end
end

--skidded off the devforum because I hate projectile math
-- Compute 2D launch angle
-- v: launch velocity
-- g: gravity (positive) e.g. 196.2
-- d: horizontal distance
-- h: vertical distance
-- higherArc: if true, use the higher arc. If false, use the lower arc.
local function LaunchAngle(v: number, g: number, d: number, h: number, higherArc: boolean)
	local v2 = v * v
	local v4 = v2 * v2
	local root = math.sqrt(v4 - g*(g*d*d + 2*h*v2))
	if not higherArc then root = -root end
	return math.atan((v2 + root) / (g * d))
end

-- Compute 3D launch direction from
-- start: start position
-- target: target position
-- v: launch velocity
-- g: gravity (positive) e.g. 196.2
-- higherArc: if true, use the higher arc. If false, use the lower arc.
local function LaunchDirection(start, target, v, g, higherArc: boolean)
	-- get the direction flattened:
	local horizontal = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
	
	local h = target.Y - start.Y
	local d = horizontal.Magnitude
	local a = LaunchAngle(v, g, d, h, higherArc)
	
	-- NaN ~= NaN, computation couldn't be done (e.g. because it's too far to launch)
	if a ~= a then return nil end
	
	-- speed if we were just launching at a flat angle:
	local vec = horizontal.Unit * v
	
	-- rotate around the axis perpendicular to that direction...
	local rotAxis = Vector3.new(-horizontal.Z, 0, horizontal.X)
	
	-- ...by the angle amount
	return CFrame.fromAxisAngle(rotAxis, a) * vec
end

local function FindLeadShot(targetPosition: Vector3, targetVelocity: Vector3, projectileSpeed: Number, shooterPosition: Vector3, shooterVelocity: Vector3, gravity: Number)
	local distance = (targetPosition - shooterPosition).Magnitude

	local p = targetPosition - shooterPosition
	local v = targetVelocity - shooterVelocity
	local a = Vector3.zero

	local timeTaken = (distance / projectileSpeed)
	
	if gravity > 0 then
		local timeTaken = projectileSpeed/gravity+math.sqrt(2*distance/gravity+projectileSpeed^2/gravity^2)
	end

	local goalX = targetPosition.X + v.X*timeTaken + 0.5 * a.X * timeTaken^2
	local goalY = targetPosition.Y + v.Y*timeTaken + 0.5 * a.Y * timeTaken^2
	local goalZ = targetPosition.Z + v.Z*timeTaken + 0.5 * a.Z * timeTaken^2
	
	return Vector3.new(goalX, goalY, goalZ)
end

local vischeckobj = RaycastParams.new()
local function vischeck(part, checktable, v)
	local bulspeed = checktable.Gun:getWeaponStat("bulletspeed")
	local grav = math.abs(pf.PublicSettings.bulletAcceleration.Y)
	local calculated = LaunchDirection(checktable.Origin, FindLeadShot(part.Position, v._velspring._v0 or Vector3.zero, bulspeed, checktable.Origin, Vector3.zero, grav), bulspeed, grav, false)
	if calculated then 
		return pf.BulletCheck(checktable.Origin, part.Position, calculated, pf.PublicSettings.bulletAcceleration, checktable.Gun:getWeaponStat("penetrationdepth"), 0.022222222222222223)
	end
	return false
end

local function runcode(func)
	func()
end

local function GetAllNearestHumanoidToPosition(player, distance, pos)
	local returnedplayer = {}
	local currentamount = 0
	checktab = checktab or {}
	for i, v in pairs(pf.getEntities()) do -- loop through players
		if not v._alive then continue end
		if v._player.TeamColor ~= lplr.TeamColor then -- checks
			local mag = (pos - v._thirdPersonObject._torso.Position).magnitude
			if mag <= distance then -- mag check
				table.insert(returnedplayer, v)
				currentamount = currentamount + 1
			end
		end
	end
	return returnedplayer
end

local function GetNearestHumanoidToPosition(player, distance, checktab)
	local closest, returnedplayer, targetpart = distance, nil, nil
	checktab = checktab or {}
	if lplr.Character and lplr.Character.PrimaryPart then
		for i, v in pairs(pf.getEntities()) do -- loop through players
			if not v._alive then continue end
			if v._player.TeamColor ~= lplr.TeamColor then -- checks
				local mag = (lplr.Character.PrimaryPart.Position - v._thirdPersonObject[checktab.AimPart].Position).magnitude
				if mag <= closest then -- mag check
					if checktab.WallCheck then
						if not vischeck(v._thirdPersonObject._head, checktab, v) then continue end
					end
					closest = mag
					returnedplayer = v
				end
			end
		end
	end
	return returnedplayer
end

local function worldtoscreenpoint(pos)
	if v3check == "V3" then 
		local scr = worldtoscreen({pos})
		return scr[1], scr[1].Z > 0
	end
	return cam.WorldToScreenPoint(cam, pos)
end

local function GetNearestHumanoidToMouse(player, distance, checktab)
    local closest, returnedplayer = distance, nil
	checktab = checktab or {}
    local mousepos = uis.GetMouseLocation(uis)
	for i, v in pairs(pf.getEntities()) do -- loop through players
		if not v._alive then continue end
		if v._player.TeamColor ~= lplr.TeamColor then -- checks
			local vec, vis = worldtoscreenpoint(v._thirdPersonObject[checktab.AimPart].Position)
			local mag = (mousepos - Vector2.new(vec.X, vec.Y)).magnitude
			if vis and mag <= closest then -- mag check
				if checktab.WallCheck then
					if not vischeck(v._thirdPersonObject._head, checktab, v) then continue end
				end
				closest = mag
				returnedplayer = v
			end
		end
	end
    return returnedplayer
end

local seeable = {}
local actuallyseeable = {}	
local NoFall = {Enabled = false}
runcode(function()
	local function getModule(name)
		return debug.getupvalue(shared.RequireTable, 1)._cache[name].module
	end
	local checkmodules = {
		"BulletCheck",
		"GameRoundInterface",
		"HudScopeInterface",
		"HudNotificationInterface",
		"MenuScreenGui",
		"network",
		"particle",
		"PlayerStatusEvents",
		"PublicSettings",
		"ReplicationInterface",
		"VoteKickInterface",
		"WeaponControllerInterface",
		"HudSpottingInterface",
		"sound",
		"CameraInterface"
	}
	repeat 
		task.wait() 
		local done = true
		for i,v in pairs(checkmodules) do 
			if not getModule(v) then
				done = false
				break
			end
		end
		if done then 
			break
		end
	until false
	local enttable = debug.getupvalue(getModule("ReplicationInterface").getEntry, 1)
	pf = {
		BulletCheck = getModule("BulletCheck"),
		CameraInterface = getModule("CameraInterface"),
		GameRoundInterface = getModule("GameRoundInterface"),
		getEntities = function() return enttable end,
		HudScopeInterface = getModule("HudScopeInterface"),
		HudSpottingInterface = getModule("HudSpottingInterface"),
		HudNotificationInterface = getModule("HudNotificationInterface"),
		MenuScreenGui = getModule("MenuScreenGui"),
		Network = getModule("network"),
		Particles = getModule("particle"),
		PlayerStatusEvents = getModule("PlayerStatusEvents"),
		PublicSettings = getModule("PublicSettings"),
		ReplicationInterface = getModule("ReplicationInterface"),
		Sound = getModule("sound"),
		VoteKickInterface = getModule("VoteKickInterface"),
		WeaponControllerInterface = getModule("WeaponControllerInterface")
	}
	RunLoops:BindToRenderStep("LegitRender", 1, function()
		local allowed = GuiLibrary["ObjectsThatCanBeSaved"]["ESPOptionsButton"]["Api"].Enabled or GuiLibrary["ObjectsThatCanBeSaved"]["TracersOptionsButton"]["Api"].Enabled
		if not allowed then return end
		for i,plr in pairs(enttable) do
			if plr._alive and plr._player.TeamColor ~= lplr.TeamColor then 
				actuallyseeable[plr._player.Name] = false
				if seeable[plr._player.Name] and seeable[plr._player.Name] >= tick() then
					actuallyseeable[plr._player.Name] = true
				else
					actuallyseeable[plr._player.Name] = pf.HudSpottingInterface.isSpotted(plr._player)
					if (not actuallyseeable[plr._player.Name]) then
						local char = plr._thirdPersonObject._character
						local ray = workspace:FindPartOnRayWithWhitelist(Ray.new(cam.CFrame.p, CFrame.lookAt(cam.CFrame.p, plr._thirdPersonObject._head.Position + Vector3.new(0, 0.5, 0)).LookVector * 1000), {table.unpack(pf.GameRoundInterface.raycastWhiteList), char})
						if ray and ray.Parent == char then
							actuallyseeable[plr._player.Name] = true
						end
					end
				end
			end
		end
	end)
end)

local oldnetwork = pf.Network.send
local oldbullet = pf.Particles.new
local oldaward = pf.HudNotificationInterface.bigAward
local oldsound = pf.Sound.PlaySound
local anglex = 0
local angley = 0
local AntiAim = {Enabled = false}
local AntiAimStance = {Value = "Stand"}
pf.Network.send = function(self, method, ...)
	if checkcaller() then return oldnetwork(self, method, ...) end
	if not method then return oldnetwork(self, method, ...) end
	local args = {...}

	if method == "logmessage" then
		return
	end

	if method == "repupdate" and AntiAim.Enabled then 

	end

	if NoFall.Enabled and method == "falldamage" then
		return
	end

	return oldnetwork(self, method, unpack(args))
end
pf.HudNotificationInterface.bigAward = function(awardtype, ...)
	if awardtype == "kill" then 
		kills = kills + 1
	end
	return oldaward(awardtype, ...)
end
pf.Sound.PlaySound = function(...)
	local args = {...}
	if args[1]:find("enemy") then
		local mag = (args[7].position - cam.CFrame.p).magnitude
		if mag <= 30 then
			local playersnear = GetAllNearestHumanoidToPosition(true, 5, args[7].Position)
			for i,v in pairs(playersnear) do
				seeable[v._player.Name] = tick() + 1.5
			end
		end
	end
	return oldsound(unpack(args))
end
runcode(function()
	local GunTracers = {Enabled = false}
	local GunTracersColor = {Hue = 0.44, Sat = 1, Value = 1}
	local GunTracersDelay = {Value = 10}
	local GunTracersFade = {Enabled = false}
	setreadonly(pf.Particles, false)
	pf.Particles.new = function(tab, ...)
		if tab.thirdperson and tab.penetrationdepth then
			local mag = (tab.position - cam.CFrame.p).magnitude
			if mag <= 60 then
				local playersnear = GetAllNearestHumanoidToPosition(true, 5, tab.position)
				for i,v in pairs(playersnear) do
					seeable[v._player.Name] = tick() + 1.5
				end
			end
		end
		if GunTracers.Enabled then
			if (not tab.thirdperson) and tab.penetrationdepth then
				local origin = tab.position
				local position = (origin + (tab.velocity.unit * 100))
				local distance = (origin - position).Magnitude
				local p = Instance.new("Part")
				p.Anchored = true
				p.CanCollide = false
				p.Transparency = 0.5
				p.Color = Color3.fromHSV(GunTracersColor.Hue, GunTracersColor.Sat, GunTracersColor.Value)
				p.Parent = workspace.Ignore
				p.Material = Enum.Material.Neon
				p.Size = Vector3.new(0.01, 0.01, distance)
				p.CFrame = CFrame.lookAt(origin, position) * CFrame.new(0, 0, -distance/2)
				game:GetService("Debris"):AddItem(p, GunTracersDelay.Value / 10)
			end
		end
		return oldbullet(tab)
	end
	setreadonly(pf.Particles, true)
	--[[GunTracers =  GuiLibrary["ObjectsThatCanBeSaved"]["RenderWindow"]["Api"].CreateOptionsButton({
		["Name"] = "GunTracers",
		["Function"] = function(callback) end
	})
	GunTracersColor = GunTracers.CreateColorSlider({
		["Name"] = "Tracer Color",
		["Function"] = function() end
	})
	GunTracersDelay = GunTracers.CreateSlider({
		["Name"] = "Remove Delay",
		["Min"] = 1,
		["Max"] = 30,
		["Default"] = 10,
		["Function"] = function() end,
	})]]
end)

local SilentAimPart
local SilentAimPart2
local SilentAimGun
local SilentAim = {Enabled = false}
local SilentAimAutoFire = {Enabled = false}
local SilentAimMode = {Enabled = false}
local SilentAimFOV = {Value = 1000}
local SilentAimHead = {Value = 100}
local ReachValue = {Value = 1000}
local Reach = {Enabled = false}
local KnifePart
local hook
local aimbound = false
local lastTarget
local lastTargetTick = tick()
local updateScope
hook = hookmetamethod(game, "__index", function(self, ind, val, ...)
	if ind ~= "CFrame" then return hook(self, ind, val, ...) end
	local realcf = hook(self, ind, val, ...)
	if self == KnifePart and Reach.Enabled then 
		return CFrame.new(realcf.Position + (cam.CFrame.lookVector * ReachValue.Value))
	end
	if (self == SilentAimPart or self == SilentAimPart2) and SilentAim.Enabled then
		local realcf = hook(self, ind, val, ...)
		local tar = (math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100)) <= SilentAimHead.Value and "_head" or "_torso"
		local plr 
		local hit, pos, dir = workspace:FindPartOnRayWithIgnoreList(Ray.new(cam.CFrame.p, realcf.p - cam.CFrame.p), {
			workspace.Players:FindFirstChild(lplr.TeamColor.Name),
			workspace.Terrain,
			workspace.Ignore,
			workspace.CurrentCamera
		})
		local realAimPos = pos + (0.01 * dir)
		if SilentAimMode.Value == "Legit" then
			plr = GetNearestHumanoidToMouse(true, SilentAimFOV.Value, {
				AimPart = tar,
				Gun = SilentAimGun,
				Origin = realAimPos,
				WallCheck = true
			})
		else
			plr = GetNearestHumanoidToPosition(true, SilentAimFOV.Value, {
				AimPart = tar,
				Gun = SilentAimGun,
				Origin = realAimPos,
				WallCheck = true
			})
		end
		if plr then 
			local aimpos = plr._thirdPersonObject[tar].Position
			local bulspeed = SilentAimGun:getWeaponStat("bulletspeed")
			local grav = math.abs(pf.PublicSettings.bulletAcceleration.Y)
			local calculated = LaunchDirection(realAimPos, FindLeadShot(aimpos, plr._velspring._v0 or Vector3.zero, bulspeed, realAimPos, Vector3.zero, grav), bulspeed, grav, false)
			if calculated then 
				lastTargetTick = tick() + 1
				lastTarget = plr
				return CFrame.new(realcf.p, realcf.p + calculated)
			end
		end
	end
	return realcf
end)

-- CALL UI

_Hawk = "ohhahtuhthttouttpwuttuaunbotwo"
local Hawk = loadstring(game:HttpGet("https://raw.githubusercontent.com/incrimination/HawkHUB-fork/main/LibSources/HawkLib.lua", true))()

local Window = Hawk:Window({
	ScriptName = "avohook recode",
	DestroyIfExists = true, --if false, gui wont disappear
	Theme = "Dark" --Themes: Pink, White, Dark
})
Window:Close({
	visibility = true, --if false, close button will disappear
	Callback = function()
		Window:Destroy() --Destroying Gui Function
	end,
})
Window:Minimize({
	visibility = true, --if false, close button will disappear
	OpenButton = true, -- Visible = false etc, open button.
	Callback = function()
	end,
})
local tab1 = Window:Tab("visuals") 
local newsec = tab1:Section("gun tracers")
local slider = newsec:Slider("Remove Delay",1,30,function(value)

end)
newsec:ColorPicker("Tracer Color",Color3.fromRGB(39, 39, 39),function(xd)

end)

local tab2 = Window:Tab("rage") 
local newsec2 = tab2:Section("silent aim")
runcode(function()
	local shooting = false
    local SilentAim = newsec2:Button("toggle","i hope ts works",function(callback)
		if callback then 
			task.spawn(function()
				repeat
					targetinfo.Targets.SilentAim = nil
					if lastTargetTick <= tick() and lastTarget then
						lastTarget = nil
					end
					if lastTarget then
						targetinfo.Targets.SilentAim = {
							Player = lastTarget._player,
							Humanoid = {
								Health = lastTarget._healthstate.health0,
								MaxHealth = 100
							}
						}
					end
					local controller = pf.WeaponControllerInterface:getController()
					SilentAimGun = controller and controller:getActiveWeapon()
					if SilentAimGun and SilentAimGun:getWeaponType() == "Firearm" then 
						SilentAimPart = SilentAimGun._barrelPart
						SilentAimPart2 = SilentAimGun:getActiveAimStat("sightpart")
						if SilentAimAutoFire.Enabled then
							local tar = (math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100)) <= SilentAimHead.Value and "_head" or "_torso"
							local plr 
							local hit, pos, dir = workspace:FindPartOnRayWithIgnoreList(Ray.new(cam.CFrame.p, SilentAimPart.Position - cam.CFrame.p), {
								workspace.Players:FindFirstChild(lplr.TeamColor.Name),
								workspace.Terrain,
								workspace.Ignore,
								workspace.CurrentCamera
							})
							local realAimPos = pos + (0.01 * dir)
							if SilentAimMode.Value == "Legit" then
								plr = GetNearestHumanoidToMouse(true, SilentAimFOV.Value, {
									AimPart = tar,
									Gun = SilentAimGun,
									Origin = realAimPos,
									WallCheck = true
								})
							else
								plr = GetNearestHumanoidToPosition(true, SilentAimFOV.Value, {
									AimPart = tar,
									Gun = SilentAimGun,
									Origin = realAimPos,
									WallCheck = true
								})
							end
							SilentAimGun:shoot(plr and true or false)
						end
					end
					task.wait()
				until (not SilentAim.Enabled)
			end)
			updateScope = pf.HudScopeInterface.updateScope
			pf.HudScopeInterface.updateScope = function(pos1, pos2, size1, size2)
				if lastTargetTick > tick() then 
					pos1 = UDim2.new(0, cam.ViewportSize.X / 2, 0, cam.ViewportSize.Y / 2)
					pos2 = UDim2.new(0, cam.ViewportSize.X / 2, 4.439627332431e-09, cam.ViewportSize.Y / 2)
					size1 = UDim2.new(1.12, 0, 1.12, 0)
					size2 = UDim2.new(0.9, 0, 0.9, 0)
				end
				return updateScope(pos1, pos2, size1, size2)
			end
		else
			pf.HudScopeInterface.updateScope = updateScope
			updateScope = nil
			SilentAimGun = nil
			SilentAimPart = nil
			SilentAimPart2 = nil
		end
	end)
end)

local SilentAimMode = newsec2:Dropdown("mode",{"legit", "blatant"},function(xd)

end)

local SilentAimFOV = newsec2:Slider("fov",1,1000,function(value)
	if aimfovframe then
		aimfovframe.Radius = value
	end
end)

local SilentAimHead = newsec2:Slider("hs chance",1,100,function(value)
        
end)

local SilentAimAutoFire = newsec2:Toggle("autofire",function(value)
    if value == true then
            
    elseif value == false then
            
    end
end)

runcode(function()
	local aimbound = false
	local lastTarget
	local lastTargetTick = tick()
	local updateScope

    local nudes = tab2:Section("other")
    local Reach = nudes:Button("reach","melee reach",function(callback)
        if callback then 
            local part
            local gun
            task.spawn(function()
                repeat
                    task.wait()
                    local controller = pf.WeaponControllerInterface:getController()
                    local Knife = controller and controller:getActiveWeapon()
                    if Knife and Knife:getWeaponType() == "Melee" then 
                        KnifePart = Knife._tipPart
                    end
                until (not Reach.Enabled)
            end)
        else
            Knife = nil
        end
    end)
    local ReachValue = nudes:Slider("reach length",1,18,function(value)

    end)
end)
