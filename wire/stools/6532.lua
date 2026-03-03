WireToolSetup.setCategory("Memory")
WireToolSetup.open( "6532riot", "6532 RIOT Ram", "gmod_wire_6532riot", nil, "6532 RIOT Ram chips" )

if ( CLIENT ) then
	language.Add( "Tool.wire_6532riot.name", "MOS 6532" )
	language.Add( "Tool.wire_6532riot.desc", "Spawns a 6532 RIOT Ram chip" )
	TOOL.Information = {
		{ name = "left", text = "Create a 6532 RIOT Ram chip" },
	}
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax( 20 )
TOOL.ClientConVar[ "model" ] = "models/cheeze/wires/cpu.mdl"

function TOOL.BuildCPanel(panel)
	WireToolHelpers.MakePresetControl(panel, "wire_6532riot")
    local modelPanel = WireDermaExts.ModelSelect(panel, "wire_6532riot_model", list.Get("Wire_gate_Models"), 2)
end
