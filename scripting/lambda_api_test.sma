#include <amxmodx>
#include <lambda>

#pragma semicolon 1

public stock const PluginName[] = "[Lambda] API Test";
public stock const PluginVersion[] = "0.0.1";
public stock const PluginAuthor[] = "d3m37r4";

// #define USE_DELETE_CACHE

new Array:Reasons = Invalid_Array;
new Array:AccessGroups = Invalid_Array;

public Lambda_CoreInit() {
	server_print("Forward | Lambda_CoreInit()");
}

public Lambda_ConfigExecuted() {
	server_print("Forward | Lambda_ConfigExecuted()");
}

public Lambda_CoreLoaded() {
	/*		  EXAMPLE		*/
	new AccessToken[65], TimeToString[32];
	new EzJSON:data = Lambda_LoadCache("access-token");

	// server_print("[Lambda] API Test LambdaFolder = %s", LambdaFolder);

	if (data != EzInvalid_JSON) {
		ezjson_object_get_string(data, "token", AccessToken, charsmax(AccessToken));
		format_time(TimeToString, charsmax(TimeToString), "%m/%d/%Y - %I:%M:%S %p", ezjson_get_number(ezjson_object_get_value(data, "expires_in")));
		server_print("Forward | Lambda_CoreLoaded() | Access token = %s | Expires in = %s", AccessToken, TimeToString);
	}
	/*		EXAMPLE END		*/

	/*		  EXAMPLE		*/
	new ServerTimeToString[32];
	format_time(ServerTimeToString, charsmax(ServerTimeToString), "%m/%d/%Y - %I:%M:%S %p", Lambda_GetServerTime());
	server_print("Forward | Lambda_CoreLoaded() | Server: id = %d | server time = %s | server time diff = %d", Lambda_GetServerID(), ServerTimeToString, Lambda_GetServerTimeDiff());
	/*		EXAMPLE END		*/

	/*		  EXAMPLE		*/
	server_print("Forward | Lambda_CoreLoaded() | Reasons was loaded: %s", Lambda_ReasonsLoaded() ? "true" : "false");
	if (Lambda_ReasonsLoaded()) {
		Reasons = Lambda_GetReasons();
		server_print("Forward | Lambda_CoreLoaded() | Reasons array size: %d", ArraySize(Reasons));

		for (new i, reasonData[ReasonStruct], arrSize = ArraySize(Reasons); i < arrSize; i++) {
			ArrayGetArray(Reasons, i, reasonData);
			server_print("------------------------------- id = %d | title = %s | time = %d", reasonData[ReasonID], reasonData[ReasonTitle], reasonData[ReasonTime]);
		}
	}
	/*		EXAMPLE END		*/

	/*		  EXAMPLE		*/
	server_print("Forward | Lambda_CoreLoaded() | Access Groups was loaded: %s", Lambda_AccessGroupsLoaded() ? "true" : "false");
	if (Lambda_AccessGroupsLoaded()) {
		AccessGroups = Lambda_GetAccessGroups();
		server_print("Forward | Lambda_CoreLoaded() | Access Groups array size: %d", ArraySize(AccessGroups));

		for (new i, accessGroupData[AccessGroupStruct], arrSize = ArraySize(AccessGroups); i < arrSize; i++) {
			ArrayGetArray(AccessGroups, i, accessGroupData);
			server_print("------------------------------- id = %d | title = %s | flags = %s | prefix = %s", 
				accessGroupData[AccessGroupID], 
				accessGroupData[AccessGroupTitle], 
				accessGroupData[AccessGroupFlags], 
				accessGroupData[AccessGroupPrefix]
			);
		}
	}
	/*		EXAMPLE END		*/
}

#if defined USE_DELETE_CACHE
public OnConfigsExecuted() {
	/*		  EXAMPLE		*/
	if (Lambda_DeleteAllCache()) {
		server_print("Forward | Lambda_CoreLoaded() | All cache deleted");
	}
	/*		EXAMPLE END		*/
}
#endif

public plugin_end() {
	if (Reasons != Invalid_Array) {
		ArrayDestroy(Reasons);
	}

	if (AccessGroups != Invalid_Array) {
		ArrayDestroy(AccessGroups);
	}
}