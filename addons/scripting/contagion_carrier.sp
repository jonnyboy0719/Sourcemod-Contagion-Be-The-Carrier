#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <contagion>

#define PLUGIN_VERSION "1.4"
// The higher number the less chance the carrier can infect
#define INFECTION_MAX_CHANCE	20

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
new Handle:g_hCvarNormalInfectionMode;
new Handle:g_SetWhiteyHealth;
new Handle:g_SetWhiteyInfectionTime;
new g_nCarriers[MAXPLAYERS+1][g_edata];

new Handle:g_GetMeleeInfection_Easy;
new Handle:g_GetMeleeInfection_Normal;
new Handle:g_GetMeleeInfection_Hard;
new Handle:g_GetMeleeInfection_Extreme;

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
	CreateConVar("sm_carrier_version", PLUGIN_VERSION, "Current \"Be The Carrier\" Version",
		FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_SPONLY);
	g_hDebugMode						= CreateConVar("sm_carrier_debug", "0", "0 - Disable debugging | 1 - Enable Debugging");
	g_hCvarMode							= CreateConVar("sm_carrier_max", "1", "How many carriers should can we have alive at once?");
	g_hCvarNormalInfectionMode			= CreateConVar("sm_carrier_infection_normal", "0", "0 - Disable normal zombie infection | 1 - Enable normal zombie infection");
	g_SetWhiteyHealth					= CreateConVar("sm_carrier_health", "250.0", "Value to change the carrier health to. Minimum 250.", 
		FCVAR_PLUGIN | FCVAR_NOTIFY, true, 250.0);
	g_SetWhiteyInfectionTime			= CreateConVar("sm_carrier_infection", "35.0", "Value to change the carrier infection time to. Minimum 20.", 
		FCVAR_PLUGIN | FCVAR_NOTIFY, true, 20.0);
	
	// Hooks
	HookConVarChange(g_hCvarNormalInfectionMode, OnConVarChange);
	
	// Get Contagion commands
	g_GetMeleeInfection_Easy = FindConVar("cg_infection_attacked_chance_easy");
	g_GetMeleeInfection_Normal = FindConVar("cg_infection_attacked_chance_normal");
	g_GetMeleeInfection_Hard = FindConVar("cg_infection_attacked_chance_hard");
	g_GetMeleeInfection_Extreme = FindConVar("cg_infection_attacked_chance_extreme");
	
	for (new i = 0; i <= MaxClients; i++) OnClientPostAdminCheck(i);
	
	CheckInfectionMode();
}

public CheckInfectionMode()
{
	new disabled = -1;
	if (GetConVarInt(g_hCvarNormalInfectionMode) == 1)
	{
		SetConVarInt(g_GetMeleeInfection_Easy, disabled);
		SetConVarInt(g_GetMeleeInfection_Normal, 3);
		SetConVarInt(g_GetMeleeInfection_Hard, 8);
		SetConVarInt(g_GetMeleeInfection_Extreme, 20);
	}
	else
	{
		SetConVarInt(g_GetMeleeInfection_Easy, disabled);
		SetConVarInt(g_GetMeleeInfection_Normal, disabled);
		SetConVarInt(g_GetMeleeInfection_Hard, disabled);
		SetConVarInt(g_GetMeleeInfection_Extreme, disabled);
	}
}

public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new disabled = -1;
	if (strcmp(oldValue, newValue) != 0)
	{
		if (strcmp(newValue, "1") == 0)
		{
			SetConVarInt(g_GetMeleeInfection_Easy, disabled);
			SetConVarInt(g_GetMeleeInfection_Normal, 3);
			SetConVarInt(g_GetMeleeInfection_Hard, 8);
			SetConVarInt(g_GetMeleeInfection_Extreme, 20);
		}
		else
		{
			SetConVarInt(g_GetMeleeInfection_Easy, disabled);
			SetConVarInt(g_GetMeleeInfection_Normal, disabled);
			SetConVarInt(g_GetMeleeInfection_Hard, disabled);
			SetConVarInt(g_GetMeleeInfection_Extreme, disabled);
		}
	}
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
	if (GetCarrierCount() < GetConVarInt(g_hCvarMode))
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
		PrintToServer("[[ =========================== ]]");
		PrintToServer("[[ (%s) %N infection time is %f ]]", teamname, client, CONTAGION_GetInfectionTime(client));
	}
	
	new iTeam = GetClientTeam(client);
	if (iTeam == _:CTEAM_Zombie)
		// Lets make a small timer, so the model can be set 1 mili second after the player has actually spawned, so we can actually override the model.
		CreateTimer(0.1, SetModel, client);
}

public Action:PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// lets make sure they are actual clients
	if (!IsValidClient(attacker)) return;
	if (!IsValidClient(client)) return;
	
	// Don't continue if the client is also the attacker
	if (attacker == client)
		return;
	
	if (g_nCarriers[attacker][g_nIfCarrier] == STATE_CARRIER)
	{
		if (GetClientTeam(attacker) == _:CTEAM_Zombie)
		{
			new infection_chance = GetRandomInt(1, INFECTION_MAX_CHANCE);
			switch(infection_chance)
			{
				// The carrier have higher chance to infect someone
				case 1,2,5,16,20:
				{
					CONTAGION_SetInfectionTime(client, GetConVarFloat(g_SetWhiteyInfectionTime));
				}
				
				default:
				{
				}
			}
		}
	}
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