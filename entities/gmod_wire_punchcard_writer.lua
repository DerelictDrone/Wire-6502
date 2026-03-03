AddCSLuaFile()
DEFINE_BASECLASS( "base_wire_entity" )
ENT.PrintName		= "Wire Punchcard Writer"
ENT.WireDebugName 	= "PunchcardWriter"

local function VectorMax(v1,v2)
	v1:SetUnpacked(math.max(v1.x,v2.x),math.max(v1.y,v2.y),math.max(v1.z,v2.z))
end
local function VectorMin(v1,v2)
	v1:SetUnpacked(math.min(v1.x,v2.x),math.min(v1.y,v2.y),math.min(v1.z,v2.z))
end
local function setupCollision(self)
	self.MinBox = Vector(-5,-5,-5)
	self.MaxBox = Vector(5,5,5)
	local minS,maxS = self:GetCollisionBounds()
	self.TopColliderOffset = Vector(0,0,maxS.z)  -- Centered X and Y coordinates, keeping Z for top of collision box
	self.BottomColliderOffset = Vector(0,0,-maxS.z)
	self.MinBox:Add(self.TopColliderOffset)
	VectorMax(self.MinBox,minS) -- Try to make sure that we won't grab from the bottom by clamping to the original min hitbox
	local originalZ = self.MaxBox.z
	self.MaxBox:Add(self.TopColliderOffset)
	VectorMin(self.MaxBox,maxS) -- Clamp the X and Y to fit the model's dimensions if too big
	self.MaxBox.z = originalZ
end

function ENT:Initialize()
	setupCollision(self)
	-- clientside only far
	self.ViewHitboxes = false
end

local drawOffset = Vector(0,0,0)
-- local small = Vector(1,1,1)
local green = Color(0,255,0,255)
local red = Color(255,0,0,255)
function ENT:Draw()
	self:DrawModel()
	if Punchcard_ShowHitboxes then
		local p = self:GetPos()
		local a = self:GetAngles()
		drawOffset:Set(self.TopColliderOffset)
		drawOffset:Rotate(a)
		local minS,maxS = self:GetCollisionBounds()
		render.DrawWireframeBox(p+drawOffset,a,self.MinBox,self.MaxBox,green)
		drawOffset:Set(self.BottomColliderOffset)
		drawOffset:Rotate(a)
		render.DrawWireframeBox(p+drawOffset,a,self.MaxBox,self.MinBox,red)
		render.DrawWireframeBox(p,a,minS,maxS)
		-- local endpos = self:GetEndPos()
		-- render.DrawWireframeBox(p+endpos,a,-small,small)
		-- render.DrawWireframeBox(p+self.MediaPosition,a,-small,small)
	end
end

if CLIENT then return end -- No more client

function ENT:Initialize()
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self.Inputs = Wire_CreateInputs(self, {"CLK", "Data", "Shift Row"})
	self.Outputs = Wire_CreateOutputs(self, {"Punchcard Inserted", "Currently Shifting"})
	self.HasCard = false
	self.MinBoxTemp = Vector(0,0,0)
	self.MaxBoxTemp = Vector(0,0,0)
	self.MediaMoving = false
	self.MediaPosition = Vector(0,0,0)
	self.MediaPositionTemp = Vector(0,0,0)
	self.MediaOffset = Vector(0,0,0)
	self.MediaTravelDistance = Vector(0,0,0)
	-- self.MediaAngle = Angle(-90,0,0)
	self.MediaAngle = Angle(0,90,90)
	self.MediaAngleTemp = Angle(0,0,0)
	self.MediaDesiredRow = 1
	self.MediaCurrentRow = 1
	self.MediaReversed = false
	setupCollision(self)
	self:CallOnRemove("MediaSaver",self.MediaDisconnect)
end

function ENT:Setup(silent,reversible)
	self.SilentPunching = silent
	self.MediaReversible = reversible
end

local function FindCard(self,ColliderOffset,MinBox,MaxBox)
	local p = self:GetPos()
	local a = self:GetAngles()
	self.MinBoxTemp:Set(MinBox)
	self.MaxBoxTemp:Set(MaxBox)
	self.MinBoxTemp:Rotate(a)
	self.MaxBoxTemp:Rotate(a)
	self.MinBoxTemp:Add(p+ColliderOffset)
	self.MaxBoxTemp:Add(p+ColliderOffset)
	local ents = ents.FindInBox(self.MinBoxTemp,self.MaxBoxTemp)
	local found = false
	for _,ent in ipairs(ents) do
		if ent:GetClass() == "gmod_wire_punchcard" then
			found = ent
			break
		end
	end
	return found
end

function ENT:Think()
	BaseClass.Think(self)
	if not self.HasCard then
		local card = FindCard(self,self.TopColliderOffset,self.MinBox,self.MaxBox)
		local top = true
		if not card and not self.MediaReversible then return end
		top = card and top or false
		card = card or FindCard(self,self.BottomColliderOffset,self.MaxBox,self.MinBox)
		if not card then return end
		self:MediaConnect(card,top)
		return
	end
	if not IsValid(self.DeviceConstraint) then
		self:MediaDisconnect()
		return
	end
	-- Cycling logic
	if self.MediaDesiredRow == self.MediaCurrentRow then
		if self.MediaMoving then
			self:TriggerOutputs("Currently Shifting",0)
			self.MediaMoving = false
		end
		self:NextThink(CurTime()+0.075)
		return true
	end
	if self.MediaDesiredRow < self.MediaCurrentRow then
		self:CycleMedia(-1)
		if not self.MediaMoving then
			self.MediaMoving = true
			self:TriggerOutputs("Currently Shifting",-1)
		end	
	end
	if self.MediaDesiredRow > self.MediaCurrentRow then
		self:CycleMedia(1)
		if not self.MediaMoving then
			self:TriggerOutputs("Currently Shifting",1)
		end
	end
	if self.MediaCurrentRow > self.InsertedCard.Rows or self.MediaCurrentRow < 1 then
		self:MediaDisconnect()
		return true
	end
	self.MediaMoving = true
	self:UpdateMediaPosition(self.MediaOffset)
	self:NextThink(CurTime())
	return true
end

-- Helper function for self, connects a media to this, and informs media it's connected.
function ENT:MediaConnect(media,top)
	if not IsValid(media) then return end
	if media.InDevice then return end
	if media.MediaConnected then
		if not media:MediaConnected(self) then
			return -- media has politely declined being inserted to this device
		end
	end
	self.HasCard = true
	self.InsertedCard = media
	local rows = media.Rows
	if top then
		self.MediaCurrentRow = 1
		self.MediaDesiredRow = 1
	else
		self.MediaCurrentRow = rows
		self.MediaDesiredRow = rows
	end
	local phys = media:GetPhysicsObject()
	local _,maxS = media:GetCollisionBounds()
	self.MediaOffset:SetUnpacked(0,0,0)
	local sminS = self:GetCollisionBounds()
	local tempRotatedCopy = Vector(maxS)
	maxS:Rotate(self.MediaAngle)
	self.MediaPosition:SetUnpacked(0,0,self.TopColliderOffset.z+(tempRotatedCopy.z))
	maxS:Add(self.MediaPosition)
	maxS:Rotate(self.MediaAngle)
	sminS:Add(-maxS)
	self.MediaTravelDistance:SetUnpacked(0,0,sminS.z/(media.Rows))
	if not top then
		self.MediaOffset:Set(self.MediaTravelDistance*(rows))
	end
	self:UpdateMediaPosition(self.MediaOffset)
	-- If inserted at bottom, will give you a -1 to let you know that the punchcard is reversed(so it starts at the end)
	self.MediaReversed = top
	self:TriggerOutputs("Punchcard Inserted",top and 1 or -1)
end

-- Disconnect the media, calls event handler on media if present.
function ENT:MediaDisconnect()
	self.HasCard = false
	if IsValid(self.DeviceConstraint) then
		self.DeviceConstraint:Remove()
	end
	if IsValid(self.InsertedCard) and self.InsertedCard.MediaDisconnected then
		self.InsertedCard:MediaDisconnected(self)
	end
	self.InsertedCard = nil
	self.MediaMoving = false
	self:TriggerOutputs("Punchcard Inserted",0)
	self:TriggerOutputs("Currently Shifting",0)
	self:NextThink(CurTime()+0.25)
end

-- Used by media to allow us to control whether or not to release them
function ENT:MediaGrabbed(media)
	self:MediaDisconnect(media)
	return true
end

function ENT:WeldMedia(recurse)
	if not IsValid(self.DeviceConstraint) or recurse then
		self.DeviceConstraint = constraint.Weld(self.InsertedCard,self,0,0,self.WeldForce or 5000,true)
		self.DeviceConstraint.ConstraintIndex1 = #self.Constraints
		self.DeviceConstraint.ConstraintIndex2 = #self.InsertedCard.Constraints
	else
		if self.DeviceConstraint == false then
			self.DeviceConstraint = nil
			return self:WeldMedia(true)
		end
		table.remove(self.Constraints,self.DeviceConstraint.ConstraintIndex1)
		table.remove(self.InsertedCard.Constraints,self.DeviceConstraint.ConstraintIndex2)
		self.DeviceConstraint:Remove()
		return self:WeldMedia(true)
	end
	self.InsertedCard:PhysWake()
end

-- Updates position of the object w/ offset(rotated for you), rewelds, and returns the pos
function ENT:UpdateMediaPosition(offset)
	self.MediaPositionTemp:Set(self.MediaPosition)
	self.MediaPositionTemp:Add(offset or Vector(0,0,0))
	self.MediaPositionTemp:Rotate(self:GetAngles())
	self.MediaPositionTemp:Add(self:GetPos())
	self.InsertedCard:SetPos(self.MediaPositionTemp)
	self.InsertedCard:SetAngles(self:GetMediaAngle())
	self:WeldMedia()
	self:NextThink(CurTime())
	return self.MediaPositionTemp
end

function ENT:GetMediaAngle()
	return self:LocalToWorldAngles(self.MediaAngle)
end

function ENT:CycleMedia(amt)
	self.MediaCurrentRow = self.MediaCurrentRow + amt
	self.MediaOffset:Add(self.MediaTravelDistance*amt)
end

function ENT:ReadCell(Address)
	if Address < 0 or Address > 3 then return false end
	if Address == 0 then
		if not self.HasCard then return 0 end
		if self.MediaCurrentRow == self.MediaDesiredRow then
			return 0
		end
		if self.MediaCurrentRow < self.MediaDesiredRow then
			return 1
		end
		if self.MediaCurrentRow > self.MediaDesiredRow then
			return -1
		end
	end
	if Address == 1 then
		if not self.HasCard then return 0 end
		return self.MediaReversed and -1 or 1
	end
	if Address == 2 then
		-- No use in clamping this now, I'll let them use it as a scratch register if they need to.
		return self.MediaWriteValue or 0
	end
	return false -- User most likely input a floating point address. Bad user.
end

function ENT:WriteCell(Address, value)
	if Address < 0 or Address > 2 then
		return false
	end
	if Address == 0 then
		-- Card will eject as soon as it hits 0 or number of rows+1 so no need to clamp right now.
		self.MediaDesiredRow = self.MediaDesiredRow + math.floor(value)
		return true
	end
	if Address == 1 then
		if self.HasCard then
			-- write directly to punch card at current row
			-- if the user instructs it to punch too early, skill issue.
			self.InsertedCard:PunchRow(self.MediaWriteValue,self.MediaCurrentRow,self.SilentPunching)
			return true
		else
			return false
		end
	end
	if Address == 2 then
		self.MediaWriteValue = value
		return true
	end
	return false -- User most likely input a floating point address. Bad user.
end

function ENT:TriggerInput(iname, value)
	if iname == "Shift Row" and value ~= 0 then
		self:WriteCell(0,value)
		return
	end
	if iname == "CLK" and value ~= 0 then
		self:WriteCell(1,value)
		return
	end
	if iname == "Data" then
		self:WriteCell(2,value)
	end
end

function ENT:TriggerOutputs(oname,value)
	if oname == "Currently Shifting" then
		WireLib.TriggerOutput(self, "Currently Shifting", value)
	end
	if oname == "Punchcard Inserted" then
		WireLib.TriggerOutput(self, "Punchcard Inserted", value)
	end
end

function ENT:BuildDupeInfo()
	local info = BaseClass.BuildDupeInfo(self) or {}
	return info
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)
end


duplicator.RegisterEntityClass("gmod_wire_punchcard_writer", WireLib.MakeWireEnt, "Data")
