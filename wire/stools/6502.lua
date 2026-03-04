WireToolSetup.setCategory("Chips, Gates")
WireToolSetup.open( "6502", "6502 CPU", "gmod_wire_6502", nil, "6502 CPUs" )

if ( CLIENT ) then
	language.Add( "Tool.wire_6502.name", "MOS 6502" )
	language.Add( "Tool.wire_6502.desc", "Spawns a 6502 CPU" )
	TOOL.Information = {
		{ name = "left", text = "Create a 6502 CPU" },
	}
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax( 20 )
TOOL.ClientConVar["model"] = "models/cheeze/wires/cpu.mdl"
TOOL.ClientConVar["dev1apins"] = "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"
TOOL.ClientConVar["dev2apins"] = "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"
TOOL.ClientConVar["dev3apins"] = "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"
TOOL.ClientConVar["dev4apins"] = "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"

if SERVER then
	function TOOL:GetConVars()
		return
		self:GetClientInfo("dev1apins"),
		self:GetClientInfo("dev2apins"),
		self:GetClientInfo("dev3apins"),
		self:GetClientInfo("dev4apins")
	end
end

function TOOL.BuildCPanel(panel)
	WireToolHelpers.MakePresetControl(panel, "wire_6502")
	local modelPanel = WireDermaExts.ModelSelect(panel, "wire_6502_model", list.Get("Wire_gate_Models"), 2)
	panel:AddControl("Header",{ Description = "Specify up to 16 numbers starting from 0 to map the address lines" })
	panel:AddControl("Header",{ Description = "Order from left to right determines where that bit will be mapped" })
	panel:AddControl("Header",{ Description = "Use -1 to disable a pin" })
	panel:AddControl("Textbox",{ Label = "D1 Address Pins", Command = "wire_6502_dev1apins" })
	panel:AddControl("Textbox",{ Label = "D2 Address Pins", Command = "wire_6502_dev2apins" })
	panel:AddControl("Textbox",{ Label = "D3 Address Pins", Command = "wire_6502_dev3apins" })
	panel:AddControl("Textbox",{ Label = "D4 Address Pins", Command = "wire_6502_dev4apins" })
end
