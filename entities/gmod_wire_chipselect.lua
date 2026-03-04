AddCSLuaFile()
DEFINE_BASECLASS("base_wire_entity")
ENT.PrintName     = "Chip Select"
ENT.WireDebugName = "Chip Select"

if CLIENT then return end -- No more client

function ENT:Initialize()
	BaseClass.Initialize(self)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
    self.Inputs = Wire_CreateInputs(self, {"Output Device"})
    self.Outputs = Wire_CreateOutputs(self, {"Gated Memory"})
end

local bor = bit.bor
local band = bit.band
local bxor = bit.bxor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local floor = math.floor

function ENT:Setup(mask,partial,inverted)
	self.mask = mask
	self.partial = partial
	self.invertmask = inverted
	self.inversemask = bxor(math.pow(2,31)-1,mask)
	self:UpdateOverlayText()
end

function ENT:UpdateOverlayText()
	self:SetOverlayText(string.format("Mask: 0x%.8X\nPartial Masking: %s\nInverted Mask: %s",
	self.mask,self.partial and "true" or "false", self.invertmask and "true" or "false"))
end

function ENT:BuildDupeInfo()
	local info = BaseClass.BuildDupeInfo(self) or {}
	info.mask = self.mask
	info.partial = self.partial
	info.invertmask = self.invertmask
	self.inversemask = bxor(math.pow(2,31)-1,self.mask)
	return info
end

function ENT:TriggerInput(iname, value)
	if iname == "Output Device" then
		self.Memory = self.Inputs["Output Device"].Src
	end
end

function ENT:ReadCell(index)
	local chipselect = band(index,self.mask)
	if (self.partial and chipselect ~= 0) or chipselect == self.mask then
		if self.invertmask then return 0 end
		if self.Memory and self.Memory.ReadCell then
			print("start address",index,"end address",band(index,self.inversemask))
			return self.Memory:ReadCell(band(index,self.inversemask))
		else
			return 0
		end
	end
	return 0
end


function ENT:WriteCell(index, value)
	local chipselect = band(index,self.mask)
	if (self.partial and chipselect ~= 0) or chipselect == self.mask then
		if self.invertmask then return 0 end
		if self.Memory and self.Memory.WriteCell then
			return self.Memory:WriteCell(band(index,self.inversemask),value)
		else
			return 0
		end
	end
	return 0
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)
	ent:UpdateOverlayText()
end

duplicator.RegisterEntityClass("gmod_wire_chipselect", WireLib.MakeWireEnt, "Data")
