--[[
	
	-> Como Usar Hitbox:
		
		Hitbox Template (Primeiro argumento do .new)
		{
			CFrame   : CFrame,
			Size     : Vector3, -> Apenas se for Overlap
			Radius   : number?, -> Apenas se Type for igual a "Magnitude"
			Duration : number?, -> Faz a hitbox durar mais tempo ativa, é um loop onde spama hitbox
			WaitTime : number?, -> Cooldown da duração da hitbox, ótimo para barrage etc
			HitOnce  : boolean?, -> Se true, pega apenas 1 inimigo
			Exclude  : {Instance}?, -> blacklist, funciona apenas se type == "Overlap" ou nil
			Type     : "Magnitude"?, -> Type "Magnitude" ou "Overlap". Se deixar nil, vira overlap
			Callback : (Enemies: {Model}) -> ()?, -> Função de callback quando a hitbox encosta em algo
			Debug    : boolean?, -> Cria uma part para mostrar a hitbox
		})
		
	-> Exemplos:
	
	// Magnitude:
	
	Global.HitboxManager.new({
		CFrame = CFrame.new(RootPart.CFrame),
		Callback = function(EnemiesCharacters: {Model})
			--> EnemiesCharacters é uma table com vários characters
			
			print(EnemiesCharacters)
			
			for _, Enemy in EnemiesCharacters do
				local EnemyHumanoid = Enemy.Humanoid
				
				--> Firar Server com lista de enemy
			end
		end,
		Type = "Magnitude",
		Debug = true,
		WaitTime = .1,
		Duration = 3,
	})
	
	// Overlap:
	
	Global.HitboxManager.new({
		CFrame = RootPart.CFrame,
		Size = Vector3.new(20,20,20),
		Callback = function(EnemiesCharacters: {Model})
			--> EnemiesCharacters é uma table com vários characters

			print(EnemiesCharacters)

			for _, Enemy in EnemiesCharacters do
				local EnemyHumanoid = Enemy.Humanoid

				--> Firar Server com lista de enemy
			end
		end,
		Type = "Overlap", --> Pode ser nil se quiser
		Debug = true,
		WaitTime = .1,
		Duration = 3,
		Exclude = {Character},
	})
	
	]]

local HitboxManager = {}
HitboxManager.__index = HitboxManager

-- | Services |

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- | Folders |

local Packages = ReplicatedStorage.Shared.Packages:WaitForChild("Modules")

-- | Requires |

local Signal  = require(Packages:WaitForChild("Signal"))

-- | Functions |

local function CreatePart(Position: Vector3, Size: Vector3, ShapeType: Enum.PartType, WaitTime: number?)
	local Player = Players.LocalPlayer
	
	local Part = Instance.new("Part")
	Part.Anchored = true
	Part.Position = Position
	Part.Size = Size
	Part.Color = Color3.fromRGB(255,0,0)
	Part.Transparency = .8
	Part.CanCollide = false
	Part.Parent = workspace.Game.Debris[Player.Name]
	Part.Shape = Enum.PartType.Ball
	
	task.delay(WaitTime or .1, function() Part:Destroy() end)
end

local function Overlap(Cframe: CFrame, Size: Vector3, Blacklist: {Instance}): {BasePart}
	local newBlackList = {}
	for _, instance in Blacklist do
		table.insert(newBlackList, instance)
	end
	
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = newBlackList
	
	local Result = workspace:GetPartBoundsInBox(Cframe, Size, Params)
	
	return Result
end

local function CreateMagnitudeHitbox(Position: Vector3, Radius: number, Debug: boolean?, WaitTime: number?): {Model}
	local EnemiesCharacters: {Model} = {}
	local Player = Players.LocalPlayer
	
	local Character = Player.Character
	local RootPart: BasePart = Character:FindFirstChild("HumanoidRootPart")
	
	if not Character then return end
	if not RootPart then return end
	
	if Debug then
		CreatePart(Position, Vector3.new(Radius,Radius,Radius), Enum.PartType.Ball, WaitTime)		
	end
	
	for _, EnemyPlayer in Players:GetPlayers() do
		if Player == EnemyPlayer then continue end
		
		local EnemyCharacter: Model? = EnemyPlayer.Character
		if not EnemyCharacter then continue end
		
		local EnemyRootPart: BasePart = EnemyCharacter:FindFirstChild("HumanoidRootPart")
		
		if not EnemyRootPart then return end
		
		if (RootPart-EnemyRootPart.Position).Magnitude <= Radius then continue end
		
		local EnemyHumanoid: Humanoid = EnemyCharacter:FindFirstChild("Humanoid")
		
		if not EnemyHumanoid or EnemyHumanoid.Health <= 0 then continue end
		
		table.insert(EnemiesCharacters, EnemyCharacter)
	end
	
	return EnemiesCharacters
end

local function CreateOverlapHitbox(Cframe: CFrame, Size: Vector3, Exclude: {Instance}, Debug: boolean?, WaitTime: number?): {Model}
	local PartsFound = Overlap(Cframe, Size, Exclude)
	
	local EnemiesCharacters: {Model} = {}
	
	for _, BasePart: BasePart in PartsFound do
		local EnemyHumanoid = BasePart.Parent:FindFirstChild("Humanoid")
	
		if not EnemyHumanoid then continue end
		
		local EnemyCharacter = EnemyHumanoid.Parent
		
		if EnemyCharacter.Parent ~= workspace.Game.Characters and EnemyCharacter.Parent ~= workspace.Game.NPCs.Enemies then continue end
		
		table.insert(EnemiesCharacters, EnemyCharacter)
	end
	
	if Debug then
		CreatePart(Cframe.Position, Size, Enum.PartType.Block, WaitTime)
	end
	
	return EnemiesCharacters
end

function HitboxManager.new(Template: {
		CFrame   : CFrame,
		Size     : Vector3,
		Radius   : number?,
		Duration : number?,
		WaitTime : number?,
		HitOnce  : boolean?,
		Exclude  : {Instance}?,
		Type     : "Magnitude"?,
		Callback : (Enemies: {Model}) -> ()?,
		Debug    : boolean?,
	})
	
	local self = setmetatable({}, HitboxManager)
	self.onDestroying = Signal.new()
	
	local EnemiesFound = {}
	
	if Template.Duration then
		local Activated = true
		
		task.delay(Template.Duration, function() Activated = false end)
		
		task.spawn(function()
			while Activated do
				if self.Destroyed then break end
				
				local Enemies: {Model} = Template.Type == "Magnitude"
					and CreateMagnitudeHitbox(Template.CFrame.Position, Template.Radius, Template.Debug, Template.WaitTime)
					or CreateOverlapHitbox(Template.CFrame, Template.Size, Template.Exclude, Template.Debug, Template.WaitTime)
				
				for _, Enemy in Enemies do
					if table.find(EnemiesFound, Enemy) then continue end
					
					if Template.Callback then Template.Callback(Enemies) end
					
					table.insert(EnemiesFound, Enemy)
				end
				
				task.wait(Template.WaitTime)
			end
		end)
	else
		local Enemies = CreateOverlapHitbox(Template.CFrame, Template.Size, Template.Exclude, Template.Debug, Template.WaitTime)
		EnemiesFound = Enemies
		
		if Template.Callback then Template.Callback(Enemies) end
	end
	
	self.Enemies = EnemiesFound
	
	return self
end

function HitboxManager:Destroy()
	self.onDestroying:Fire()
	self.Destroyed = true
end

return HitboxManager
