--!strict
-- TutorialService: el tutorial de 4 pasos para los que entran por primera vez.
-- Los pasos avanzan con cosas que pasan de verdad en el juego (las decide el servidor):
--   1 GrabEgg  "GRAB AN EGG!"  → al agarrar un huevo en el cañón
--   2 RunBack  "RUN BACK!"     → al salir del cañón con el huevo (escondiéndote en una cueva si viene la ola)
--   3 HatchIt  "HATCH IT!"     → al poner el huevo en uno de tus nidos
--   4 GetRich  "GET RICH!"     → al comprar tu primera mejora en la tienda
--   5 Done
-- Cada paso completado da Config.Tutorial.StepReward monedas ("STEP COMPLETE! +100 coins" en la pantalla).
-- El paso se guarda en el perfil (PlayerDataService) y se publica como atributo "TutorialStep"
-- para que el cliente muestre el cartel y la flecha (ver Tutorial.luau en el cliente).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TutorialService = {}

TutorialService.Steps = {
	GrabEgg = 1,
	RunBack = 2,
	HatchIt = 3,
	GetRich = 4,
	Done = 5,
}

local S = TutorialService.Steps

-- Qué evento completa cada paso (con "Incubated" también vale si todavía estaba en "RunBack")
local EVENT_COMPLETES: { [string]: { number } } = {
	Grabbed = { S.GrabEgg },
	BackSafe = { S.RunBack },
	Incubated = { S.RunBack, S.HatchIt },
	BoughtUpgrade = { S.GetRich },
}

local notifyRemote = Remotes.Event("Notify")
local actionRemote = Remotes.Event("TutorialAction")

-- Cambia el paso. Si avanza (y no fue por saltearlo), paga la recompensa de cada paso completado.
local function setStep(player: Player, step: number, reward: boolean)
	local profile = PlayerDataService.Get(player)
	if not profile or profile.TutorialStep == step then
		return
	end
	local previous = profile.TutorialStep
	profile.TutorialStep = step
	PlayerDataService.SyncLevels(player) -- publica el atributo "TutorialStep"
	if reward and step > previous then
		local coins = (step - previous) * Config.Tutorial.StepReward
		PlayerDataService.AddCoins(player, coins)
		actionRemote:FireClient(player, "StepComplete", previous, coins)
	end
	if step == S.Done then
		notifyRemote:FireClient(player, "Tutorial complete! Good luck in the canyon!")
	end
end

-- Los otros servicios avisan acá cuando pasa algo ("Grabbed", "Incubated", "BoughtUpgrade").
-- Solo avanza si el jugador está justo en un paso que ese evento completa.
function TutorialService.OnEvent(player: Player, event: string)
	local profile = PlayerDataService.Get(player)
	local completes = EVENT_COMPLETES[event]
	if profile and completes and table.find(completes, profile.TutorialStep) then
		setStep(player, completes[#completes] + 1, true)
	end
end

-- Paso 2: ¿ya salió del cañón con el huevo? (lo revisa el servidor mirando dónde está)
local function checkRunBack()
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.Get(player)
		if profile and profile.TutorialStep == S.RunBack and player:GetAttribute("CarriedEggRarity") ~= nil then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and root.Position.X < Config.Map.CanyonStartX - 4 then
				TutorialService.OnEvent(player, "BackSafe")
			end
		end
	end
end

function TutorialService.Init()
	-- Lo único que el cliente puede pedir es saltear el tutorial (sin recompensa).
	actionRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		if action == "Skip" then
			setStep(player, S.Done, false)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			checkRunBack()
		end
	end)
end

return TutorialService
