if ( SERVER ) then

	AddCSLuaFile()

	return
end

if ( not istable( highlight ) ) then

	highlight	= {

		IsValid	= function( self )
			return true
		end,
		Version	= {
			1, -- major
			0, -- minor
			0, -- patch
		}

	}

	highlight.Version = table.concat( highlight.Version, '.' )

end

local colors, classes = {}, {}

do -- @colors

	function highlight.AddColor( colorName, colorString )

		colors[ colorName ] = string.ToColor( colorString )

		local convarName = ( 'highlight_color_' .. colorName )
		local convarHelp = ( 'Color for ' .. colorName .. ' highlights' )
		CreateConVar( convarName, colorString, FCVAR_ARCHIVE, convarHelp )

		cvars.RemoveChangeCallback( convarName, colorName )
		cvars.AddChangeCallback( convarName, function( convarName, oldColor, newColor )
			colors[ colorName ] = string.ToColor( newColor )
		end, colorName )

	end

	highlight.AddColor( 'health', '0 255 51 255' )
	highlight.AddColor( 'armor', '0 255 255 255' )
	highlight.AddColor( 'weapon', '204 102 102 255' )
	highlight.AddColor( 'ammo', '204 204 102 255' )
	highlight.AddColor( 'entity', '204 51 204 255' )

end

do -- @classes

	function highlight.AddClass( className, colorName )
		classes[ className ] = colorName
	end

	-- highlight.AddClass( 'item_healthcharger', 'health' )
	highlight.AddClass( 'item_healthkit', 'health' )
	highlight.AddClass( 'item_healthvial', 'health' )
	highlight.AddClass( 'item_battery', 'armor' )
	highlight.AddClass( 'item_suit', 'armor' )
	-- highlight.AddClass( 'item_suitcharger', 'armor' )

	highlight.AddClass( 'item_item_crate', 'entity' )
	highlight.AddClass( 'item_ammo_crate', 'ammo' )

	local item_ammo = {
		'item_ammo_357', 'item_ammo_357_large',
		'item_ammo_ar2', 'item_ammo_ar2_large', 'item_ammo_ar2_altfire',
		'item_ammo_crossbow',
		'item_ammo_pistol', 'item_ammo_pistol_large',
		'item_ammo_smg1', 'item_ammo_smg1_large', 'item_ammo_smg1_grenade',
		'item_box_buckshot', 'item_rpg_round'
	}

	for index, className in ipairs( item_ammo ) do
		highlight.AddClass( className, 'ammo' )
	end

	local weapons = {
		'weapon_357', 'weapon_ar2', 'weapon_bugbait', 'weapon_crossbow',
		'weapon_crowbar', 'weapon_frag', 'weapon_physcannon', 'weapon_pistol',
		'weapon_rpg', 'weapon_shotgun', 'weapon_slam', 'weapon_smg1',
		'weapon_stunstick', 'weapon_striderbuster'
	}

	for index, className in ipairs( weapons ) do
		highlight.AddClass( className, 'weapon' )
	end

end

do -- @hooks

	local language_GetPhrase = language.GetPhrase

	local render_DepthRange = render.DepthRange
	local render_DrawBeam = render.DrawBeam
	local render_SetMaterial = render.SetMaterial

	local cam_Start2D, cam_End2D = cam.Start2D, cam.End2D
	local surface_SetFont = surface.SetFont
	local surface_GetTextSize = surface.GetTextSize
	local surface_SetTextColor = surface.SetTextColor
	local surface_SetTextPos = surface.SetTextPos
	local surface_DrawText = surface.DrawText

	local beamMaterial = Material( 'vgui/gradient-u' )

	local highlight_height = CreateConVar(
		'highlight_height',
		'24',
		FCVAR_ARCHIVE,
		language_GetPhrase( 'highlight_height.helptext' ),
		12,
		72
	)
	local beamHeight = Vector( 0, 0, highlight_height:GetInt() )
	cvars.RemoveChangeCallback( highlight_height:GetName(), 'beamHeight' )
	cvars.AddChangeCallback( highlight_height:GetName(), function( convarName, oldHeight, newHeight )
		beamHeight.z = tonumber( newHeight )
	end, 'beamHeight' )

	local highlight_width = CreateConVar(
		'highlight_width',
		'2',
		FCVAR_ARCHIVE,
		language_GetPhrase( 'highlight_width.helptext' ),
		1,
		5
	)
	local beamWidth = highlight_width:GetFloat()
	cvars.RemoveChangeCallback( highlight_width:GetName(), 'beamWidth' )
	cvars.AddChangeCallback( highlight_width:GetName(), function( convarName, oldWidth, newWidth )
		beamWidth = tonumber( newWidth )
	end, 'beamWidth' )

	-- these could be settings too
	local textFont = 'HudSelectionText'
	local textHeight = Vector( 0, 0, 4 )

	local function DrawHighlight( startPos, color, text )

		local endPos = ( startPos + beamHeight )

		render_DepthRange( 0, 0.01 )

			render_SetMaterial( beamMaterial )
			render_DrawBeam(
				startPos,
				endPos,
				beamWidth,
				0,
				1,
				color
			)

		render_DepthRange( 0, 1 )

		if ( not text ) then
			return
		end

		cam_Start2D()

			surface_SetFont( textFont )
	
			local data = ( endPos + textHeight ):ToScreen()
			local x, y = data.x, data.y
			
			local wide, tall = surface_GetTextSize( text )
			x, y = x - ( wide / 2 ), y - ( tall / 2 )

			surface_SetTextColor( 0, 0, 0, color.a )
			surface_SetTextPos( x + 2, y + 2 )
			surface_DrawText( text )

			surface_SetTextColor( color.r, color.g, color.b, color.a )
			surface_SetTextPos( x, y )
			surface_DrawText( text )

		cam_End2D()

	end
	highlight.Draw = DrawHighlight

	local math_cos, math_rad = math.cos, math.rad
	local util_TraceEntity = util.TraceEntity

	local fov_desired = GetConVar( 'fov_desired' )
	local fov_cos = math_cos( math_rad( fov_desired:GetFloat() ) )
	cvars.RemoveChangeCallback( fov_desired:GetName(), 'fov_cos' )
	cvars.AddChangeCallback( fov_desired:GetName(), function( convarName, oldFOV, newFOV )
		fov_cos = math_cos( math_rad( tonumber( newFOV ) ) )
	end, 'fov_cos' )

	local visOffset = Vector( 0, 0, 16 )

	local traceRes = {}
	local trace = { mask = MASK_SHOT, ignoreworld = false, output = traceRes }

	local function Visible( eyePos, eyeVector, entity )

		local pos = ( entity:WorldSpaceCenter() + visOffset )
		local posOffset = ( pos - eyePos )
		local posAngles = eyeVector:Dot( posOffset ) / posOffset:Length() -- yaw as cosine

		-- position is within looking direction
		if ( posAngles > fov_cos ) then

			trace.start = pos
			trace.endpos = eyePos
			trace.filter = entity
			util_TraceEntity( trace, entity )

			return traceRes.HitNonWorld
		end

		return false
	end

	local function PassesFilter( entity )

		if entity:IsWeapon() then

			if entity:GetOwner():IsValid() then
				return false
			end

		end

		return true
	end

	local ents_FindInCone = ents.FindInCone

	local highlight_range = CreateConVar(
		'highlight_range',
		'400',
		FCVAR_ARCHIVE,
		language_GetPhrase( 'highlight_range.helptext' ),
		32,
		1024
	)
	local range = highlight_range:GetInt()
	cvars.RemoveChangeCallback( highlight_range:GetName(), 'variable_update' )
	cvars.AddChangeCallback( highlight_range:GetName(), function( convarName, oldRange, newRange )
		range = tonumber( newRange )
	end, 'variable_update' )

	function highlight:PostDrawTranslucentRenderables( bDepth, bSkybox, bSkybox3D )

		if ( bSkybox ) then
			return
		end

		local eyePos, eyeVector = EyePos(), EyeVector()
		local color, class

		for index, entity in ipairs( ents_FindInCone( eyePos, eyeVector, range, fov_cos ) ) do

			if ( not PassesFilter( entity ) ) then
				goto skip
			end

			class = entity:GetClass()
			color = classes[ class ]

			if ( not color ) then
				goto skip
			end

			if ( not Visible( eyePos, eyeVector, entity ) ) then
				goto skip
			end

			local status, printName = pcall( entity.GetPrintName, entity )

			if ( not status ) then
				printName = language_GetPhrase(
					entity.PrintName or ( '#' .. class )
				)
			end

			DrawHighlight(
				entity:WorldSpaceCenter(),
				colors[ color ],
				printName
			)

			::skip::

		end

	end
	hook.Add( 'PostDrawTranslucentRenderables', highlight, highlight.PostDrawTranslucentRenderables )

	local function NumSlider( CPanel, ConVar )
		local convarName = ConVar:GetName()
		CPanel:NumSlider( '#' .. convarName, convarName, ConVar:GetMin(), ConVar:GetMax(), 0 )
		CPanel:Help( ConVar:GetHelpText() )
	end

	function highlight:PopulateToolMenu()

		local tab, category = 'Utilities', '#highlights'
		local className, printName = 'highlight_settings', '#Settings'
		local command, config = '', ''

		spawnmenu.AddToolMenuOption( tab, category, className, printName, command, config, function( CPanel )
	
			CPanel:ClearControls()

			NumSlider( CPanel, highlight_range )
			NumSlider( CPanel, highlight_height )
			NumSlider( CPanel, highlight_width )

			CPanel:Button( '#highlight_reset', 'highlight_reset' )
			CPanel:Help( '#highlight_reset.helptext' )

		end )

	end
	hook.Add( 'PopulateToolMenu', highlight, highlight.PopulateToolMenu )

	local function ResetConVar( ConVar, Type )
		ConVar[ 'Set' .. Type ]( ConVar, ConVar:GetDefault() )
	end

	concommand.Add( 'highlight_reset', function( player, command, arguments, impulse )

		ResetConVar( highlight_range, 'Int' )
		ResetConVar( highlight_height, 'Float' )
		ResetConVar( highlight_width, 'Float' )

	end )

end

do -- @support

	MsgN( '[highlights.lua] loaded ' .. highlight.Version )

	local gamemode = engine.ActiveGamemode()

	if ( gamemode == 'sandbox' ) then

		-- makes tools distinct from weapons
		highlight.AddColor( 'tool', '255 0 204 255' )

		highlight.AddClass( 'gmod_camera', 'tool' )
		highlight.AddClass( 'gmod_tool', 'tool' )
		highlight.AddClass( 'weapon_physgun', 'tool' )
		highlight.AddClass( 'weapon_medkit', 'health' )

		highlight.AddClass( 'sent_ball', 'health' )

	elseif ( gamemode == 'terrortown' ) then

		highlight.AddClass( 'item_ammo_357_ttt', 'ammo' )
		highlight.AddClass( 'item_ammo_pistol_ttt', 'ammo' )
		highlight.AddClass( 'item_ammo_revolver_ttt', 'ammo' )
		highlight.AddClass( 'item_ammo_smg1_ttt', 'ammo' )
		highlight.AddClass( 'item_box_buckshot_ttt', 'ammo' )

		local weapons = {
			'ttt_c4', 'weapon_ttt_beacon', 'weapon_ttt_binoculars', 'weapon_ttt_c4',
			'weapon_ttt_confgrenade', 'weapon_ttt_cse', 'weapon_ttt_decoy', 'weapon_ttt_defuser',
			'weapon_ttt_flaregun', 'weapon_ttt_glock', 'weapon_ttt_knife', 'weapon_ttt_m16',
			'weapon_ttt_phammer', 'weapon_ttt_push', 'weapon_ttt_radio', 'weapon_ttt_sipistol',
			'weapon_ttt_smokegrenade', 'weapon_ttt_stungun', 'weapon_ttt_teleport', 'weapon_ttt_wtester',
			'weapon_zm_improvised', 'weapon_zm_mac10', 'weapon_zm_molotov', 'weapon_zm_pistol',
			'weapon_zm_revolver', 'weapon_zm_rifle', 'weapon_zm_shotgun', 'weapon_zm_sledge'
		}

		for index, className in ipairs( weapons ) do
			highlight.AddClass( className, 'weapon' )
		end

		highlight.AddClass( 'ttt_health_station', 'health' )
		highlight.AddClass( 'weapon_ttt_health_station', 'health' )

	end

end
