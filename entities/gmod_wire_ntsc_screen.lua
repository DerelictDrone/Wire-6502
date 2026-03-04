AddCSLuaFile()
DEFINE_BASECLASS("base_wire_entity")
ENT.PrintName     = "NTSC Screen"
ENT.WireDebugName = "NTSC Screen"

local bor = bit.bor
local band = bit.band
local bxor = bit.bxor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local floor = math.floor


if CLIENT then

    net.Receive("ntsc_screen_frame",function(len)
        local screen = net.ReadEntity()
        local data = net.ReadData(net.ReadUInt(2))
        local str = util.Decompress(data)
        
    end)
    function ENT:Initialize()
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self.FB = {}
        self.GPU = WireGPU(self, true)
        for i=0,206718 do
            self.FB[i] = 0
        end
    end
end

function ENT:OnRemove()
    if CLIENT then
        self.GPU:Finalize()
    end
end

function ENT:Draw()
    local SetDrawColor = surface.SetDrawColor
    local DrawRect = surface.DrawRect
    local NTSC = TVColorStandards.NTSC
    self:DrawModel()
    local fb = self.FB
    self.GPU:RenderToWorld(nil, 525, function(rx, ry, w, h, monitor, pos, ang, res)
        for y = 0, 524 do
            local base = y * 393
            local x = 0
            while x < 393 do
                local color = fb[base + x]
                local runEnd = x + 1
                while runEnd < 394 and fb[base + runEnd] == color do
                    runEnd = runEnd + 1
                end
                SetDrawColor(NTSC[rshift(band(color, 0xFE), 1) + 1])
                DrawRect(x*(w/393), y, (runEnd - x)*(w/393), 1)
                x = runEnd
            end
        end
    end,nil,true)
    Wire_Render(self)
end

if CLIENT then return end -- No more client

util.AddNetworkString("ntsc_screen_frame")

function ENT:Initialize()
	BaseClass.Initialize(self)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
    self.FB = {}
    for i=0,206718 do
        self.FB[i] = 0
    end
    self.Inputs = Wire_CreateInputs(self, {})
    self.Outputs = Wire_CreateOutputs(self, {"RF A/V In"})
    self.RFAVCapable = true
    self.PVSCache = RecipientFilter()
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

function ENT:TriggerInput(iname, value)
end

local byte = string.byte
function ENT:Think()
    local f = RecipientFilter()
    f:AddPVS(self:GetPos())
    f:RemovePlayers(self.PVSCache)
    if f:GetCount() > 0 then
        local str = {}
        for ind,i in ipairs(self.FB) do
            table.insert(str,byte(i))
        end
        str = util.Compress(table.concat(str,""))
        net.Start("ntsc_screen_frame",true)
            net.WriteEntity(self)
            net.WriteUInt(#str,2)
            net.WriteData(str)
        net.Send(f)
    end
    self.PVSCache:RemoveAllPlayers()
    self.PVSCache:AddPVS(self:GetPos())
end

function ENT:ReadCell(index)

end

function ENT:WriteCell(index, value)

end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)
	ent:UpdateOverlayText()
end

duplicator.RegisterEntityClass("gmod_wire_6502", WireLib.MakeWireEnt, "Data")
