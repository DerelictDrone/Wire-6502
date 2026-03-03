AddCSLuaFile("wire/client/colors.lua")

if CLIENT then
	include("wire/client/colors.lua")
end
if SERVER then
	include("wire/server/avm.lua")
end
