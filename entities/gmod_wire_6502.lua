AddCSLuaFile()
DEFINE_BASECLASS("base_wire_entity")
ENT.PrintName     = "6502 8-bit CPU"
ENT.WireDebugName = "6502"

if CLIENT then return end -- No more client

function ENT:Initialize()
	BaseClass.Initialize(self)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self.Inputs = Wire_CreateInputs(self, {"CLK","Device 1", "Device 2", "Device 3", "Device 4", "Frequency", "Reset"})
	self.Outputs = Wire_CreateOutputs(self, {"Interrupt"})
end

function ENT:DeviceRead(index)
	local v = 0
	local d1 = self.Inputs["Device 1"].Src
	local d2 = self.Inputs["Device 2"].Src
	local d3 = self.Inputs["Device 3"].Src
	local d4 = self.Inputs["Device 4"].Src
	if d1 and d1.ReadCell then
		v = bit.bor(v,d1:ReadCell(self.VM.AddressCache[1][index]))
	end
	if d2 and d2.ReadCell then
		v = bit.bor(v,d2:ReadCell(self.VM.AddressCache[2][index]))
	end
	if d3 and d3.ReadCell then
		v = bit.bor(v,d3:ReadCell(self.VM.AddressCache[3][index]))
	end
	if d4 and d4.ReadCell then
		v = bit.bor(v,d4:ReadCell(self.VM.AddressCache[4][index]))
	end
	return 0
end

function ENT:DeviceWrite(index, value)
	local d1 = self.Inputs["Device 1"].Src
	local d2 = self.Inputs["Device 2"].Src
	local d3 = self.Inputs["Device 3"].Src
	local d4 = self.Inputs["Device 4"].Src
	if d1 and d1.WriteCell then
		d1:WriteCell(self.VM.AddressCache[1][index],value)
	end
	if d2 and d2.WriteCell then
		d2:WriteCell(self.VM.AddressCache[2][index],value)
	end
	if d3 and d3.WriteCell then
		d3:WriteCell(self.VM.AddressCache[3][index],value)
	end
	if d4 and d4.WriteCell then
		d4:WriteCell(self.VM.AddressCache[4][index],value)
	end
end

function ENT:TriggerInput(iname, value)
    if iname == "Frequency" then
        self.Frequency = value
    end
	if iname == "Reset" then
		self.VM:Reset()
	end
end

function ENT:Think()
	local vm = self.VM
	local target = vm.cycles + (self.Frequency or 0)
	while vm.cycles < target do
		vm:Step()
	end
end

function ENT:Setup(d1pins,d2pins,d3pins,d4pins)
	self:UpdateOverlayText()
	local d1 = {}
	local d2 = {}
	local d3 = {}
	local d4 = {}
	local DPins = {d1,d2,d3,d4}
	for m in string.gmatch(d1pins,"%-*%d+") do
		table.insert(d1,tonumber(m))
	end
	for m in string.gmatch(d2pins,"%-*%d+") do
		table.insert(d2,tonumber(m))
	end
	for m in string.gmatch(d3pins,"%-*%d+") do
		table.insert(d3,tonumber(m))
	end
	for m in string.gmatch(d4pins,"%-*%d+") do
		table.insert(d4,tonumber(m))
	end
	self.VM = AVM.New(DPins)
	self.VM.DeviceRead = self.DeviceRead
	self.VM.DeviceWrite = self.DeviceWrite
	self.VM.Entity = self
end

function ENT:UpdateOverlayText()
end

function ENT:BuildDupeInfo()
	local info = BaseClass.BuildDupeInfo(self) or {}
	return info
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)
	ent:UpdateOverlayText()
end

duplicator.RegisterEntityClass("gmod_wire_6502", WireLib.MakeWireEnt, "Data")
