#include <amxmodx>
#include <lambda>
#include <reapi>

#pragma semicolon 1

const Float:CMD_DELAY	= 0.8;
const ATTEMPTS_COUNT	= 3;

// See Reunion API:
// https://github.com/s1lentq/reapi/blob/e808d72075f5018336c15955f8d2d68e8f2cc084/reapi/include/reunion_api.h
static const ClientAuthType[client_auth_type][] = {
	"auth_none",
	"auth_dproto",
	"auth_steam",
	"auth_steamemu",
	"auth_revemu",
	"auth_oldrevemu",
	"auth_hltv",
	"auth_sc2009",
	"auth_avsmp",
	"auth_sxei",
	"auth_revemu2013",
	"auth_sse3",
};

/**
 * API routes
 */
#define API_GAME_SERVER_ROUTE_PLAYER_CONNECT			fmt("servers/%d/players/connect", ServerID)
#define API_GAME_SERVER_ROUTE_PLAYER_ASSIGN(%0)			fmt("servers/%d/players/%d/assign", ServerID, PlayersData[%0][PlayerID])
#define API_GAME_SERVER_ROUTE_PLAYER_DISCONNECT(%0)		fmt("servers/%d/players/%d/disconnect", ServerID, PlayersData[%0][PlayerID])

enum FwdStruct {
	FwdPlayerLoading,
	FwdPlayerLoaded,
	FwdPlayerDisconnecting,
	// FwdDisconnected,
};
new Forwards[FwdStruct];
new FReturn;

enum {
	StatusNone = 0,
	StatusWaiting,
	StatusLoading,
	StatusLoaded,
};

enum any:PlayerStruct {
	PlayerStatus,
	PlayerID,
	PlayerAuthID[MAX_AUTHID_LENGTH],
	client_auth_type:PlayerAuthType,
	PlayerSessionID,
	PlayerGameUserID,
	// PlayerImmunity,
	Float:PlayerFloodTime,
	PlayerAttemptsCount	
};

new PlayersData[MAX_PLAYERS + 1][PlayerStruct];
new ServerID;


#define CheckPlayerStatus(%0,%1) bool:(PlayersData[%0][PlayerStatus] == %1)

#include "lambda/misc.inl"
#include "lambda/player_natives.inl"

public plugin_init() {
	register_plugin("[Lambda] Players Management", LAMBDA_VERSION_STR, "d3m37r4");

	if (!is_rehlds()) {
		set_fail_state("ReHLDS: isn't available!");
	}

	if (!has_reunion()) {
		set_fail_state("Reunion: isn't available!");
	}

	registerCommands();
	registerForwards();
	RegisterHookChain(RH_SV_DropClient, "SV_DropClient_Post", true);
	getPlayersData();
}

public Lambda_CoreLoaded() {
	ServerID = Lambda_GetServerID();
}

public client_putinserver(id) {
	makeLoadPlayerRequest(id);
}

public SV_DropClient_Post(const id) {
	makeDisconnectPlayerRequest(id);
}

public CmdAssign(id) {
	new Float:gametime = get_gametime();

	if (gametime < PlayersData[id][PlayerFloodTime] + CMD_DELAY) {
		if (++PlayersData[id][PlayerAttemptsCount] >= ATTEMPTS_COUNT) {
			console_print(id, "* Stop flooding the server by sending a command!");
			return PLUGIN_HANDLED;
		}
	} else if (PlayersData[id][PlayerAttemptsCount]) {
		PlayersData[id][PlayerAttemptsCount] = 0;
	}

	PlayersData[id][PlayerFloodTime] = gametime;

	if (CheckPlayerStatus(id, StatusLoaded) && PlayersData[id][PlayerID]) {
		console_print(id, "* Access has already been granted!");
		return PLUGIN_HANDLED;
	}

	new token[36];
	read_args(token, charsmax(token));
	remove_quotes(token);

	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_number(data, "player_id", PlayersData[id][PlayerID]);
	grip_json_object_set_string(data, "token", token);

	Lambda_MakeRequest(API_GAME_SERVER_ROUTE_PLAYER_ASSIGN(PlayersData[id][PlayerID]), data, "OnPlayerAssigned", id);
	// makeRequest("player/assign", data, PluginId, Functions[FnOnAssigned], get_user_userid(id));
	// grip_destroy_json_value(data);

	return PLUGIN_HANDLED;
}

public plugin_end() {
	new GripJSONValue:data = grip_json_init_object();
	new GripJSONValue:array = grip_json_init_array();

	for (new id = 1, GripJSONValue:object; id <= MaxClients; id++) {
		if (!CheckPlayerStatus(id, StatusLoaded)) {
			continue;
		}

		object = grip_json_init_object();
		grip_json_object_set_number(object, "player_id", PlayersData[id][PlayerID]);
		grip_json_object_set_number(object, "session_id", PlayersData[id][PlayerSessionID]);
		grip_json_object_set_string(object, "authid", PlayersData[id][PlayerAuthID]);
		grip_json_object_set_number(object, "auth_type", PlayersData[id][PlayerAuthType]);
		grip_json_array_append_value(array, object);
		grip_destroy_json_value(object);
	}

	grip_json_object_set_value(data, "players", array);
	grip_destroy_json_value(array);

	Lambda_SaveCache("players", data);
	grip_destroy_json_value(data);
}

public OnPlayerConnected(const LambdaResponseStatus:status, GripJSONValue:data, const id) {
	CHECK_RESPONSE_STATUS(status)

	if (id == 0) {
		return;
	}

	if (!data || grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	PlayersData[id][PlayerID] = grip_json_object_get_number(data, "player_id");
	PlayersData[id][PlayerSessionID] = grip_json_object_get_number(data, "session_id");
	PlayersData[id][PlayerGameUserID] = get_user_userid(id);
	PlayersData[id][PlayerStatus] = StatusLoaded;

	log_amx("Player (player_id = %d | session_id = %d) loaded!", PlayersData[id][PlayerID], PlayersData[id][PlayerSessionID]);

	ExecuteForward(Forwards[FwdPlayerLoaded], FReturn, id, data);
}

public OnPlayerAssigned(const LambdaResponseStatus:status, GripJSONValue:data, const id) {
	CHECK_RESPONSE_STATUS(status)
	// if (status != LambdaResponseStatusOk) {
	// 	log_amx("Bad response (status #%d)", status);
	// 	return;
	// }

	if (id == 0) {
		return;
	}

	if (!data || grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	// Индекс аккаунта пользователя на сайте, нужно заменить название PlayerUserID.
	// Players[id][PlayerUserId] = grip_json_object_get_number(data, "user_id");
}

makeLoadPlayerRequest(id) {
	if (!isValidPlayer(id)) {
		return;
	}

	new name[MAX_NAME_LENGTH], authid[MAX_AUTHID_LENGTH], ip[MAX_IP_LENGTH];

	get_user_name(id, name, charsmax(name));
	get_user_authid(id, authid, charsmax(authid));
	get_user_ip(id, ip, charsmax(ip), 1);

	new client_auth_type:authtype = REU_GetAuthtype(id);

	PlayersData[id][PlayerStatus] = StatusWaiting;

	for (new player = 1; player <= MaxClients; player++) {
		if (equali(authid, PlayersData[player][PlayerAuthID]) && authtype == PlayersData[player][PlayerAuthType]) {
			PlayersData[player][PlayerStatus] = StatusLoaded;
			log_amx("Player (player_id = %d | session_id = %d) loaded!", PlayersData[id][PlayerID], PlayersData[id][PlayerSessionID]);
			break;
		}
	}

	if (!canBeLoadedPlayer(id)) {
		return;
	}

	// arrayset(PlayersData[id], 0, sizeof PlayersData[]);
	ExecuteForward(Forwards[FwdPlayerLoading], FReturn, id);
	
	if (FReturn == PLUGIN_HANDLED) {
		return;
	}



	// for (new player = 1; player <= MaxClients; player++) {
	// 	if (equali(authid, PlayersData[player][PlayerAuthID]) && authtype == PlayersData[player][PlayerAuthType]) {
	// 		PlayersData[player][PlayerStatus] = StatusLoaded;
	// 		log_amx("Player (player_id = %d | session_id = %d) loaded!", PlayersData[id][PlayerID], PlayersData[id][PlayerSessionID]);
	// 		break;
	// 	}
	// }

	// if (!CheckPlayerStatus(id, StatusLoaded)) {
		new GripJSONValue:data = grip_json_init_object();

		grip_json_object_set_string(data, "name", name);
		grip_json_object_set_string(data, "authid", authid);
		grip_json_object_set_string(data, "ip", ip);
		grip_json_object_set_string(data, "auth_type", ClientAuthType[authtype]);

		// log_amx("Player #%d <authtype: %s> <authid: %s> <ip: %s> <name: %s> <id: %d> <session: %d> connecting to server.", get_user_userid(id), ClientAuthType[authtype], authid, ip, name, PlayersData[id][PlayerID], PlayersData[id][PlayerSessionID]);
		Lambda_MakeRequest(API_GAME_SERVER_ROUTE_PLAYER_CONNECT, data, "OnPlayerConnected", id);
	// }
}

makeDisconnectPlayerRequest(id) {
	if (PlayersData[id][PlayerStatus] != StatusLoaded || PlayersData[id][PlayerID] <= 0) {
		arrayset(PlayersData[id], 0, sizeof PlayersData[]);
		return;
	}

	ExecuteForward(Forwards[FwdPlayerDisconnecting], FReturn, id);
	if (FReturn == PLUGIN_HANDLED) {
		arrayset(PlayersData[id], 0, sizeof PlayersData[]);
		return;
	}

	// log_amx("Player #%d <player: %d> <session: %d> <user: %d> disconnecting from server", get_user_userid(id), Players[id][PlayerId], PlayersData[id][PlayerSessionID], Players[id][PlayerUserId]);
	// log_amx("Player #%d <player: %d> <session: %d> disconnecting from server", get_user_userid(id), PlayersData[id][PlayerID], PlayersData[id][PlayerSessionID]);

	new name[MAX_NAME_LENGTH];
	get_user_name(id, name, charsmax(name));

	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_string(data, "name", name);

	Lambda_MakeRequest(API_GAME_SERVER_ROUTE_PLAYER_DISCONNECT(PlayersData[id][PlayerID]), data);
	arrayset(PlayersData[id], 0, sizeof PlayersData[]);

	return;
}

registerCommands() {
	register_clcmd("lambda_assign", "CmdAssign");
}

registerForwards() {
	Forwards[FwdPlayerLoading] = CreateMultiForward("Lambda_PlayerLoading", ET_STOP, FP_CELL);
	Forwards[FwdPlayerLoaded] = CreateMultiForward("Lambda_PlayerLoaded", ET_IGNORE, FP_CELL, FP_CELL);
	Forwards[FwdPlayerDisconnecting] = CreateMultiForward("Lambda_PlayerDisconnecting", ET_STOP, FP_CELL);
}

bool:isValidPlayer(const index) {
	return bool:(!is_user_bot(index) && !is_user_hltv(index));
}

bool:canBeLoadedPlayer(const index) {
	return bool:(PlayersData[index][PlayerStatus] != StatusLoading && PlayersData[index][PlayerStatus] != StatusLoaded /*&& !is_user_bot(index) && !is_user_hltv(index)*/);
}

parsePlayersData(const GripJSONValue:data) {
	new GripJSONValue:tmp = grip_json_object_get_value(data, "players");
	for (new i, n = grip_json_array_get_count(tmp), id, GripJSONValue:element; i < n; i++) {
		id = i + 1;
		element = grip_json_array_get_value(tmp, i);

		if (grip_json_get_type(element) == GripJSONObject) {
			PlayersData[id][PlayerID] = grip_json_object_get_number(element, "player_id");
			PlayersData[id][PlayerSessionID] = grip_json_object_get_number(element, "session_id");
			grip_json_object_get_string(element, "authid", PlayersData[id][PlayerAuthID], charsmax(PlayersData[][PlayerAuthID]));
			PlayersData[id][PlayerAuthType] = client_auth_type:grip_json_object_get_number(element, "auth_type");
		}

		grip_destroy_json_value(element);
	}

	grip_destroy_json_value(tmp);
}

bool:getPlayersData() {
	new GripJSONValue:data = Lambda_LoadCache("players");
	if (data == Invalid_GripJSONValue) {
		return false;
	}

	parsePlayersData(data);
	grip_destroy_json_value(data);

	return true;
}