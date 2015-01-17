#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <contagion>

#define PLUGIN_VERSION "1.1"

// TODO: Add lives override
enum g_eModes
{
	MODE_LIVES=0,	// Default 4 lives on CE and other modes.
	MODE_OVERRIDE=1	// Override the amount of lives you have, so you always will live (this doesn't apply for CPC)
};

enum g_eStatus
{
	STATE_NOT_CARRIER=0,
	STATE_CARRIER
};

enum g_edata
{
	g_eModes:g_nCarrierMode,
	g_eStatus:g_nIfCarrier
};

new CanBeCarrier;
new Handle:g_hDebugMode;
new Handle:g_hCvarMode;
new Handle:g_SetWhiteyHealth;
new g_nCarriers[MAXPLAYERS+1][g_edata];

public Plugin:myinfo =
{
	name = "[Contagion] Be The Carrier",
	author = "JonnyBoy0719",
	version = PLUGIN_VERSION,
	description = "Makes the first player zombie a carrier from Zombie Panic! Source",
	url = "https://forums.alliedmods.net/"
}

public OnPluginStart()
{
	// Events
	HookEvent("player_spawn",EVENT_PlayerSpawned);
	
	// Commands
	CreateConVar("sm_carrier_version", PLUGIN_VERSION, "Current \"Be The Carrier\" Version", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_SPONLY);
	g_hDebugMode		= CreateConVar("sm_carrier_debug", "0", "0 - Disable debugging | 1 - Enable Debugging");
	g_hCvarMode			= CreateConVar("sm_carrier_max", "1", "How many carriers should can we have alive at once?");
	g_SetWhiteyHealth	= CreateConVar("sm_carrier_health", "250.0", "Value to change the carrier health to. Minimum 250.", 
		FCVAR_PLUGIN|FCVAR_NOTIFY, true, 250.0);
	
	for (new i = 0; i <= MaxClients; i++) OnClientPostAdminCheck(i);
}

public OnClientPostAdminCheck(client)
{
	if (!IsValidClient(client)) return;
	g_nCarriers[client][g_nIfCarrier] = STATE_NOT_CARRIER;
	CheckTeams();
}

public OnMapStart()
{
	// Download the model
	AddFileToDownloadsTable("models/zombies/whitey/whitey.mdl");
	AddFileToDownloadsTable("models/zombies/whitey/whitey.dx90.vtx");
	AddFileToDownloadsTable("models/zombies/whitey/whitey.vvd");
	
	// Download the textures
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_body_DIF.vmt");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_body_DIF.vtf");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_body_NM.vtf");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_eye.vmt");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_eye.vtf");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_head_DIF.vmt");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_head_DIF.vtf");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_head_NM.vtf");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_teeth.vmt");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zombie1_teeth.vtf");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zp_sv1_pants.vmt");
	AddFileToDownloadsTable("materials/models/zombies/Zombie0/zp_sv1_pants.vtf");
	
	// Precache everything
	PrecacheModel("models/zombies/whitey/whitey.mdl");
}

public CheckTeams()
{
	if (GetCarrierCount() <= GetConVarInt(g_hCvarMode))
		CanBeCarrier = true;
	else
		CanBeCarrier = false;
}

public Action:EVENT_PlayerSpawned(Handle:hEvent,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!IsValidClient(client)) return;
	
	CheckTeams();
	
	new String:teamname[32];
	
	if (GetClientTeam(client) == _:CTEAM_Zombie)
		teamname = "Zombie";
	else
		teamname = "Survivor";
	
	// if the player is already a carrier, don't call this
	if (g_nCarriers[client][g_nIfCarrier] == STATE_NOT_CARRIER)
	{
		if (CanBeCarrier && GetClientTeam(client) == _:CTEAM_Zombie)
			g_nCarriers[client][g_nIfCarrier] = STATE_CARRIER;
	}
	
	if (GetConVarInt(g_hDebugMode) >= 1)
	{
		if (g_nCarriers[client][g_nIfCarrier] == STATE_CARRIER)
			PrintToServer("(%s) %N is a carrier", teamname, client);
		else
			PrintToServer("(%s) %N is not a carrier", teamname, client);
		
		// Lets get the information of how many zombies there is, and what the amount is
		PrintToServer("[[ There is %d amount of zombies (players) ]]", GetZombieCount());
		PrintToServer("[[ There is %d amount of carriers ]]", GetCarrierCount());
		PrintToServer("[[ %d is the max carrier count ]]", GetConVarInt(g_hCvarMode));
	}
	
	new iTeam = GetClientTeam(client);
	if (iTeam == _:CTEAM_Zombie)
		// Lets make a small timer, so the model can be set 1 mili second after the player has actually spawned, so we can actually override the model.
		CreateTimer(0.1, SetModel, client);
}

public Action:SetModel(Handle:timer, any:client)
{
	// Only call this if the player is a carrier
	if (g_nCarriers[client][g_nIfCarrier] == STATE_CARRIER)
	{
		SetEntityModel(client,"models/zombies/whitey/whitey.mdl");
		new sethealth = GetConVarInt(g_SetWhiteyHealth);
		SetEntityHealth(client, sethealth);
	}
}

public OnClientDisconnect(client)
{
	if (!IsValidClient(client)) return;
	CheckTeams();
}

stock bool:IsValidClient(client, bool:bCheckAlive=true)
{
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsClientSourceTV(client) || IsClientReplay(client)) return false;
	if(IsFakeClient(client)) return false;
	if(bCheckAlive) return IsPlayerAlive(client);
	return true;
}

GetCarrierCount()
{
	decl iCount, i; iCount = 0;
	
	for( i = 1; i <= MaxClients; i++ )
		if( IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == _:CTEAM_Zombie && g_nCarriers[i][g_nIfCarrier] == STATE_CARRIER )
			iCount++;
	
	return iCount;
}

GetZombieCount()
{
	decl iCount, i; iCount = 0;
	
	for( i = 1; i <= MaxClients; i++ )
		if( IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == _:CTEAM_Zombie )
			iCount++;
	
	return iCount;
}