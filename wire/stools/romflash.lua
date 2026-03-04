WireToolSetup.setCategory("Memory")
WireToolSetup.open( "romflash", "ROM Flasher", "gmod_rom_flasher", nil, "ROM Flasher" )

if ( CLIENT ) then
	language.Add( "Tool.rom_flasher.name", "ROM Flasher" )
	language.Add( "Tool.rom_flasher.desc", "Flashes a ROM file onto a high-speed device" )
	TOOL.Information = {
		{ name = "left", text = "Flash ROM" },
	}
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax( 20 )
TOOL.ClientConVar[ "rom_flasher_rom" ] = "pacman.a26"

function TOOL.BuildCPanel(panel)
	WireToolHelpers.MakePresetControl(panel, "rom_flasher")
	panel:AddControl("Textbox",{ Label = "ROM Name", Command = "rom_flasher_rom" })
end

function TOOL:LeftClick(trace)
	PrintTable(trace)
	if trace.Entity and trace.Entity.WriteCell then
		local data = file.Read("roms/" .. self:GetClientInfo("rom_flasher_rom"), "DATA")
		if not data then error("ROM not found!") end
		
		local size = #data
		for addr = 0, 8192 do
			local i = (addr % size) + 1
			trace.Entity:WriteCell(addr,string.byte(data, i))
			print(string.byte(data,i))
		end
		return true
	end
end

