//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Pets for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME "pets"

#define STATE_IDLE		0
#define STATE_WALKING	1
#define STATE_JUMPING	2

#define MAX_ANIMATION_NAME_LENGTH 64

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-items>
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-items>
#include <modularstore/modularstore-shop>
#include <modularstore/modularstore-inventory>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals
int g_Pet[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

ArrayList g_Pets;
int g_PetStance[2048 + 1] = {STATE_IDLE, ...};
int g_PetHeight[2048 + 1];
char g_PetAnimations[2048 + 1][3][MAX_ANIMATION_NAME_LENGTH];

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Pets", 
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

	g_Pets = new ArrayList();
	RegAdminCmd("sm_testpets", Command_TestPets, ADMFLAG_ROOT);

	HookEvent("player_spawn", Event_OnPlayerSpawn);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(g_Pet[i]))
			AcceptEntityInput(g_Pet[i], "Kill");
	}

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != -1)
	{
		if (g_Pets.FindValue(EntIndexToEntRef(entity)) != -1)
			AcceptEntityInput(entity, "Kill");
	}
}

public void OnConfigsExecuted()
{
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME))
		ModularStore_UnregisterItemType(MODULE_NAME);
	
	ModularStore_OnRegisterItemTypesPost();
}

public void ModularStore_OnRegisterItemTypesPost()
{
	RegisterStatus status;
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME, "Pets", OnAction)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME, status);
}

public Action OnAction(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sModel[PLATFORM_MAX_PATH];
		itemdata.GetString("model", sModel, sizeof(sModel));

		if (StrContains(sModel, "models/", false) != 0)
			Format(sModel, sizeof(sModel), "models/%s", sModel);

		if (StrContains(sModel, ".mdl", false) == -1)
			Format(sModel, sizeof(sModel), "%s.mdl", sModel);
			
		if (!IsModelPrecached(sModel))
			PrecacheModel(sModel);

		char sAnimation_Idle[MAX_ANIMATION_NAME_LENGTH];
		itemdata.GetString("anim_idle", sAnimation_Idle, sizeof(sAnimation_Idle));

		char sAnimation_Walk[MAX_ANIMATION_NAME_LENGTH];
		itemdata.GetString("anim_walk", sAnimation_Walk, sizeof(sAnimation_Walk));

		char sAnimation_Jump[MAX_ANIMATION_NAME_LENGTH];
		itemdata.GetString("anim_jump", sAnimation_Jump, sizeof(sAnimation_Jump));

		int height;
		itemdata.GetValue("add_height", height);

		int skin;
		itemdata.GetValue("skin", skin);

		float scale;
		itemdata.GetValue("scale", scale);

		int rendercolor[4] = {255, 255, 255, 255};
		itemdata.GetArray("render_color", rendercolor, sizeof(rendercolor));

		RenderMode rendermode = RENDER_NORMAL;
		itemdata.GetValue("render_mode", rendermode);

		RenderFx renderfx = RENDERFX_NONE;
		itemdata.GetValue("render_fx", renderfx);

		KillPet(client);
		g_Pet[client] = CreatePet(client, sModel, sAnimation_Idle, sAnimation_Walk, sAnimation_Jump, height, skin, scale, rendercolor, rendermode, renderfx);
		g_Pets.Push(g_Pet[client]);
	}
	else if (StrEqual(action, "unequip"))
	{
		KillPet(client);
	}
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.2, Timer_DelaySpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelaySpawn(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Stop;
	
	char sItem[MAX_ITEM_NAME_LENGTH];
	if (!ModularStore_GetEquippedItem(client, MODULE_NAME, sItem, sizeof(sItem)) || strlen(sItem) == 0)
		return Plugin_Stop;

	StringMap itemdata;
	if ((itemdata = ModularStore_GetItemData(MODULE_NAME, sItem)) == null)
		return Plugin_Stop;

	char sModel[PLATFORM_MAX_PATH];
	itemdata.GetString("model", sModel, sizeof(sModel));

	if (StrContains(sModel, "models/", false) != 0)
		Format(sModel, sizeof(sModel), "models/%s", sModel);

	if (StrContains(sModel, ".mdl", false) == -1)
		Format(sModel, sizeof(sModel), "%s.mdl", sModel);
			
	if (!IsModelPrecached(sModel))
		PrecacheModel(sModel);

	char sAnimation_Idle[MAX_ANIMATION_NAME_LENGTH];
	itemdata.GetString("anim_idle", sAnimation_Idle, sizeof(sAnimation_Idle));

	char sAnimation_Walk[MAX_ANIMATION_NAME_LENGTH];
	itemdata.GetString("anim_walk", sAnimation_Walk, sizeof(sAnimation_Walk));

	char sAnimation_Jump[MAX_ANIMATION_NAME_LENGTH];
	itemdata.GetString("anim_jump", sAnimation_Jump, sizeof(sAnimation_Jump));

	int height;
	itemdata.GetValue("add_height", height);

	int skin;
	itemdata.GetValue("skin", skin);

	float scale;
	itemdata.GetValue("scale", scale);

	int rendercolor[4] = {255, 255, 255, 255};
	itemdata.GetArray("render_color", rendercolor, sizeof(rendercolor));

	RenderMode rendermode = RENDER_NORMAL;
	itemdata.GetValue("render_mode", rendermode);

	RenderFx renderfx = RENDERFX_NONE;
	itemdata.GetValue("render_fx", renderfx);

	KillPet(client);
	g_Pet[client] = CreatePet(client, sModel, sAnimation_Idle, sAnimation_Walk, sAnimation_Jump, height, skin, scale, rendercolor, rendermode, renderfx);
	g_Pets.Push(g_Pet[client]);

	return Plugin_Stop;
}

int CreatePet(int client, const char[] model, const char[] anim_idle, const char[] anim_walk, const char[] anim_jump, int height, int skin, float scale, int rendercolor[4], RenderMode rendermode, RenderFx renderfx)
{
	if (strlen(model) == 0)
		return -1;
	
	int entity = CreateEntityByName("prop_dynamic_override");

	if (IsValidEntity(entity))
	{
		g_PetStance[entity] = STATE_IDLE;
		g_PetHeight[entity] = height;
		strcopy(g_PetAnimations[entity][STATE_IDLE], MAX_ANIMATION_NAME_LENGTH, anim_idle);
		strcopy(g_PetAnimations[entity][STATE_WALKING], MAX_ANIMATION_NAME_LENGTH, anim_walk);
		strcopy(g_PetAnimations[entity][STATE_JUMPING], MAX_ANIMATION_NAME_LENGTH, anim_jump);

		float vecOrigin[3];
		GetClientAbsOrigin(client, vecOrigin);

		vecOrigin[0] += GetRandomFloat(-128.0, 128.0);
		vecOrigin[1] += GetRandomFloat(-128.0, 128.0);

		DispatchKeyValueVector(entity, "origin", vecOrigin);
		DispatchKeyValue(entity, "model", model);
		DispatchKeyValueInt(entity, "skin", skin);
		DispatchKeyValueFloat(entity, "modelscale", scale);
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchSpawn(entity);

		SetEntityRenderColorEx(entity, rendercolor);
		SetEntityRenderMode(entity, rendermode);
		SetEntityRenderFx(entity, renderfx);

		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	}

	return EntIndexToEntRef(entity);
}

void KillPet(int client)
{
	if (IsValidEntity(g_Pet[client]))
	{
		int index = -1;
		if ((index = g_Pets.FindValue(g_Pet[client])) != -1)
			g_Pets.Erase(index);

		int entity = -1;
		if ((entity = EntRefToEntIndex(g_Pet[client])) > 0)
		{
			g_PetStance[entity] = STATE_IDLE;
			g_PetHeight[entity] = 0;

			for (int i = 0; i < 3; i++)
				g_PetAnimations[entity][i][0] = '\0';
		}

		AcceptEntityInput(g_Pet[client], "Kill");
		g_Pet[client] = INVALID_ENT_REFERENCE;
	}
}

public void OnGameFrame()
{
	int entity = -1;
	for (int i = 0; i < g_Pets.Length; i++)
	{
		entity = EntRefToEntIndex(g_Pets.Get(i));

		if (!IsValidEntity(entity))
			continue;
		
		OnPetThink(entity);
	}
}

void OnPetThink(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if (client < 1 || !IsPlayerAlive(client) || TF2_IsPlayerInCondition(client, TFCond_Cloaked) || TF2_IsPlayerInCondition(client, TFCond_Disguised))
		return;
		
	float pos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);

	float ang[3];
	GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);

	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);

	float dist = GetVectorDistance(clientPos, pos);
	float distX = clientPos[0] - pos[0];
	float distY = clientPos[1] - pos[1];
	float speed = (dist - 64.0) / 54;

	if (speed < -4.0)
		speed = -4.0;
	else if (speed > 4.0)
		speed = 4.0;
		
	if (FloatAbs(speed) < 0.3)
		speed *= 0.1;
		
	if (dist > 1024.0)
	{
		float posTmp[3];
		GetClientAbsOrigin(client, posTmp);

		posTmp[0] += GetRandomFloat(-128.0, 128.0);
		posTmp[1] += GetRandomFloat(-128.0, 128.0);

		TeleportEntity(entity, posTmp, NULL_VECTOR, NULL_VECTOR);
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
	}

	if (pos[0] < clientPos[0])
		pos[0] += speed;
		
	if (pos[0] > clientPos[0])
		pos[0] -= speed;
		
	if (pos[1] < clientPos[1])
		pos[1] += speed;
		
	if (pos[1] > clientPos[1])
		pos[1] -= speed;

	pos[2] = clientPos[2] + g_PetHeight[entity];

	if (!(GetEntityFlags(client) & FL_ONGROUND))
		SetPetState(entity, STATE_JUMPING);
	else if (FloatAbs(speed) > 0.2)
		SetPetState(entity, STATE_WALKING);
	else
		SetPetState(entity, STATE_IDLE);
		
	ang[1] = (ArcTangent2(distY, distX) * 180) / 3.14;

	TeleportEntity(entity, pos, ang, NULL_VECTOR);
}

void SetPetState(int entity, int status)
{ 
	if (g_PetStance[entity] == status)
		return;
	
	g_PetStance[entity] = status;

	if (strlen(g_PetAnimations[entity][status]) > 0)
	{
		SetVariantString(g_PetAnimations[entity][status]);
		AcceptEntityInput(entity, "SetAnimation");
	}
}

public Action Command_TestPets(int client, int args)
{
	if (args == 0)
	{
		PrintToChat(client, "Specify a pet.");
		return Plugin_Handled;
	}

	char sName[64];
	GetCmdArgString(sName, sizeof(sName));

	StringMap itemdata = ModularStore_GetItemData("Pets", sName);

	if (itemdata == null)
	{
		PrintToChat(client, "Pet not found.");
		return Plugin_Handled;
	}

	char sModel[PLATFORM_MAX_PATH];
	itemdata.GetString("model", sModel, sizeof(sModel));

	if (StrContains(sModel, "models/", false) != 0)
		Format(sModel, sizeof(sModel), "models/%s", sModel);

	if (StrContains(sModel, ".mdl", false) == -1)
		Format(sModel, sizeof(sModel), "%s.mdl", sModel);
			
	if (!IsModelPrecached(sModel))
		PrecacheModel(sModel);

	char sAnimation_Idle[MAX_ANIMATION_NAME_LENGTH];
	itemdata.GetString("anim_idle", sAnimation_Idle, sizeof(sAnimation_Idle));

	char sAnimation_Walk[MAX_ANIMATION_NAME_LENGTH];
	itemdata.GetString("anim_walk", sAnimation_Walk, sizeof(sAnimation_Walk));

	char sAnimation_Jump[MAX_ANIMATION_NAME_LENGTH];
	itemdata.GetString("anim_jump", sAnimation_Jump, sizeof(sAnimation_Jump));

	int height;
	itemdata.GetValue("add_height", height);

	int skin;
	itemdata.GetValue("skin", skin);

	float scale;
	itemdata.GetValue("scale", scale);

	int rendercolor[4] = {255, 255, 255, 255};
	itemdata.GetArray("render_color", rendercolor, sizeof(rendercolor));

	RenderMode rendermode = RENDER_NORMAL;
	itemdata.GetValue("render_mode", rendermode);

	RenderFx renderfx = RENDERFX_NONE;
	itemdata.GetValue("render_fx", renderfx);

	KillPet(client);
	g_Pet[client] = CreatePet(client, sModel, sAnimation_Idle, sAnimation_Walk, sAnimation_Jump, height, skin, scale, rendercolor, rendermode, renderfx);
	g_Pets.Push(g_Pet[client]);

	return Plugin_Handled;
}