#if defined _modularstore_packages_included
  #endinput
#endif
#define _modularstore_packages_included

//Natives

//Forwards


#if !defined REQUIRE_PLUGIN
public void __pl_modularstore_packages_SetNTVOptional()
{
	//MarkNativeAsOptional("");
}
#endif

public SharedPlugin __pl_modularstore_packages =
{
	name = "modularstore-packages",
	file = "store-packages.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
