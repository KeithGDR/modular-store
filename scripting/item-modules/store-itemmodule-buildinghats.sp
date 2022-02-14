//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Building Hats for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME_BUILDINGHATS "buildinghats"
#define MODULE_NAME_BUILDINGHATEFFECTS "buildinghatseffects"

#define MAX_ANIMATION_NAME_LENGTH 64
#define MAX_PARTICLE_NAME_LENGTH 64

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-items>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals
char g_Building_Hat[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
float g_Building_Offset[MAXPLAYERS + 1];
float g_Building_Scale[MAXPLAYERS + 1];
char g_Building_Animation[MAXPLAYERS + 1][MAX_ANIMATION_NAME_LENGTH];

char g_Building_Particle[MAXPLAYERS + 1][MAX_PARTICLE_NAME_LENGTH];

int g_hatEnt[2048 + 1] = {INVALID_ENT_REFERENCE, ... };
int g_particleEnt[2048 + 1] = {INVALID_ENT_REFERENCE, ... };

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Building Hats", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public void OnPluginStart()
{
	//LoadTranslations("common.phrases");
	//LoadTranslations("NEWPROJECT.phrases");
	
	//CreateConVar("sm_modularstore_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	//g_Convar_Status = CreateConVar("sm_modularstore_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	//AutoExecConfig();

	HookEvent("player_builtobject", Event_PlayerBuiltObject);
	HookEvent("player_upgradedobject", Event_UpgradeObject);
	HookEvent("player_dropobject", Event_DropObject);
	HookEvent("player_carryobject", Event_PickupObject);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		int iBuilding = -1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1) 
		{
			if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == i)
			{
				if (IsValidEntity(g_hatEnt[iBuilding]))
					AcceptEntityInput(g_hatEnt[iBuilding], "Kill");
				
				if (IsValidEntity(g_particleEnt[iBuilding]))
				{
					AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
					AcceptEntityInput(g_particleEnt[iBuilding], "Kill");
				}
				
				if (GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
				{
					SetVariantInt(0);
					AcceptEntityInput(iBuilding, "SetBodyGroup");
				}
			}
		}
	}
}

public void OnConfigsExecuted()
{
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_BUILDINGHATS))
		ModularStore_UnregisterItemType(MODULE_NAME_BUILDINGHATS);
	
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_BUILDINGHATEFFECTS))
		ModularStore_UnregisterItemType(MODULE_NAME_BUILDINGHATEFFECTS);
	
	ModularStore_OnRegisterItemTypesPost();
}

public void ModularStore_OnRegisterItemTypesPost()
{
	RegisterStatus status;
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_BUILDINGHATS, "Building Hats", OnAction_Hat)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_BUILDINGHATS, status);
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_BUILDINGHATEFFECTS, "Building Hat Effects", OnAction_Effect)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_BUILDINGHATEFFECTS, status);
}

public Action OnAction_Hat(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sModel[PLATFORM_MAX_PATH];
		itemdata.GetString("model", sModel, sizeof(sModel));
		strcopy(g_Building_Hat[client], PLATFORM_MAX_PATH, sModel);

		float offset;
		itemdata.GetValue("offset", offset);
		g_Building_Offset[client] = offset;

		float scale;
		itemdata.GetValue("scale", scale);
		g_Building_Scale[client] = scale;

		char sAnimation[MAX_ANIMATION_NAME_LENGTH];
		itemdata.GetString("animation", sAnimation, sizeof(sAnimation));
		strcopy(g_Building_Animation[client], MAX_ANIMATION_NAME_LENGTH, sAnimation);

		int iBuilding = -1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1) 
		{
			if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == client && !GetEntProp(iBuilding, Prop_Send, "m_bCarryDeploy"))
			{
				switch (TF2_GetObjectType(iBuilding))
				{
					case TFObject_Sentry:
					{
						if (GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
						{
							SetVariantInt(2);
							AcceptEntityInput(iBuilding, "SetBodyGroup");
							CreateTimer(3.0, Timer_TurnTheLightsOff, iBuilding);
						}
						
						GiveBuildingHat(iBuilding, TFObject_Sentry, g_Building_Hat[client], g_Building_Offset[client], g_Building_Scale[client], g_Building_Animation[client]);
					}
					case TFObject_Dispenser: GiveBuildingHat(iBuilding, TFObject_Dispenser, g_Building_Hat[client], g_Building_Offset[client], g_Building_Scale[client], g_Building_Animation[client]);
				}
			}
		}
	}
	else if (StrEqual(action, "unequip"))
	{
		g_Building_Hat[client][0] = '\0';
		g_Building_Offset[client] = 0.0;
		g_Building_Scale[client] = 0.0;
		g_Building_Animation[client][0] = '\0';

		int iBuilding = -1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1) 
		{
			if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == client)
			{
				if (IsValidEntity(g_hatEnt[iBuilding]))
				{
					AcceptEntityInput(g_hatEnt[iBuilding], "Kill");
					g_hatEnt[iBuilding] = INVALID_ENT_REFERENCE;
				}
				
				if (IsValidEntity(g_particleEnt[iBuilding]))
				{
					AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
					AcceptEntityInput(g_particleEnt[iBuilding], "Kill");
					g_particleEnt[iBuilding] = INVALID_ENT_REFERENCE;
				}
				
				if (GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
				{
					SetVariantInt(0);
					AcceptEntityInput(iBuilding, "SetBodyGroup");
				}
			}
		}
	}
}

public Action OnAction_Effect(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sParticle[MAX_PARTICLE_NAME_LENGTH];
		itemdata.GetString("effect", sParticle, sizeof(sParticle));
		strcopy(g_Building_Particle[client], MAX_PARTICLE_NAME_LENGTH, sParticle);

		int iBuilding = -1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1) 
		{
			if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == client && !GetEntProp(iBuilding, Prop_Send, "m_bCarryDeploy") && g_hatEnt[iBuilding] != INVALID_ENT_REFERENCE)
				AttachHatEffect(client, iBuilding);
		}
	}
	else if (StrEqual(action, "unequip"))
	{
		g_Building_Particle[client][0] = '\0';

		int iBuilding = -1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1) 
		{
			if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == client)
			{
				if (IsValidEntity(g_particleEnt[iBuilding]))
				{
					AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
					AcceptEntityInput(g_particleEnt[iBuilding], "Kill");
					g_particleEnt[iBuilding] = INVALID_ENT_REFERENCE;
				}
			}
		}
	}
}

public void Event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0 && client <= MaxClients && IsClientInGame(client) && strlen(g_Building_Hat[client]) > 0)
	{
		int iBuilding = event.GetInt("index");
		
		if (iBuilding > MaxClients && IsValidEntity(iBuilding) && !GetEntProp(iBuilding, Prop_Send, "m_bCarryDeploy"))
		{
			switch (view_as<TFObjectType>(event.GetInt("object")))
			{
				case TFObject_Sentry:
				{
					if (GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
					{
						SetVariantInt(2);
						AcceptEntityInput(iBuilding, "SetBodyGroup");
						CreateTimer(3.0, Timer_TurnTheLightsOff, iBuilding);
					}

					GiveBuildingHat(iBuilding, TFObject_Sentry, g_Building_Hat[client], g_Building_Offset[client], g_Building_Scale[client], g_Building_Animation[client]);
				}
				case TFObject_Dispenser: GiveBuildingHat(iBuilding, TFObject_Dispenser, g_Building_Hat[client], g_Building_Offset[client], g_Building_Scale[client], g_Building_Animation[client]);
			}
		}
	}
}

public Action Timer_TurnTheLightsOff(Handle timer, any iBuilding)
{
	if (iBuilding > MaxClients && IsValidEntity(iBuilding))
	{
		SetVariantInt(2);
		AcceptEntityInput(iBuilding, "SetBodyGroup");
	}
}

public void Event_UpgradeObject(Event event, const char[] name, bool dontBroadcast)
{
	int iBuilding = event.GetInt("index");
	
	if (iBuilding > MaxClients && IsValidEntity(iBuilding))
	{
		int builder = GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder");

		if (builder >= 1 && builder <= MaxClients && IsClientInGame(builder) && strlen(g_Building_Hat[builder]) == 0)
			return;
		
		if (view_as<TFObjectType>(event.GetInt("object")) == TFObject_Dispenser && GetEntProp(iBuilding, Prop_Send, "m_iUpgradeLevel") != 2)
			return;
		
		if (IsValidEntity(g_hatEnt[iBuilding]))
		{
			AcceptEntityInput(g_hatEnt[iBuilding], "Kill");
			g_hatEnt[iBuilding] = INVALID_ENT_REFERENCE;
		}

		if (IsValidEntity(g_particleEnt[iBuilding]))
		{
			AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
			AcceptEntityInput(g_particleEnt[iBuilding], "Kill");
			g_particleEnt[iBuilding] = INVALID_ENT_REFERENCE;
		}

		CreateTimer(2.0, Timer_ReHat, iBuilding);
	}
}

public Action Timer_ReHat(Handle timer, any iBuilding)
{
	if (iBuilding > MaxClients && IsValidEntity(iBuilding))
	{
		int client = GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder");

		switch (TF2_GetObjectType(iBuilding))
		{
			case TFObject_Sentry: GiveBuildingHat(iBuilding, TFObject_Sentry, g_Building_Hat[client], g_Building_Offset[client], g_Building_Scale[client], g_Building_Animation[client]);
			case TFObject_Dispenser: GiveBuildingHat(iBuilding, TFObject_Dispenser, g_Building_Hat[client], g_Building_Offset[client], g_Building_Scale[client], g_Building_Animation[client]);
		}
	}
}

public void Event_DropObject(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0 && client <= MaxClients && IsClientInGame(client) && strlen(g_Building_Hat[client]) > 0)
	{
		int iBuilding = event.GetInt("index");
		
		if (iBuilding > MaxClients && IsValidEntity(iBuilding))
		{
			if (view_as<TFObjectType>(event.GetInt("object")) == TFObject_Sentry && GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
			{
				SetVariantInt(2);
				AcceptEntityInput(iBuilding, "SetBodyGroup");
				CreateTimer(2.0, Timer_TurnTheLightsOff, iBuilding);
			}
			
			if (IsValidEntity(g_hatEnt[iBuilding]))
				AcceptEntityInput(g_hatEnt[iBuilding], "TurnOn");

			if (IsValidEntity(g_particleEnt[iBuilding]))
				AcceptEntityInput(g_particleEnt[iBuilding], "Start");
		}
	}
}

public void Event_PickupObject(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client == 0 || client > MaxClients || !IsClientInGame(client))
		return;
	
	int iBuilding = event.GetInt("index");

	if (iBuilding > MaxClients && IsValidEntity(iBuilding))
	{
		if (IsValidEntity(g_hatEnt[iBuilding]))
			AcceptEntityInput(g_hatEnt[iBuilding], "TurnOff");
		
		if (IsValidEntity(g_particleEnt[iBuilding]))
			AcceptEntityInput(g_particleEnt[iBuilding], "Stop");
	}
}

int GiveBuildingHat(int entity, TFObjectType objectT, const char[] smodel, float flZOffset, float flModelScale, const char[] strAnimation)
{
	int prop = CreateEntityByName("prop_dynamic_override");
	
	if (!IsValidEntity(prop))
		return prop;
		
	DispatchKeyValue(prop, "model", smodel); 
	SetEntPropFloat(prop, Prop_Send, "m_flModelScale", flModelScale);

	DispatchSpawn(prop);
	AcceptEntityInput(prop, "Enable");

	int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
	SetEntProp(prop, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);

	SetVariantString("!activator");
	AcceptEntityInput(prop, "SetParent", entity);
	
	switch (objectT)
	{
		case TFObject_Sentry: SetVariantString(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") < 3 ? "build_point_0" : "rocket_r");
		case TFObject_Dispenser: SetVariantString("build_point_0");
	}
		
	AcceptEntityInput(prop, "SetParentAttachment", entity);
	
	float pPos[3];
	GetEntPropVector(prop, Prop_Send, "m_vecOrigin", pPos);
	
	float pAng[3];
	GetEntPropVector(prop, Prop_Send, "m_angRotation", pAng);
	
	if (!StrEqual(strAnimation, "default", false))
	{
		SetVariantString(strAnimation);
		AcceptEntityInput(prop, "SetAnimation");  

		SetVariantString(strAnimation);
		AcceptEntityInput(prop, "SetDefaultAnimation");
	}
		
	pPos[2] += flZOffset;
		
	if (objectT == TFObject_Dispenser)
	{
		pPos[2] += 13.0;
		pAng[1] += 180.0;
		
		if (GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3)
			pPos[2] += 8.0;
	}
	else if (GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3)
	{
		pPos[2] += 6.5;
		pPos[0] -= 11.0;
	}
	
	SetEntPropVector(prop, Prop_Send, "m_vecOrigin", pPos);
	SetEntPropVector(prop, Prop_Send, "m_angRotation", pAng);

	g_hatEnt[entity] = EntIndexToEntRef(prop);

	AttachHatEffect(builder, entity);
	return entity;
}

int AttachHatEffect(int builder, int entity)
{
	if (strlen(g_Building_Particle[builder]) == 0)
		return -1;
	
	if (IsValidEntity(g_particleEnt[entity]))
	{
		AcceptEntityInput(g_particleEnt[entity], "Stop");
		AcceptEntityInput(g_particleEnt[entity], "Kill");
		g_particleEnt[entity] = INVALID_ENT_REFERENCE;
	}
	
	int iParticle = CreateEntityByName("info_particle_system"); 
	
	if (IsValidEdict(iParticle))
	{
		DispatchKeyValue(iParticle, "effect_name", g_Building_Particle[builder]); 
		DispatchSpawn(iParticle); 
			
		SetVariantString("!activator"); 
		AcceptEntityInput(iParticle, "SetParent", entity); 
		ActivateEntity(iParticle); 
		
		switch (TF2_GetObjectType(entity))
		{
			case TFObject_Sentry: SetVariantString(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") < 3 ? "build_point_0" : "rocket_r");
			case TFObject_Dispenser: SetVariantString("build_point_0");
		}

		AcceptEntityInput(iParticle, "SetParentAttachment", entity);
		
		float flPos[3];
		GetEntPropVector(iParticle, Prop_Send, "m_vecOrigin", flPos);

		switch (TF2_GetObjectType(entity))
		{
			case TFObject_Sentry:
			{
				SetVariantString(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") < 3 ? "build_point_0" : "rocket_r");
				
				if (GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3)
				{
					flPos[2] += 6.5;
					flPos[0] -= 11.0;
				}
			}
			case TFObject_Dispenser:
			{
				flPos[2] += 13.0;
				
				if (GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") == 3)
					flPos[2] += 8.0;
			}
		}
		
		SetEntPropVector(iParticle, Prop_Send, "m_vecOrigin", flPos);
		AcceptEntityInput(iParticle, "start");
		
		g_particleEnt[entity] = EntIndexToEntRef(iParticle);
	}

	return iParticle;
}