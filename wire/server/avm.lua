AVM = AVM or {}
AVM.__index = AVM

local bor = bit.bor
local band = bit.band
local bxor = bit.bxor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local floor = math.floor

local CF = 1 -- carry
local ZF = 2 -- zero
local IF = 4 -- irq
local DF = 8 -- decimal
local BF = 16 -- break
local UF = 32 -- unused
local OF = 64 -- overflow
local NF = 128 -- negative

function AVM:SetFlag(flag, state)
    if state then
        self.ps = bor(self.ps, flag)
    else
        self.ps = band(self.ps, bnot(flag))
    end
end

function AVM:GetFlag(flag)
    return (band(self.ps, flag) ~= 0) and 1 or 0
end

function AVM:To4(n)
    return bxor(band(n, 0xF), 0x8) - 0x8
end

function AVM:To8(value)
    return band(value, 0xFF)
end

function AVM:To16(value)
    return band(value, 0xFFFF)
end

function AVM:Pack16(low, high)
    return bor(lshift(high, 8), low)
end

function AVM:AddPC(value)
    self.pc = self:To16(self.pc + value)
end

function AVM:MRead8(index)
    index = self:To16(index)
    return self:To8(self.DeviceRead(self.Entity,index))
    -- if index == 0x1FF8 then
    --     self.bank = 0
    -- elseif index == 0x1FF9 then
    --     self.bank = 1
    -- end

end

function AVM:MRead16(index)
    index = self:To16(index)
    return self:Pack16(self:MRead8(index), self:MRead8(self:To16(index + 1)))
end

function AVM:MWrite8(index, value)
    index = self:To16(index)

    self.DeviceWrite(self.Entity,index,value)
    -- if index == 0x1FF8 then
    --     self.bank = 0
    -- elseif index == 0x1FF9 then
    --     self.bank = 1
    -- end

    -- if index >= 0xF000 then
    --     return
    -- elseif index >= 0x0280 and index < 0x0298 then
    --     self:RIOTWrite(index, self:To8(value))
    -- elseif index < 0x40 then
    --     self:TIAWrite(index, self:To8(value))
    -- else
    --     self.ram[index] = self:To8(value)
    -- end
end

function AVM:Fetch8()
    local n = self:MRead8(self.pc)
    self:AddPC(1)
    return n
end

function AVM:Fetch16()
    local lo = self:Fetch8()
    local hi = self:Fetch8()
    return self:Pack16(lo, hi)
end

function AVM:Push8(value)
    self:MWrite8(0x0100 + self.sp, value)
    self.sp = self:To8(self.sp - 1)
end

function AVM:Pop8()
    self.sp = self:To8(self.sp + 1)
    return self:MRead8(0x0100 + self.sp)
end

function AVM:IMM()
    return self:Fetch8()
end

function AVM:ZP()
    return self:MRead8(self:Fetch8())
end

function AVM:ZPX()
    return self:MRead8(self:To8(self:Fetch8() + self.x))
end

function AVM:ZPY()
    return self:MRead8(self:To8(self:Fetch8() + self.y))
end

function AVM:ABS()
    return self:MRead8(self:Fetch16())
end

function AVM:ABSX()
    local base = self:Fetch16()
    local addr = self:To16(base + self.x)
    if band(base, 0xFF00) ~= band(addr, 0xFF00) then
        self.extraCycles = 1
    end
    return self:MRead8(addr)
end

function AVM:ABSY()
    local base = self:Fetch16()
    local addr = self:To16(base + self.y)
    if band(base, 0xFF00) ~= band(addr, 0xFF00) then
        self.extraCycles = 1
    end
    return self:MRead8(addr)
end

function AVM:INDY()
    local zp = self:Fetch8()
    local base = self:Pack16(self:MRead8(zp), self:MRead8(self:To8(zp + 1)))
    local addr = self:To16(base + self.y)
    if band(base, 0xFF00) ~= band(addr, 0xFF00) then
        self.extraCycles = 1
    end
    return self:MRead8(addr)
end

function AVM:ZPA()
    return self:Fetch8()
end

function AVM:ZPXA()
    return self:To8(self:Fetch8() + self.x)
end

function AVM:ZPYA()
    return self:To8(self:Fetch8() + self.y)
end

function AVM:ABSA()
    return self:Fetch16()
end

function AVM:ABSXA()
    return self:To16(self:Fetch16() + self.x)
end

function AVM:ABSYA()
    return self:To16(self:Fetch16() + self.y)
end

function AVM:INDX()
    local zp = self:To8(self:Fetch8() + self.x)
    return self:MRead8(self:Pack16(self:MRead8(zp), self:MRead8(self:To8(zp + 1))))
end

function AVM:INDXA()
    local zp = self:To8(self:Fetch8() + self.x)
    return self:Pack16(self:MRead8(zp), self:MRead8(self:To8(zp + 1)))
end

function AVM:INDYA()
    local zp = self:Fetch8()
    return self:To16(self:Pack16(self:MRead8(zp), self:MRead8(self:To8(zp + 1))) + self.y)
end

function AVM:Branch(condition)
    local o = self:Fetch8()
    if o >= 0x80 then o = o - 0x100 end
    if not condition then return end

    local oldPC = self.pc
    self.pc = self:To16(self.pc + o)

    if band(oldPC, 0xFF00) ~= band(self.pc, 0xFF00) then
        self.extraCycles = 2
    else
        self.extraCycles = 1
    end
end

function AVM:NOP()
end

function AVM:CLC()
    self:SetFlag(CF, false)
end

function AVM:SEC()
    self:SetFlag(CF, true)
end

function AVM:CLI()
    self:SetFlag(IF, false)
end

function AVM:SEI()
    self:SetFlag(IF, true)
end

function AVM:CLV()
    self:SetFlag(OF, false)
end

function AVM:CLD()
    self:SetFlag(DF, false)
end

function AVM:SED()
    self:SetFlag(DF, true)
end

function AVM:TAX()
    self.x = self:To8(self.a)
    self:SetFlag(ZF, self.x == 0)
    self:SetFlag(NF, band(self.x, 0x80) ~= 0)
end

function AVM:TAY()
    self.y = self:To8(self.a)
    self:SetFlag(ZF, self.y == 0)
    self:SetFlag(NF, band(self.y, 0x80) ~= 0)
end

function AVM:TSX()
    self.x = self:To8(self.sp)
    self:SetFlag(ZF, self.x == 0)
    self:SetFlag(NF, band(self.x, 0x80) ~= 0)
end

function AVM:TXA()
    self.a = self:To8(self.x)
    self:SetFlag(ZF, self.a == 0)
    self:SetFlag(NF, band(self.a, 0x80) ~= 0)
end

function AVM:TXS()
    self.sp = self:To8(self.x)
end

function AVM:TYA()
    self.a = self:To8(self.y)
    self:SetFlag(ZF, self.a == 0)
    self:SetFlag(NF, band(self.a, 0x80) ~= 0)
end

function AVM:LDA(value)
    self.a = self:To8(value)
    self:SetFlag(ZF, self.a == 0)
    self:SetFlag(NF, band(self.a, 0x80) ~= 0)
end

function AVM:LDX(value)
    self.x = self:To8(value)
    self:SetFlag(ZF, self.x == 0)
    self:SetFlag(NF, band(self.x, 0x80) ~= 0)
end

function AVM:LDY(value)
    self.y = self:To8(value)
    self:SetFlag(ZF, self.y == 0)
    self:SetFlag(NF, band(self.y, 0x80) ~= 0)
end

function AVM:STA(addr)
    self:MWrite8(addr, self.a)
end

function AVM:STX(addr)
    self:MWrite8(addr, self.x)
end

function AVM:STY(addr)
    self:MWrite8(addr, self.y)
end

function AVM:ADC(value)
    local full = value + self.a + self:GetFlag(CF)
    local sum = self:To8(full)
    self:SetFlag(CF, full > 0xFF)
    self:SetFlag(ZF, sum == 0)
    self:SetFlag(NF, band(sum, 0x80) ~= 0)
    self:SetFlag(OF, band(band(bxor(value, sum), bxor(self.a, sum)), 0x80) ~= 0)
    self.a = sum
end

function AVM:SBC(value)
    local borrow = 1 - self:GetFlag(CF)
    local full = self.a - value - borrow
    local res = self:To8(full)
    self:SetFlag(CF, full >= 0)
    self:SetFlag(ZF, res == 0)
    self:SetFlag(NF, band(res, 0x80) ~= 0)
    self:SetFlag(OF, band(band(bxor(self.a, res), bxor(self.a, value)), 0x80) ~= 0)
    self.a = res
end

function AVM:AND(value)
    self.a = self:To8(band(self.a, self:To8(value)))
    self:SetFlag(ZF, self.a == 0)
    self:SetFlag(NF, band(self.a, 0x80) ~= 0)
end

function AVM:ORA(value)
    self.a = self:To8(bor(self.a, self:To8(value)))
    self:SetFlag(ZF, self.a == 0)
    self:SetFlag(NF, band(self.a, 0x80) ~= 0)
end

function AVM:EOR(value)
    self.a = self:To8(bxor(self.a, self:To8(value)))
    self:SetFlag(ZF, self.a == 0)
    self:SetFlag(NF, band(self.a, 0x80) ~= 0)
end

function AVM:BIT(value)
    self:SetFlag(ZF, band(self.a, value) == 0)
    self:SetFlag(NF, band(value, 0x80) ~= 0)
    self:SetFlag(OF, band(value, 0x40) ~= 0)
end

function AVM:CMP(value)
    local res = self:To8(self.a - value)
    self:SetFlag(CF, self.a >= value)
    self:SetFlag(ZF, res == 0)
    self:SetFlag(NF, band(res, 0x80) ~= 0)
end

function AVM:CPX(value)
    local res = self:To8(self.x - value)
    self:SetFlag(CF, self.x >= value)
    self:SetFlag(ZF, res == 0)
    self:SetFlag(NF, band(res, 0x80) ~= 0)
end

function AVM:CPY(value)
    local res = self:To8(self.y - value)
    self:SetFlag(CF, self.y >= value)
    self:SetFlag(ZF, res == 0)
    self:SetFlag(NF, band(res, 0x80) ~= 0)
end

function AVM:INX()
    self.x = self:To8(self.x + 1)
    self:SetFlag(ZF, self.x == 0)
    self:SetFlag(NF, band(self.x, 0x80) ~= 0)
end

function AVM:INY()
    self.y = self:To8(self.y + 1)
    self:SetFlag(ZF, self.y == 0)
    self:SetFlag(NF, band(self.y, 0x80) ~= 0)
end

function AVM:DEX()
    self.x = self:To8(self.x - 1)
    self:SetFlag(ZF, self.x == 0)
    self:SetFlag(NF, band(self.x, 0x80) ~= 0)
end

function AVM:DEY()
    self.y = self:To8(self.y - 1)
    self:SetFlag(ZF, self.y == 0)
    self:SetFlag(NF, band(self.y, 0x80) ~= 0)
end

function AVM:INC(addr)
    local value = self:To8(self:MRead8(addr) + 1)
    self:MWrite8(addr, value)
    self:SetFlag(ZF, value == 0)
    self:SetFlag(NF, band(value, 0x80) ~= 0)
end

function AVM:DEC(addr)
    local value = self:To8(self:MRead8(addr) - 1)
    self:MWrite8(addr, value)
    self:SetFlag(ZF, value == 0)
    self:SetFlag(NF, band(value, 0x80) ~= 0)
end

function AVM:ASL(addr)
    if not addr then
        self:SetFlag(CF, band(self.a, 0x80) ~= 0)
        self.a = self:To8(lshift(self.a, 1))
        self:SetFlag(ZF, self.a == 0)
        self:SetFlag(NF, band(self.a, 0x80) ~= 0)
        return
    end
    local value = self:MRead8(addr)
    self:SetFlag(CF, band(value, 0x80) ~= 0)
    value = self:To8(lshift(value, 1))
    self:MWrite8(addr, value)
    self:SetFlag(ZF, value == 0)
    self:SetFlag(NF, band(value, 0x80) ~= 0)
end

function AVM:LSR(addr)
    if not addr then
        self:SetFlag(CF, band(self.a, 0x01) ~= 0)
        self.a = self:To8(rshift(self.a, 1))
        self:SetFlag(ZF, self.a == 0)
        self:SetFlag(NF, 0)
        return
    end
    local value = self:MRead8(addr)
    self:SetFlag(CF, band(value, 0x01) ~= 0)
    value = self:To8(rshift(value, 1))
    self:MWrite8(addr, value)
    self:SetFlag(ZF, value == 0)
    self:SetFlag(NF, false)
end

function AVM:ROL(addr)
    if not addr then
        local c = self:GetFlag(CF)
        self:SetFlag(CF, band(self.a, 0x80) ~= 0)
        self.a = self:To8(bor(lshift(self.a, 1), c))
        self:SetFlag(ZF, self.a == 0)
        self:SetFlag(NF, band(self.a, 0x80) ~= 0)
        return
    end
    local value = self:MRead8(addr)
    local c = self:GetFlag(CF)
    self:SetFlag(CF, band(value, 0x80) ~= 0)
    value = self:To8(bor(lshift(value, 1), c))
    self:MWrite8(addr, value)
    self:SetFlag(ZF, value == 0)
    self:SetFlag(NF, band(value, 0x80) ~= 0)
end

function AVM:ROR(addr)
    if not addr then
        local c = self:GetFlag(CF)
        self:SetFlag(CF, band(self.a, 0x01) ~= 0)
        self.a = self:To8(bor(rshift(self.a, 1), lshift(c, 7)))
        self:SetFlag(ZF, self.a == 0)
        self:SetFlag(NF, band(self.a, 0x80) ~= 0)
        return
    end
    local value = self:MRead8(addr)
    local c = self:GetFlag(CF)
    self:SetFlag(CF, band(value, 0x01) ~= 0)
    value = self:To8(bor(rshift(value, 1), lshift(c, 7)))
    self:MWrite8(addr, value)
    self:SetFlag(ZF, value == 0)
    self:SetFlag(NF, band(value, 0x80) ~= 0)
end

function AVM:JMP()
    self.pc = self:Fetch16()
end

function AVM:JMPIND()
    local ptr = self:Fetch16()
    local lo = self:MRead8(ptr)
    local hi = self:MRead8(bor(band(ptr, 0xFF00), self:To8(ptr + 1)))
    self.pc = self:Pack16(lo, hi)
end

function AVM:JSR()
    local addr = self:Fetch16()
    local ret = self:To16(self.pc - 1)
    self:Push8(rshift(ret, 8))
    self:Push8(band(ret, 0xFF))
    self.pc = addr
end

function AVM:RTS()
    local lo = self:Pop8()
    local hi = self:Pop8()
    self.pc = self:To16(self:Pack16(lo, hi) + 1)
end

function AVM:RTI()
    self.ps = self:To8(bor(self:Pop8(), UF))
    self.ps = band(self.ps, bnot(BF))
    local lo = self:Pop8()
    local hi = self:Pop8()
    self.pc = self:Pack16(lo, hi)
end

function AVM:PHA()
    self:Push8(self.a)
end

function AVM:PHP()
    self:Push8(bor(self.ps, BF, UF))
end

function AVM:PLA()
    self.a = self:To8(self:Pop8())
    self:SetFlag(ZF, self.a == 0)
    self:SetFlag(NF, band(self.a, 0x80) ~= 0)
end

function AVM:PLP()
    self.ps = self:To8(bor(self:Pop8(), UF))
    self.ps = band(self.ps, bnot(BF))
end

function AVM:BRK()
    self:Fetch8()
    self:Push8(rshift(self.pc, 8))
    self:Push8(band(self.pc, 0xFF))
    self:Push8(bor(self.ps, BF, UF))
    self:SetFlag(IF, true)
    self.pc = self:MRead16(0xFFFE)
end

function AVM:BPL() self:Branch(self:GetFlag(NF) == 0) end
function AVM:BMI() self:Branch(self:GetFlag(NF) == 1) end
function AVM:BVC() self:Branch(self:GetFlag(OF) == 0) end
function AVM:BVS() self:Branch(self:GetFlag(OF) == 1) end
function AVM:BCC() self:Branch(self:GetFlag(CF) == 0) end
function AVM:BCS() self:Branch(self:GetFlag(CF) == 1) end
function AVM:BNE() self:Branch(self:GetFlag(ZF) == 0) end
function AVM:BEQ() self:Branch(self:GetFlag(ZF) == 1) end

AVM.Opcodes = {
    [0x00] = function(self) self:BRK() return 7 end,
    [0x01] = function(self) self:ORA(self:INDX()) return 6 end,
    [0x05] = function(self) self:ORA(self:ZP()) return 3 end,
    [0x06] = function(self) self:ASL(self:ZPA()) return 5 end,
    [0x08] = function(self) self:PHP() return 3 end,
    [0x09] = function(self) self:ORA(self:IMM()) return 2 end,
    [0x0A] = function(self) self:ASL() return 2 end,
    [0x0D] = function(self) self:ORA(self:ABS()) return 4 end,
    [0x0E] = function(self) self:ASL(self:ABSA()) return 6 end,

    [0x10] = function(self) self:BPL() return 2 end,
    [0x11] = function(self) self:ORA(self:INDY()) return 5 end,
    [0x15] = function(self) self:ORA(self:ZPX()) return 4 end,
    [0x16] = function(self) self:ASL(self:ZPXA()) return 6 end,
    [0x18] = function(self) self:CLC() return 2 end,
    [0x19] = function(self) self:ORA(self:ABSY()) return 4 end,
    [0x1D] = function(self) self:ORA(self:ABSX()) return 4 end,
    [0x1E] = function(self) self:ASL(self:ABSXA()) return 7 end,

    [0x20] = function(self) self:JSR() return 6 end,
    [0x21] = function(self) self:AND(self:INDX()) return 6 end,
    [0x24] = function(self) self:BIT(self:ZP()) return 3 end,
    [0x25] = function(self) self:AND(self:ZP()) return 3 end,
    [0x26] = function(self) self:ROL(self:ZPA()) return 5 end,
    [0x28] = function(self) self:PLP() return 4 end,
    [0x29] = function(self) self:AND(self:IMM()) return 2 end,
    [0x2A] = function(self) self:ROL() return 2 end,
    [0x2C] = function(self) self:BIT(self:ABS()) return 4 end,
    [0x2D] = function(self) self:AND(self:ABS()) return 4 end,
    [0x2E] = function(self) self:ROL(self:ABSA()) return 6 end,

    [0x30] = function(self) self:BMI() return 2 end,
    [0x31] = function(self) self:AND(self:INDY()) return 5 end,
    [0x35] = function(self) self:AND(self:ZPX()) return 4 end,
    [0x36] = function(self) self:ROL(self:ZPXA()) return 6 end,
    [0x38] = function(self) self:SEC() return 2 end,
    [0x39] = function(self) self:AND(self:ABSY()) return 4 end,
    [0x3D] = function(self) self:AND(self:ABSX()) return 4 end,
    [0x3E] = function(self) self:ROL(self:ABSXA()) return 7 end,

    [0x40] = function(self) self:RTI() return 6 end,
    [0x41] = function(self) self:EOR(self:INDX()) return 6 end,
    [0x45] = function(self) self:EOR(self:ZP()) return 3 end,
    [0x46] = function(self) self:LSR(self:ZPA()) return 5 end,
    [0x48] = function(self) self:PHA() return 3 end,
    [0x49] = function(self) self:EOR(self:IMM()) return 2 end,
    [0x4A] = function(self) self:LSR() return 2 end,
    [0x4C] = function(self) self:JMP() return 3 end,
    [0x4D] = function(self) self:EOR(self:ABS()) return 4 end,
    [0x4E] = function(self) self:LSR(self:ABSA()) return 6 end,

    [0x50] = function(self) self:BVC() return 2 end,
    [0x51] = function(self) self:EOR(self:INDY()) return 5 end,
    [0x55] = function(self) self:EOR(self:ZPX()) return 4 end,
    [0x56] = function(self) self:LSR(self:ZPXA()) return 6 end,
    [0x58] = function(self) self:CLI() return 2 end,
    [0x59] = function(self) self:EOR(self:ABSY()) return 4 end,
    [0x5D] = function(self) self:EOR(self:ABSX()) return 4 end,
    [0x5E] = function(self) self:LSR(self:ABSXA()) return 7 end,

    [0x60] = function(self) self:RTS() return 6 end,
    [0x61] = function(self) self:ADC(self:INDX()) return 6 end,
    [0x65] = function(self) self:ADC(self:ZP()) return 3 end,
    [0x66] = function(self) self:ROR(self:ZPA()) return 5 end,
    [0x68] = function(self) self:PLA() return 4 end,
    [0x69] = function(self) self:ADC(self:IMM()) return 2 end,
    [0x6A] = function(self) self:ROR() return 2 end,
    [0x6C] = function(self) self:JMPIND() return 5 end,
    [0x6D] = function(self) self:ADC(self:ABS()) return 4 end,
    [0x6E] = function(self) self:ROR(self:ABSA()) return 6 end,

    [0x70] = function(self) self:BVS() return 2 end,
    [0x71] = function(self) self:ADC(self:INDY()) return 5 end,
    [0x75] = function(self) self:ADC(self:ZPX()) return 4 end,
    [0x76] = function(self) self:ROR(self:ZPXA()) return 6 end,
    [0x78] = function(self) self:SEI() return 2 end,
    [0x79] = function(self) self:ADC(self:ABSY()) return 4 end,
    [0x7D] = function(self) self:ADC(self:ABSX()) return 4 end,
    [0x7E] = function(self) self:ROR(self:ABSXA()) return 7 end,

    [0x81] = function(self) self:STA(self:INDXA()) return 6 end,
    [0x84] = function(self) self:STY(self:ZPA()) return 3 end,
    [0x85] = function(self) self:STA(self:ZPA()) return 3 end,
    [0x86] = function(self) self:STX(self:ZPA()) return 3 end,
    [0x88] = function(self) self:DEY() return 2 end,
    [0x8A] = function(self) self:TXA() return 2 end,
    [0x8C] = function(self) self:STY(self:ABSA()) return 4 end,
    [0x8D] = function(self) self:STA(self:ABSA()) return 4 end,
    [0x8E] = function(self) self:STX(self:ABSA()) return 4 end,

    [0x90] = function(self) self:BCC() return 2 end,
    [0x91] = function(self) self:STA(self:INDYA()) return 6 end,
    [0x94] = function(self) self:STY(self:ZPXA()) return 4 end,
    [0x95] = function(self) self:STA(self:ZPXA()) return 4 end,
    [0x96] = function(self) self:STX(self:ZPYA()) return 4 end,
    [0x98] = function(self) self:TYA() return 2 end,
    [0x99] = function(self) self:STA(self:ABSYA()) return 5 end,
    [0x9A] = function(self) self:TXS() return 2 end,
    [0x9D] = function(self) self:STA(self:ABSXA()) return 5 end,

    [0xA0] = function(self) self:LDY(self:IMM()) return 2 end,
    [0xA1] = function(self) self:LDA(self:INDX()) return 6 end,
    [0xA2] = function(self) self:LDX(self:IMM()) return 2 end,
    [0xA4] = function(self) self:LDY(self:ZP()) return 3 end,
    [0xA5] = function(self) self:LDA(self:ZP()) return 3 end,
    [0xA6] = function(self) self:LDX(self:ZP()) return 3 end,
    [0xA8] = function(self) self:TAY() return 2 end,
    [0xA9] = function(self) self:LDA(self:IMM()) return 2 end,
    [0xAA] = function(self) self:TAX() return 2 end,
    [0xAC] = function(self) self:LDY(self:ABS()) return 4 end,
    [0xAD] = function(self) self:LDA(self:ABS()) return 4 end,
    [0xAE] = function(self) self:LDX(self:ABS()) return 4 end,

    [0xB0] = function(self) self:BCS() return 2 end,
    [0xB1] = function(self) self:LDA(self:INDY()) return 5 end,
    [0xB4] = function(self) self:LDY(self:ZPX()) return 4 end,
    [0xB5] = function(self) self:LDA(self:ZPX()) return 4 end,
    [0xB6] = function(self) self:LDX(self:ZPY()) return 4 end,
    [0xB8] = function(self) self:CLV() return 2 end,
    [0xB9] = function(self) self:LDA(self:ABSY()) return 4 end,
    [0xBA] = function(self) self:TSX() return 2 end,
    [0xBC] = function(self) self:LDY(self:ABSX()) return 4 end,
    [0xBD] = function(self) self:LDA(self:ABSX()) return 4 end,
    [0xBE] = function(self) self:LDX(self:ABSY()) return 4 end,

    [0xC0] = function(self) self:CPY(self:IMM()) return 2 end,
    [0xC1] = function(self) self:CMP(self:INDX()) return 6 end,
    [0xC4] = function(self) self:CPY(self:ZP()) return 3 end,
    [0xC5] = function(self) self:CMP(self:ZP()) return 3 end,
    [0xC6] = function(self) self:DEC(self:ZPA()) return 5 end,
    [0xC8] = function(self) self:INY() return 2 end,
    [0xC9] = function(self) self:CMP(self:IMM()) return 2 end,
    [0xCA] = function(self) self:DEX() return 2 end,
    [0xCC] = function(self) self:CPY(self:ABS()) return 4 end,
    [0xCD] = function(self) self:CMP(self:ABS()) return 4 end,
    [0xCE] = function(self) self:DEC(self:ABSA()) return 6 end,

    [0xD0] = function(self) self:BNE() return 2 end,
    [0xD1] = function(self) self:CMP(self:INDY()) return 5 end,
    [0xD5] = function(self) self:CMP(self:ZPX()) return 4 end,
    [0xD6] = function(self) self:DEC(self:ZPXA()) return 6 end,
    [0xD8] = function(self) self:CLD() return 2 end,
    [0xD9] = function(self) self:CMP(self:ABSY()) return 4 end,
    [0xDD] = function(self) self:CMP(self:ABSX()) return 4 end,
    [0xDE] = function(self) self:DEC(self:ABSXA()) return 7 end,

    [0xE0] = function(self) self:CPX(self:IMM()) return 2 end,
    [0xE1] = function(self) self:SBC(self:INDX()) return 6 end,
    [0xE4] = function(self) self:CPX(self:ZP()) return 3 end,
    [0xE5] = function(self) self:SBC(self:ZP()) return 3 end,
    [0xE6] = function(self) self:INC(self:ZPA()) return 5 end,
    [0xE8] = function(self) self:INX() return 2 end,
    [0xE9] = function(self) self:SBC(self:IMM()) return 2 end,
    [0xEA] = function(self) self:NOP() return 2 end,
    [0xEC] = function(self) self:CPX(self:ABS()) return 4 end,
    [0xED] = function(self) self:SBC(self:ABS()) return 4 end,
    [0xEE] = function(self) self:INC(self:ABSA()) return 6 end,

    [0xF0] = function(self) self:BEQ() return 2 end,
    [0xF1] = function(self) self:SBC(self:INDY()) return 5 end,
    [0xF5] = function(self) self:SBC(self:ZPX()) return 4 end,
    [0xF6] = function(self) self:INC(self:ZPXA()) return 6 end,
    [0xF8] = function(self) self:SED() return 2 end,
    [0xF9] = function(self) self:SBC(self:ABSY()) return 4 end,
    [0xFD] = function(self) self:SBC(self:ABSX()) return 4 end,
    [0xFE] = function(self) self:INC(self:ABSXA()) return 7 end,
}

function AVM:Reset()
    self.a  = 0
    self.x  = 0
    self.y  = 0
    self.ps = bor(IF, UF)
    self.sp = 0xFD
    self.pc = self:MRead16(0xFFFC)
    self.cycles = 0
    self.extraCycles = 0



    self.riotTimer = 0
    self.riotDivider = 1
    self.riotCyclesLeft = 0
    self.riotInterrupt = false

    for i=0, 160 * 192 do
        self.frameBuffer[i] = 0
    end

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

function AVM:Step()
    local opcode = self:Fetch8()
    local instruction = self.Opcodes[opcode]
    if not instruction then
        print(string.format("Unknown opcode %02X at %04X", opcode, self.pc - 1))
        return
    end
    
    local cycles = instruction(self) + self.extraCycles
    self.extraCycles = 0
    self.cycles = self.cycles + cycles
end

function AVM:State()
    print(string.format(
        "PC:%04X A: %02X X:%02X Y:%02X SP:%02X PS:%02X OP:%02X",
        self.pc,
        self.a,
        self.x,
        self.y,
        self.sp,
        self.ps,
        self:MRead8(self.pc)
    ))
end

function AVM:LoadROM(rom)
    local data = file.Read("roms/" .. rom, "DATA")
    if not data then error("ROM not found!") end

    local size = #data
    for addr = 0, 8192 do
        local i = (addr % size) + 1
        self.rom[addr] = string.byte(data, i)
    end

    self:Reset()

    print("Loaded rom: " .. rom)
end

-- external



function AVM:TIARead(index)
    if index == 0x0C then
        -- return IsKeyDown(KEY_SPACE) and 0x00 or 0x80
    end

    if index == 0x0D then
        -- return IsKeyDown(KEY_RCONTROL) and 0x00 or 0x80
    end
    return 0x80
end

function AVM:TIAWrite(index, value)
    if index == 0x00 then
        self.vsync = value
        if band(value, 0x02) ~= 0 then
            self.scanline = 0
        end
    elseif index == 0x01 then self.vblank = value
    elseif index == 0x02 then
        local cycles = self.cycles % 76
        self.cycles = self.cycles + (76 - cycles)
        self:RenderScanline()
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

function AVM:RenderScanline()
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

local blshift = bit.lshift

AVM.New = function(AddressRemaps,ZeroPageMask)
    local vm = setmetatable({
        cycles = 0,
        extraCycles = 0,
        pc = 0,
        sp = 0,
        a = 0,
        x = 0,
        y = 0,
        ps = bor(IF, UF),
        bank = 0,
        ZERO_PAGE_MASK = ZeroPageMask,
        frameBuffer = {},
        scanline = 0,
        colubk = 0,
        colupf = 0,
        colup0 = 0,
        colup1 = 0,
        vsync  = 0,
        vblank = 0,
        pf0 = 0,
        pf1 = 0,
        pf2 = 0,
        grp0 = 0,
        grp1 = 0,
        resp0 = 0,
        resp1 = 0,
        hmp0 = 0,
        hmp1 = 0,
        ctrlpf = 0,
        AddressCache = {}
    }, AVM)

    for i=0, 160 * 192 do
        vm.frameBuffer[i] = 0
    end
    local one,zero = 1,0
    for i=1,4 do
        local curCache = {}
        vm.AddressCache[i] = curCache
        local currentRemap = AddressRemaps[i]
        for i=0,65535 do
            local b0 = band(i,1) and one or zero
            local b1 = band(i,2) and one or zero
            local b2 = band(i,4) and one or zero
            local b3 = band(i,8) and one or zero
            local b4 = band(i,16) and one or zero
            local b5 = band(i,32) and one or zero
            local b6 = band(i,64) and one or zero
            local b7 = band(i,128) and one or zero
            local b8 = band(i,256) and one or zero
            local b9 = band(i,512) and one or zero
            local b10 = band(i,1024) and one or zero
            local b11 = band(i,2048) and one or zero
            local b12 = band(i,4096) and one or zero
            local b13 = band(i,8192) and one or zero
            local b14 = band(i,16384) and one or zero
            local b15 = band(i,32768) and one or zero
            local t = {b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b11,b12,b13,b14,b15}
            local curd = 0
            curd = bor(curd,t[currentRemap[1] or zero] or zero)
            curd = bor(curd,blshift(t[currentRemap[2] ~= -1 and currentRemap[2] or zero] or zero,01))
            curd = bor(curd,blshift(t[currentRemap[3] ~= -1 and currentRemap[3] or zero] or zero,02))
            curd = bor(curd,blshift(t[currentRemap[4] ~= -1 and currentRemap[4] or zero] or zero,03))
            curd = bor(curd,blshift(t[currentRemap[5] ~= -1 and currentRemap[5] or zero] or zero,04))
            curd = bor(curd,blshift(t[currentRemap[6] ~= -1 and currentRemap[6] or zero] or zero,05))
            curd = bor(curd,blshift(t[currentRemap[7] ~= -1 and currentRemap[7] or zero] or zero,06))
            curd = bor(curd,blshift(t[currentRemap[8] ~= -1 and currentRemap[8] or zero] or zero,07))
            curd = bor(curd,blshift(t[currentRemap[9] ~= -1 and currentRemap[9] or zero] or zero,08))
            curd = bor(curd,blshift(t[currentRemap[10] ~= -1 and currentRemap[10] or zero] or zero,09))
            curd = bor(curd,blshift(t[currentRemap[11] ~= -1 and currentRemap[11] or zero] or zero,10))
            curd = bor(curd,blshift(t[currentRemap[12] ~= -1 and currentRemap[12] or zero] or zero,11))
            curd = bor(curd,blshift(t[currentRemap[13] ~= -1 and currentRemap[13] or zero] or zero,12))
            curd = bor(curd,blshift(t[currentRemap[14] ~= -1 and currentRemap[14] or zero] or zero,13))
            curd = bor(curd,blshift(t[currentRemap[15] ~= -1 and currentRemap[15] or zero] or zero,14))
            curd = bor(curd,blshift(t[currentRemap[16] ~= -1 and currentRemap[16] or zero] or zero,15))
            curCache[i] = curd
        end
    end
    return vm
end

-- vm:LoadROM("pacman.a26")

-- local SetDrawColor = surface.SetDrawColor
-- local DrawRect = surface.DrawRect
-- local fb = vm.frameBuffer

-- hook.Add("HUDPaint", "tia_draw", function()
--     for y = 0, 191 do
--         local base = y * 160
--         local x = 0
--         while x < 160 do
--             local color = fb[base + x]
--             local runEnd = x + 1
--             while runEnd < 160 and fb[base + runEnd] == color do
--                 runEnd = runEnd + 1
--             end
--             SetDrawColor(NTSC[rshift(band(color, 0xFE), 1) + 1])
--             DrawRect(x * 4, y * 2, (runEnd - x) * 4, 2)
--             x = runEnd
--         end
--     end
-- end)