AddCSLuaFile()
DEFINE_BASECLASS("base_wire_entity")
ENT.PrintName     = "T.I.A Television Interface Adapter"
ENT.WireDebugName = "TIA"

local bor = bit.bor
local band = bit.band
local bxor = bit.bxor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local floor = math.floor

function ENT:BackupTIAState()
    return {
        self.scanline,
        self.colubk,
        self.colupf,
        self.colup0,
        self.colup1,
        self.vsync,
        self.vblank,
        self.pf0,
        self.pf1,
        self.pf2,
        self.grp0,
        self.grp1,
        self.resp0,
        self.resp1,
        self.hmp0,
        self.hmp1,
        self.ctrlpf
    }
end

function ENT:RestoreTIAState(state)
    self.scanline,
    self.colubk,
    self.colupf,
    self.colup0,
    self.colup1,
    self.vsync,
    self.vblank,
    self.pf0,
    self.pf1,
    self.pf2,
    self.grp0,
    self.grp1,
    self.resp0,
    self.resp1,
    self.hmp0,
    self.hmp1,
    self.ctrlpf = unpack(state)
end

if CLIENT then
    function ENT:Initialize()
        BaseClass.Initialize(self)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self.scanline = 0
        self.colubk = 0
        self.colupf = 0
        self.colup0 = 0
        self.colup1 = 0
        self.vsync  = 0
        self.vblank = 0
        self.pf0 = 0
        self.pf1 = 0
        self.pf2 = 0
        self.grp0 = 0
        self.grp1 = 0
        self.resp0 = 0
        self.resp1 = 0
        self.hmp0 = 0
        self.hmp1 = 0
        self.ctrlpf = 0
    end
    net.Receive("tia_scanline_screen",function(len,ply)
        local TIA = net.ReadEntity()
        local screen = net.ReadEntity()
        local state = {
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
            net.ReadInt(8),
        }
        TIA:RestoreState(state)
        TIA:RenderScanline(screen)
    end)
    function ENT:RenderScanline(targetEnt)
        if self.scanline >= 192 then return end
    
        if band(self.vblank, 0x02) ~= 0 then
            self.scanline = self.scanline + 1
            return
        end
    
        local base = self.scanline * 160
        local bg = self.colubk
        local pf = self.colupf
    
        for x = 0, 159 do
            local tile = floor(x / 4)
            local pixel = 0
            local pos
    
            if tile < 20 then
                if tile < 4 then
                    pos = tile + 4
                    pixel = band(rshift(self.pf0, pos), 1)
                elseif tile < 12 then
                    pos = 7 - ((tile - 4) % 8)
                    pixel = band(rshift(self.pf1, pos), 1)
                else
                    pos = (tile - 12) % 8
                    pixel = band(rshift(self.pf2, pos), 1)
                end
            else
                local mirror = band(self.ctrlpf, 0x01) ~= 0
                local mirrored = mirror and (19 - (tile - 20)) or (tile - 20)
    
                if mirrored < 4 then
                    pos = mirrored + 4
                    pixel = band(rshift(self.pf0, pos), 1)
                elseif mirrored < 12 then
                    pos = 7 - ((mirrored - 4) % 8)
                    pixel = band(rshift(self.pf1, pos), 1)
                else
                    pos = (mirrored - 12) % 8
                    pixel = band(rshift(self.pf2, pos), 1)
                end
            end
    
            self.frameBuffer[base + x] = pixel == 1 and pf or bg
        end
    
        for bit = 7, 0, -1 do
            if band(rshift(self.grp0, bit), 1) == 1 then
                local px = self.resp0 + (7 - bit)
                if px >= 0 and px < 160 then
                    self.frameBuffer[base + px] = self.colup0
                end
            end
        end
    
        for bit = 7, 0, -1 do
            if band(rshift(self.grp1, bit), 1) == 1 then
                local px = self.resp1 + (7 - bit)
                if px >= 0 and px < 160 then
                    self.frameBuffer[base + px] = self.colup1
                end
            end
        end
    
        self.scanline = self.scanline + 1
    end
end

if CLIENT then return end -- No more client

util.AddNetworkString("tia_scanline_screen")

function ENT:Initialize()
	BaseClass.Initialize(self)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
    self.Inputs = Wire_CreateInputs(self, {"Port A", "Frequency", "Reset", "RF A/V Out"})
    self.Outputs = Wire_CreateOutputs(self, {"Memory"})
    self.RFScreens = {}
    self.scanline = 0
    self.colubk = 0
    self.colupf = 0
    self.colup0 = 0
    self.colup1 = 0
    self.vsync  = 0
    self.vblank = 0
    self.pf0 = 0
    self.pf1 = 0
    self.pf2 = 0
    self.grp0 = 0
    self.grp1 = 0
    self.resp0 = 0
    self.resp1 = 0
    self.hmp0 = 0
    self.hmp1 = 0
    self.ctrlpf = 0
end

function ENT:Setup()
	self:UpdateOverlayText()
end

function ENT:UpdateOverlayText()
end

function ENT:BuildDupeInfo()
	local info = BaseClass.BuildDupeInfo(self) or {}
	return info
end

function ENT:To8(value)
    return band(value, 0xFF)
end

function ENT:TriggerInput(iname, value)
    if iname == "Frequency" then
    end
    if iname == "RF A/V Out" then
        local rf = self.Inputs["RF A/V Out"].Src
        self.RFScreens = {}
        if rf.TraceWriteDevices then
            local devices = rf:TraceWriteDevices()
            for _,device in ipairs(devices) do
                if device.RFAVCapable then
                    table.insert(self.RFScreens,device)
                end
            end
        end
    end
end

function ENT:Think()
end


function ENT:ReadCell(index)
    if bit.band(index,128+256) then return 0 end
    index = self:To8(index)
    local port1 = self.Inputs["Port A"].Src
    if port1 and port1.ReadCell then
        if index == 0x0C then
            return port1:ReadCell(0) ~= 0 and 0x00 or 0x80
        end

        if index == 0x0D then
            return port1:ReadCell(1) ~= 0 and 0x00 or 0x80
        end
    end
    return 0
end

function ENT:RenderScanlineToDevices()
    local rf = self.Inputs["RF A/V Out"].Src
    local backup = self:BackupTIAState()
    for ind,i in ipairs(self.RFScreens) do
        self:RestoreTIAState(backup)
        net.Start("tia_scanline_screen")
            net.WriteEntity(self)
            net.WriteEntity(i)
            for _,i in ipairs(backup) do
                net.WriteInt(i,8)
            end
        net.SendPVS(i:GetPos())
        self:RenderScanline(i)
    end
    if #self.RFScreens == 0 then
        self:RestoreTIAState(backup)
        if rf and rf.WriteCell then
            self:RenderScanline(rf)
        end
    end
    -- after last draw state should be finalized technically
end

local function writeFrameBuffer(device,addr,value)
    if device.RFAVCapable then
        device.FB[addr] = value
    else
        device:WriteCell(addr,value)
    end
end

function ENT:RenderScanline(screen)
    if self.scanline >= 192 then return end

    if band(self.vblank, 0x02) ~= 0 then
        self.scanline = self.scanline + 1
        return
    end

    local base = self.scanline * 160
    local bg = self.colubk
    local pf = self.colupf

    for x = 0, 159 do
        local tile = floor(x / 4)
        local pixel = 0
        local pos

        if tile < 20 then
            if tile < 4 then
                pos = tile + 4
                pixel = band(rshift(self.pf0, pos), 1)
            elseif tile < 12 then
                pos = 7 - ((tile - 4) % 8)
                pixel = band(rshift(self.pf1, pos), 1)
            else
                pos = (tile - 12) % 8
                pixel = band(rshift(self.pf2, pos), 1)
            end
        else
            local mirror = band(self.ctrlpf, 0x01) ~= 0
            local mirrored = mirror and (19 - (tile - 20)) or (tile - 20)

            if mirrored < 4 then
                pos = mirrored + 4
                pixel = band(rshift(self.pf0, pos), 1)
            elseif mirrored < 12 then
                pos = 7 - ((mirrored - 4) % 8)
                pixel = band(rshift(self.pf1, pos), 1)
            else
                pos = (mirrored - 12) % 8
                pixel = band(rshift(self.pf2, pos), 1)
            end
        end

        writeFrameBuffer(screen,base + x, pixel == 1 and pf or bg)
    end

    for bit = 7, 0, -1 do
        if band(rshift(self.grp0, bit), 1) == 1 then
            local px = self.resp0 + (7 - bit)
            if px >= 0 and px < 160 then
                writeFrameBuffer(screen, base + px, self.colup0)
            end
        end
    end

    for bit = 7, 0, -1 do
        if band(rshift(self.grp1, bit), 1) == 1 then
            local px = self.resp1 + (7 - bit)
            if px >= 0 and px < 160 then
                writeFrameBuffer(screen, base + px, self.colup1)
            end
        end
    end

    self.scanline = self.scanline + 1
end

function ENT:WriteCell(index, value)
    if index == 0x00 then
        self.vsync = value
        if band(value, 0x02) ~= 0 then
            self.scanline = 0
        end
    elseif index == 0x01 then self.vblank = value
    elseif index == 0x02 then
        local cycles = self.cycles % 76
        self.cycles = self.cycles + (76 - cycles)
        self:RenderScanlineToDevices()
    elseif index == 0x06 then self.colup0 = value
    elseif index == 0x07 then self.colup1 = value
    elseif index == 0x08 then self.colupf = value
    elseif index == 0x09 then self.colubk = value
    elseif index == 0x0A then self.ctrlpf = value
    elseif index == 0x0D then self.pf0 = value
    elseif index == 0x0E then self.pf1 = value
    elseif index == 0x0F then self.pf2 = value
    elseif index == 0x10 then
        self.resp0 = (self.cycles % 76) * 3 - 68
    elseif index == 0x11 then
        self.resp1 = (self.cycles % 76) * 3 - 68
    elseif index == 0x1B then self.grp0 = value
    elseif index == 0x1C then self.grp1 = value
    elseif index == 0x20 then self.hmp0 = self:To4(rshift(value, 4))
    elseif index == 0x21 then self.hmp1 = self:To4(rshift(value, 4))
    elseif index == 0x2A then
        self.resp0 = self.resp0 + self.hmp0
        self.resp1 = self.resp1 + self.hmp1
    elseif index == 0x2B then
        self.hmp0 = 0
        self.hmp1 = 0
    end
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)
	ent:UpdateOverlayText()
end

duplicator.RegisterEntityClass("gmod_wire_6502", WireLib.MakeWireEnt, "Data")
