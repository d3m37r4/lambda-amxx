#if defined _lambda_included
	#endinput
#endif
#define _lambda_included

#pragma reqlib Lambda_AMXX_API_Core
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib Lambda_AMXX_API_Core
#endif

#include <grip>
#include <lambda_consts>
#include <lambda_version>

/**
 * Called when preparing Lambda core for operations.
 *
 * @noreturn
 */
forward Lambda_CoreInit();

/**
 * Called when core is initiated and config are done executing.
 *
 * @noreturn
 */
forward Lambda_ConfigExecuted();

/**
 * Called after loading core, executed configuration, authorization, and receiving primary information when map has loaded.
 *
 * @noreturn
 */
forward Lambda_CoreLoaded();

/**
 * Called when a player is loading.
 *
 * @param index			Client index
 *
 * @return				PLUGIN_CONTINUE to let the client load.
 *						PLUGIN_HANDLED to prevent the client to load.
 */
forward Lambda_PlayerLoading(const index);

/**
 * Called when a player was loaded.
 *
 * @param index			Client index
 * @param data			
 *
 * @noreturn
 */
forward Lambda_PlayerLoaded(const index, GripJSONValue:data);

/**
 * Called when a player is disconnecting.
 *
 * @param index			Client index
 *
 * @return              PLUGIN_CONTINUE to let saving information about player's disconnection.
 *                      PLUGIN_HANDLED to prevent saving information about player's disconnection.
 */
forward Lambda_PlayerDisconnecting(const index);


/**
 * Makes request to API.
 *
 * @note				There is no need to use the native grip_destroy_json_value() to clean up after creating the request.
 *
 * @param endpoint		Part of path to api resource
 * @param data			Data provided to API
 * @param callback		Callback name which will be called
 * @param param			Parameter which will be provided in callback
 *
 * @return				ID of request, INVALID_REQUEST_ID if error occurred.
 * @error				If an invalid number of arguments is set, or API is not enabled, or an
 *						invalid callback function is provided, an error will be thrown.
 */
native Lambda_MakeRequest(const endpoint[], GripJSONValue:data, const callback[] = "", const param = 0);

/**
 * Gets server index.
 *
 * @noparam
 *
 * @return				Server index
 */
native Lambda_GetServerID();

/**
 * Gets time on api part in unix timestamp.
 *
 * @noparam
 *
 * @return				Unix timestamp
 */
native Lambda_GetServerTime();

/**
 * Gets diff from server time and api part time in seconds.
 *
 * @noparam
 *
 * @return				Seconds
 */
native Lambda_GetServerTimeDiff();

/**
 * Loads saved cache by name.
 *
 * @param name			JSON name
 *
 * @return				JSON handle on success, Invalid_GripJSONValue otherwise.
 * @error				If an invalid number of arguments is set, an error will be thrown.
 */
native GripJSONValue:Lambda_LoadCache(const name[]);

/**
 * Saves cache by name.
 *
 * @note				Needs to be destroyed GripJSONValue:data using grip_destroy_json_value() native.
 *
 * @param name			JSON name
 * @param data			JSON handle
 *
 * @return				true on success, false otherwise.
 * @error				If an invalid number of arguments is set, an error will be thrown.
 */
native bool:Lambda_SaveCache(const name[], const GripJSONValue:data);

/**
 * Deletes saved cache by name.
 *
 * @param name			JSON name
 *
 * @return				true on success, false otherwise.
 * @error				If an invalid number of arguments is set, an error will be thrown.
 */
native bool:Lambda_DeleteCache(const name[]);

/**
 * Deletes entire cache.
 *
 * @noparam
 *
 * @return				true on success, false otherwise.
 */
native bool:Lambda_DeleteAllCache();

/**
 * Checking whether reasons for this server have been received.
 *
 * @noparam
 *
 * @return				true if reasons are loaded, false otherwise.
 */
native bool:Lambda_ReasonsLoaded();

/**
 * Gets reasons for this server.
 *
 * @noparam
 *
 * @return				Array handle, otherwise will return Invalid_Array.
 */
native Array:Lambda_GetReasons();

/**
 * Checking whether access groups for this server have been received.
 *
 * @noparam
 *
 * @return				true if access groups are loaded, false otherwise.
 */
native bool:Lambda_AccessGroupsLoaded();

/**
 * Gets access groups for this server.
 *
 * @noparam
 *
 * @return				Array handle, otherwise will return Invalid_Array.
 */
native Array:Lambda_GetAccessGroups();

/**
 * Makes request to API.
 *
 * @param command       Command name
 * @param callback      Callback name which will be called
 *
 * @return              ID of command, -1 if error occurred
 * @error               If an invalid number of arguments is set, or an
 *                      invalid callback function is provided, an error will be thrown.
 */
// native GMX_RegisterCommand(const command[], const callback[]);

/**
 * Makes request to API.
 *
 * @param level         Logging level
 * @param fmt           Formatting rules
 * @param ...           Variable number of formatting parameters
 *
 * @return              1 on success, 0 otherwise
 */
// native GMX_Log(const GmxLogLevel:level, const fmt[], any:...);

/**
 * Checks if player is loaded.
 *
 * @param id            Client index
 *
 * @return              true if loaded, false otherwise
 * @error               If an invalid number of arguments is set, an error will be thrown.
 */
// native bool:GMX_PlayerIsLoaded(const id);

/**
 * Returns player's ID.
 *
 * @param id            Client index
 *
 * @return              Player's ID if it was found
 * @error               If the index is not within the range of 1 to MaxClients,
 *                      or an invalid number of arguments is set, or player is not
 *                      loaded, an error will be thrown.
 */
// native GMX_PlayerGetPlayerId(const id);

/**
 * Returns player's user ID.
 *
 * @param id            Client index
 *
 * @return              Player's user ID if it was found
 * @error               If the index is not within the range of 1 to MaxClients,
 *                      or an invalid number of arguments is set, or player is not
 *                      loaded, an error will be thrown.
 */
// native GMX_PlayerGetUserId(const id);

/**
 * Returns player's session ID.
 *
 * @param id            Client index
 *
 * @return              Player's session ID if it was found
 * @error               If the index is not within the range of 1 to MaxClients,
 *                      or an invalid number of arguments is set, or player is not
 *                      loaded, an error will be thrown.
 */
// native GMX_PlayerGetSessionId(const id);

/**
 * Returns player's immunity level.
 *
 * @param id            Client index
 *
 * @return              Player's immunity level if it was found
 * @error               If the index is not within the range of 1 to MaxClients,
 *                      or an invalid number of arguments is set, or player is not
 *                      loaded, an error will be thrown.
 */
// native GMX_PlayerGetImmunity(const id);

/**
 * This is callback from Lambda AMXX Core that gives major/minor versions for verifying compatibility for Lambda versions.
 * Do not modify this!
 */
public __lambda_version_check(const majorVersion, const minorVersion) {
	if (majorVersion != LAMBDA_VERSION_MAJOR) {
		set_fail_state("API major version mismatch; expected %d, real %d", LAMBDA_VERSION_MAJOR, majorVersion);
		return;
	}

	if (minorVersion < LAMBDA_VERSION_MINOR){
		set_fail_state("API minor version mismatch; expected at least %d, real %d", LAMBDA_VERSION_MINOR, minorVersion);
		return;
	}
}
