WireToolSetup.setCategory("Memory")
WireToolSetup.open( "chipselect", "Chip Select", "gmod_wire_chipselect", nil, "Chip Selects" )

if ( CLIENT ) then
	language.Add( "Tool.wire_chipselect.name", "Chip Select" )
	language.Add( "Tool.wire_chipselect.desc", "Spawns a Chip Select" )
	TOOL.Information = {
		{ name = "left", text = "Create a Chip Select" },
	}
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax( 20 )
TOOL.ClientConVar["model"] = "models/cheeze/wires/cpu.mdl"
TOOL.ClientConVar["mask"] = "1"
TOOL.ClientConVar["allowpartial"] = "1"
TOOL.ClientConVar["inverted"] = "0"

if SERVER then
	function TOOL:GetConVars()
		return self:GetClientNumber("mask"),
		self:GetClientBool("allowpartial"),
		self:GetClientBool("inverted")
	end
end

function TOOL.BuildCPanel(panel)
	WireToolHelpers.MakePresetControl(panel, "wire_6502")
	local modelPanel = WireDermaExts.ModelSelect(panel, "wire_chipselect_model", list.Get("Wire_gate_Models"), 2)
	panel:AddControl("Header",{ Description = "Will return 0 and ignore read/writes unless mask bit(s) are ON" })
	panel:AddControl("Header",{ Description = "Mask bits will be stripped from the resulting address!" })
	panel:AddControl("Slider",{ Min=1, Max=math.pow(2,32), Label = "Chip Select Mask", Command = "wire_chipselect_mask" })
	panel:AddControl("Checkbox",{ Label = "Allow Partial (one bit must be on)?", Command = "wire_chipselect_allowpartial" })
	panel:AddControl("Checkbox",{ Label = "Inverted mode", Command = "wire_chipselect_inverted" })
end
