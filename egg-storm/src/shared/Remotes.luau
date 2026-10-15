--!strict
-- Remotes: un solo lugar para crear/buscar los RemoteEvents (la forma en que servidor y cliente se hablan).
-- El servidor los crea; el cliente espera a que existan.
-- Regla de oro: todo lo que llega DEL cliente hay que validarlo en el servidor (nunca confiar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.Event(name: string): RemoteEvent
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `[Remotes] {name} is not a RemoteEvent`)
	return remote
end

return Remotes
