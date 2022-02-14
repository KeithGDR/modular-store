#if defined _modularstore_distributions_included
  #endinput
#endif
#define _modularstore_distributions_included

//Natives
//native int ModularStore_GetCurrency(int client, const char[] currency = NULL_STRING);

//Forwards

#if !defined REQUIRE_PLUGIN
public void __pl_modularstore_distributions_SetNTVOptional()
{
	//MarkNativeAsOptional("ModularStore_GetCurrency");
}
#endif

public SharedPlugin __pl_modularstore_distributions =
{
	name = "modularstore-distributions",
	file = "store-distributions.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
