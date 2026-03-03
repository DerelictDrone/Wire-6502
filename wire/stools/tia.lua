WireToolSetup.setCategory("Visuals")
WireToolSetup.open( "tia", "TIA", "gmod_wire_tia", nil, "Television Interface Adapters" )

if ( CLIENT ) then
	language.Add( "Tool.wire_tia.name", "T.I.A" )
	language.Add( "Tool.wire_tia.desc", "Spawns a Television Interface Adapter" )
	TOOL.Information = {
		{ name = "left", text = "Create a Television Interface Adapter" },
	}
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax( 20 )
TOOL.ClientConVar[ "model" ] = "models/cheeze/wires/cpu.mdl"

function TOOL.BuildCPanel(panel)
	WireToolHelpers.MakePresetControl(panel, "wire_tia")
    local modelPanel = WireDermaExts.ModelSelect(panel, "wire_tia_model", list.Get("Wire_gate_Models"), 2)
end
