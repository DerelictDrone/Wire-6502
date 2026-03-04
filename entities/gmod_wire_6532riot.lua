AddCSLuaFile()
DEFINE_BASECLASS("base_wire_entity")
ENT.PrintName     = "6532 RAM I/O-TIMER"
ENT.WireDebugName = "6532 RIOT"

if CLIENT then return end -- No more client

function ENT:Initialize()
	BaseClass.Initialize(self)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
    self.riotTimer = 0
    self.riotDivider = 1
    self.riotCyclesLeft = 0
    self.riotInterrupt = false
    self.RAM = {}
    for i=0,127 do
        self.RAM[i] = 0
    end
    self.Inputs = Wire_CreateInputs(self, {"Port A", "Port B", "Frequency", "Reset"})
    self.Outputs = Wire_CreateOutputs(self, {"Memory", "Interrupt"})
end

local bor = bit.bor
local band = bit.band
local bxor = bit.bxor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local floor = math.floor

function ENT:Setup()
	self:UpdateOverlayText()
end

function ENT:UpdateOverlayText()
end

function ENT:BuildDupeInfo()
	local info = BaseClass.BuildDupeInfo(self) or {}
    info.riotTimer = self.riotTimer
    info.riotDivider = self.riotDivider
    info.riotCyclesLeft = self.riotCyclesLeft
    info.riotInterrupt = self.riotInterrupt
	return info
end

function ENT:To8(value)
    return band(value, 0xFF)
end

function ENT:TriggerInput(iname, value)
    if iname == "Frequency" then
        self.riotFrequency = value
    end
end

function ENT:Think()
    if self.riotDivider > 0 then
        self.riotCyclesLeft = self.riotCyclesLeft - (self.riotFrequency or 0)

        if self.riotCyclesLeft <= 0 then
            self.riotTimer = self:To8(self.riotTimer - 1)

            if self.riotTimer == 255 then
                    self.riotInterrupt = true
                    self.riotDivider = 1
                end

            self.riotCyclesLeft = self.riotCyclesLeft + self.riotDivider
        end
    end
end

-- port A and port B read need to respect the direction masks
function ENT:ReadPortA()
    local port1 = self.Inputs["Port A"].Src
    local mask = 0xFF
    if port1 and port1:ReadCell(3) ~= 0 then mask = band(mask, bnot(0x10)) end
    if port1 and port1:ReadCell(2) ~= 0 then mask = band(mask, bnot(0x20)) end
    if port1 and port1:ReadCell(1) ~= 0 then mask = band(mask, bnot(0x40)) end
    if port1 and port1:ReadCell(0) ~= 0 then mask = band(mask, bnot(0x80)) end

    if port1 and port1:ReadCell(7) ~= 0 then mask = band(mask, bnot(0x01)) end
    if port1 and port1:ReadCell(6) ~= 0 then mask = band(mask, bnot(0x02)) end
    if port1 and port1:ReadCell(5) ~= 0 then mask = band(mask, bnot(0x04)) end
    if port1 and port1:ReadCell(4) ~= 0 then mask = band(mask, bnot(0x08)) end
    return mask
end

function ENT:ReadPortB()
    local port2 = self.Inputs["Port B"].Src
    local mask = 0xFF
    if port2 and port2:ReadCell(0) ~= 0 then mask = band(mask, bnot(0x01)) end
    if port2 and port2:ReadCell(1) ~= 0 then mask = band(mask, bnot(0x02)) end
    if port2 and port2:ReadCell(2) ~= 0 then mask = band(mask, bnot(0x04)) end
    if port2 and port2:ReadCell(3) ~= 0 then mask = band(mask, bnot(0x08)) end
    if port2 and port2:ReadCell(4) ~= 0 then mask = band(mask, bnot(0x10)) end
    if port2 and port2:ReadCell(5) ~= 0 then mask = band(mask, bnot(0x20)) end
    if port2 and port2:ReadCell(6) ~= 0 then mask = band(mask, bnot(0x40)) end
    if port2 and port2:ReadCell(7) ~= 0 then mask = band(mask, bnot(0x80)) end
    return mask
end

-- use the port direction masks for this
function ENT:WritePortA(d) end
function ENT:WritePortB(d) end

function ENT:ReadInterrupt()
    return self.riotInterrupt and 0x80 or 0x00
end

function ENT:ReadCell(index)
    -- chipset 1 is bit 7
    -- ram switch is bit 8, set ON to switch out of ram mode
    -- chipset 2 is bit 9
    local chip1 = bit.band(0x80,index) ~= 0
    local ramswitch = bit.band(0x100,index) ~= 0
    local chip2 = bit.band(0x200,index) ~= 0
    if not chip1 or chip2 then return 0 end
    if chip1 then
        index = index - 0x180
        if not ramswitch then
            return self.RAM[index]
        end
        -- everything says it only cares about A2, A0
        index = band(index,7)
        if index == 0 then
            return self:ReadPortA()
        elseif index == 1 then
           -- read direction pins for port A
           return self.portAMask
        elseif index == 2 then
            return self:ReadPortB()
        elseif index == 3 then
            -- read direction pins for port B
            return self.portBMask
        elseif index >= 4 then
            local oldIndex = index
            index = band(index,5)
            if index == 4 then
                self.tInterruptEnabled = band(oldIndex,8) == 8
                return self.riotTimer
            elseif index == 5 then
                return self:ReadInterrupt()
            end
        end
    end
    return 0
end

local dividers = {
    [4] = 1,
    [5] = 8,
    [6] = 64,
    [7] = 1024
}



function ENT:WriteCell(index, value)
    index = self:To8(index)
    local chip1 = band(0x80,index) ~= 0
    local ramswitch = band(0x100,index) ~= 0
    local chip2 = band(0x200,index) ~= 0
    if not chip1 or chip2 then return end
    if chip1 then
        index = index - 0x180
        if not ramswitch then
            self.RAM[index] = value
            return
        end
        if index == 0 then
            return self:WritePortA(value)
        end
        if index == 1 then
            self.portAMask = self:To8(value)
            return
        end
        if index == 2 then
            return self:WritePortB(value)
        end
        if index == 3 then
            self.portBMask = self:To8(value)
            return
        end
        local a4_a2 = band(index,20)
        if a4_a2 == 4 then
            self.PA7EdgeInterrupt = band(index,2) ~= 0
            self.PA7EdgeDetectPositive = band(index,1) ~= 0
            return
        end
        if a4_a2 == 20 then
            self.tInterruptEnabled = bit.band(index,8) ~= 0
            index = index - 20
            if index == 4 then
                self.riotTimer = value
                self.riotCyclesLeft = value
                self.riotDivider = 1
            elseif index == 5 then
                self.riotTimer = value
                self.riotCyclesLeft = value * 8
                self.riotDivider = 8
            elseif index == 6 then
                self.riotTimer = value
                self.riotCyclesLeft = value * 64
                self.riotDivider = 64
            elseif index == 7 then
                self.riotTimer = value
                self.riotCyclesLeft = value * 1024
                self.riotDivider = 1024
            end
        end
    end
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)
	ent:UpdateOverlayText()
end

duplicator.RegisterEntityClass("gmod_wire_6502", WireLib.MakeWireEnt, "Data")
