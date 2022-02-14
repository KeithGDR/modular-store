#if defined _tf2_weapons_included
  #endinput
#endif
#define _tf2_weapons_included

//Defines
#define MAX_WEAPON_NAME_LENGTH 32
#define MAX_DESCRIPTION_LENGTH 64
#define MAX_ATTRIBUTE_NAME_LENGTH 64
#define MAX_ATTRIBUTE_DISPLAY_LENGTH 64

//Typedefs
typedef RegisterAttribute_OnAction = function void (int client, int weapon, const char[] attrib, const char[] action, StringMap attributedata);

//Natives
native bool TF2Weapons_AllowAttributeRegisters();
native bool TF2Weapons_RegisterAttribute(char[] attrib, RegisterAttribute_OnAction onaction);
native int TF2Weapons_GiveWeapon(int client, const char[] name, bool message = false);

//Forwards
forward void TF2Weapons_OnRegisterAttributesPost();

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_weapons_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Weapons_AllowAttributeRegisters");
	MarkNativeAsOptional("TF2Weapons_RegisterAttribute");
	MarkNativeAsOptional("TF2Weapons_GiveWeapon");
}
#endif

public SharedPlugin __pl_tf2_weapons =
{
	name = "tf2-weapons",
	file = "tf2-weapons.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
