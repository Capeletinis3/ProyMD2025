--!strict
-- TutorialService: el tutorial para los que entran por primera vez.
-- Los pasos avanzan con cosas que pasan de verdad en el juego (las decide el servidor):
--   1 GrabEgg      → al agarrar un huevo
--   2 Incubate     → al ponerlo en la incubadora
--   3 WaitHatch    → cuando sale tu primera mascota
--   4 OpenUpgrades → al abrir el panel de mejoras (o comprar una mejora)
--   5 Done
-- El paso se guarda en el perfil (PlayerDataService) y se publica como atributo "TutorialStep"
-- para que el cliente muestre el texto y la flecha (ver Tutorial.luau en el cliente).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TutorialService = {}

TutorialService.Steps = {
	GrabEgg = 1,
	Incubate = 2,
	WaitHatch = 3,
	OpenUpgrades = 4,
	Done = 5,
}

-- Qué evento completa cada paso
local EVENT_COMPLETES: { [string]: number } = {
	Grabbed = TutorialService.Steps.GrabEgg,
	Incubated = TutorialService.Steps.Incubate,
	Hatched = TutorialService.Steps.WaitHatch,
	OpenedUpgrades = TutorialService.Steps.OpenUpgrades,
	BoughtUpgrade = TutorialService.Steps.OpenUpgrades,
}

local notifyRemote = Remotes.Event("Notify")
local actionRemote = Remotes.Event("TutorialAction")

local function setStep(player: Player, step: number)
	local profile = PlayerDataService.Get(player)
	if not profile or profile.TutorialStep == step then
		return
	end
	profile.TutorialStep = step
	PlayerDataService.SyncLevels(player) -- publica el atributo "TutorialStep"
	if step == TutorialService.Steps.Done then
		notifyRemote:FireClient(player, "Tutorial complete! Good luck in the storm!")
	end
end

-- Los otros servicios avisan acá cuando pasa algo ("Grabbed", "Incubated", "Hatched", "BoughtUpgrade").
-- Solo avanza si el jugador está justo en el paso que ese evento completa.
function TutorialService.OnEvent(player: Player, event: string)
	local profile = PlayerDataService.Get(player)
	local completes = EVENT_COMPLETES[event]
	if profile and completes and profile.TutorialStep == completes then
		setStep(player, completes + 1)
	end
end

function TutorialService.Init()
	-- Lo único que el cliente puede avisar: que abrió el panel de mejoras, o que quiere saltear el tutorial.
	-- Es inofensivo (solo mueve el tutorial hacia adelante), pero igual revisamos lo que llega.
	actionRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		if action == "OpenedUpgrades" then
			TutorialService.OnEvent(player, "OpenedUpgrades")
		elseif action == "Skip" then
			setStep(player, TutorialService.Steps.Done)
		end
	end)
end

return TutorialService
