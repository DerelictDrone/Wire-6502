WireToolSetup.setCategory("Visuals")
WireToolSetup.open( "ntsc_screen", "NTSC Screen", "gmod_wire_ntsc_screen", nil, "NTSC Screens" )

if ( CLIENT ) then
	language.Add( "Tool.wire_ntsc_screen.name", "NTSC Screen" )
	language.Add( "Tool.wire_tia.ntsc_screen", "Spawns an NTSC Screen" )
	TOOL.Information = {
		{ name = "left", text = "Create an NTSC Screen" },
	}
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax( 20 )
TOOL.ClientConVar[ "model" ] = "models/cheeze/wires/cpu.mdl"

function TOOL.BuildCPanel(panel)
	WireToolHelpers.MakePresetControl(panel, "wire_ntsc_screen_model")
    local modelPanel = WireDermaExts.ModelSelect(panel, "wire_ntsc_screen_model", list.Get("WireScreenModels"), 3)
end
