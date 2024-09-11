#include <amxmodx>
// #include <fakemeta>
// #include <reapi>
#include <lambda>

#pragma semicolon 1

public const LambdaFolder[] = "lambda";
public const LambdaCacheFolder[] = "lambda_cache";
public const LambdaCoreCfg[] = "lambda-core.json";

const TaskPingIndex = 100;
const Float:PingDelay = 60.0;

/**
 * API routes
 */
#define API_GAME_SERVER_ROUTE_AUTH	"servers/auth"
#define API_GAME_SERVER_ROUTE_INFO	fmt("servers/%d/info", ServerData[ServerID])
#define API_GAME_SERVER_ROUTE_PING	fmt("servers/%d/ping", ServerData[ServerID])

enum any:RequestStruct {
	RequestEndPoint[256],
	EzJSON:RequestData,
	RequestPluginId,
	RequestFuncId,
	RequestParam,
	bool:RequestNotProcessed,
};

enum FwdStruct {
	FwdCoreInit,
	FwdConfigExecuted,
	FwdCoreLoaded,
};
new Forwards[FwdStruct];

enum FUNC {
	FuncOnAuthorization,
	FuncOnInfoResponse,
	FuncOnPing,
};
new Functions[FUNC];

new LastNotProcessedRequest;
new EzJSON:RequestOptions = EzInvalid_JSON;
new Array:RequestStorage = Invalid_Array;
new RequestUrl[256];

enum any:ServerStruct {
	ServerID,
	ServerTime,
	ServerTimeDiff,
	ServerIP[MAX_IP_LENGTH],
	ServerPort,
	ServerAuthToken[65],
	ServerAccessToken[65],
	ServerAccessTokenExpiresIn,
};
new ServerData[ServerStruct];

new CachePath[PLATFORM_MAX_PATH];

new Array:ReasonsData = Invalid_Array;
new ReasonsNextUpdate;
new bool:UpdateReasons;

new Array:AccessGroupsData = Invalid_Array;
new AccessGroupsNextUpdate;
new bool:UpdateAccessGroups;

new PluginId;

#include "lambda/misc.inl"
#include "lambda/core_natives.inl"

public plugin_precache() {
	PluginId = register_plugin("[Lambda] Core", LAMBDA_VERSION_STR, "d3m37r4");

	registerForwards();
	getCachePath(CachePath, charsmax(CachePath));
	getPluginFunctions();

	register_srvcmd("lambda_reload_core", "CmdReloadCore");
	register_srvcmd("lambda_remove_cache", "CmdRemoveCache");

	if (loadConfig()) {
		UpdateReasons = !getReasons();
		UpdateAccessGroups = !getAccessGroups();
		getAccessToken() ? makeInfoRequest() : makeAuthorizationRequest();
	}
}

public plugin_init() {
	// server_print("plugin_init");
}

public CmdReloadCore() {
	if (loadConfig()) {
		log_amx("Core reload initialized.");

		remove_task(TaskPingIndex);
		makeAuthorizationRequest();
	}
}

public CmdRemoveCache() {
	if (deleteAllCache()) {
		log_amx("Cache was successfully cleared.");
		return PLUGIN_HANDLED;
	}

	log_amx("Something went wrong!");
	return PLUGIN_CONTINUE;
}

public plugin_end() {
	// for (new i, items = ArraySize(RequestStorage), request[RequestStruct]; i < items; i++) {
	// 	ArrayGetArray(RequestStorage, i, request, sizeof request);
	// 	log_amx("plugin_end | data = %d", request[RequestData]);
	// 	ezjson_free(request[RequestData]);
	// }

	// if (RequestOptions != EzInvalid_JSON) {
	// 	ezjson_free(RequestOptions);
	// }
}

public OnAuthorization(const LambdaResponseStatus:status, EzJSON:data) {
	CHECK_RESPONSE_STATUS(status)

	if (!data || ezjson_get_type(data) != EzJSONObject) {
		return;
	}

	new EzJSON:tmp = ezjson_object_get_value(data, "access_token");
	parseAccessToken(tmp);
	saveCache("access-token", tmp);
	ezjson_free(tmp);

	log_amx("Server has successfully authorized.");

	if (isRequestIndexValid(LastNotProcessedRequest)) {
		new request[RequestStruct];
		ArrayGetArray(RequestStorage, LastNotProcessedRequest, request, sizeof request);
		// ArrayDeleteItem(RequestStorage, LastNotProcessedRequest);

		if (request[RequestNotProcessed] && request[RequestFuncId] != Functions[FuncOnAuthorization]) {
			log_amx("Attempt to send the last raw request (id: %d).", LastNotProcessedRequest);

			makeRequest(request[RequestEndPoint], request[RequestData], request[RequestPluginId], request[RequestFuncId], request[RequestParam]);
			LastNotProcessedRequest = -1;
		}
	}
}

public OnInfoResponse(const LambdaResponseStatus:status, EzJSON:data) {
	CHECK_RESPONSE_STATUS(status)

	if (!data || ezjson_get_type(data) != EzJSONObject) {
		return;
	}

	// ServerData[ServerID] = ezjson_object_get_number(data, "server_id");
	ServerData[ServerTime] = ezjson_object_get_number(data, "time");
	ServerData[ServerTimeDiff] = get_systime(0) - ServerData[ServerTime];

	if (UpdateReasons) {
		new EzJSON:tmp = ezjson_object_get_value(data, "reasons_data");
		parseReasons(tmp);
		saveCache("reasons", tmp);
		zjson_free(tmp);
	}

	if (UpdateAccessGroups) {
		new EzJSON:tmp = ezjson_object_get_value(data, "access_groups_data");
		parseAccessGroups(tmp);
		saveCache("access_groups", tmp);
		zjson_free(tmp);
	}

	ExecuteForward(Forwards[FwdCoreLoaded]);
	log_amx("OnInfoResponse | status = ok");

	set_task(PingDelay, "TaskPing", .id = TaskPingIndex, .flags = "b");
}

public OnPing(const LambdaResponseStatus:status, EzJSON:data) {
	CHECK_RESPONSE_STATUS(status)
	// if (status != LambdaResponseStatusOk) {
	// 	log_amx("Bad response (status code #%d)", status);
	// 	remove_task(TaskPingIndex);
	// 	return;
	// }

	if (!data || ezjson_get_type(data) != EzJSONObject) {
		return;
	}

	// https://github.com/gm-x/gmx-amxx/blob/1bd75e46b20f5ec98e2afd676d321bf63aefa62b/scripting/gmx.sma#L362-L398
	log_amx("OnPing | status = ok");
}

public TaskPing() {
	makePingRequest();
}

makeAuthorizationRequest() {
	new EzJSON:data = ezjson_init_object();
	ezjson_object_set_string(data, "port", ServerData[ServerPort]);
	ezjson_object_set_string(data, "auth_token", ServerData[ServerAuthToken]);
	makeRequest(API_GAME_SERVER_ROUTE_AUTH, data, PluginId, Functions[FuncOnAuthorization]);
}

makeInfoRequest() {
	new EzJSON:data = ezjson_init_object();
	ezjson_object_set_string(data, "map", MapName);
	ezjson_object_set_number(data, "max_players", MaxClients);
	UpdateReasons && ezjson_object_set_bool(data, "update_reasons", true);
	UpdateAccessGroups && ezjson_object_set_bool(data, "update_access_groups", true);
	makeRequest(API_GAME_SERVER_ROUTE_INFO, data, PluginId, Functions[FuncOnInfoResponse]);
}

makePingRequest() {
	new EzJSON:data = ezjson_init_object();
	// ezjson_object_set_number(data, "num_players", get_playersnum());
	// https://github.com/gm-x/gmx-amxx/blob/1bd75e46b20f5ec98e2afd676d321bf63aefa62b/scripting/gmx.sma#L236-L242
	makeRequest(API_GAME_SERVER_ROUTE_PING, data, PluginId, Functions[FuncOnPing]);
	// https://github.com/gm-x/gmx-amxx/blob/1bd75e46b20f5ec98e2afd676d321bf63aefa62b/scripting/gmx.sma#L245
}

makeRequest(const endpoint[], EzJSON:data = EzInvalid_JSON, const pluginID = INVALID_PLUGIN_ID, const funcID = INVALID_PLUGIN_ID, const param = 0) {
	if (RequestOptions == EzInvalid_JSON) {
		RequestOptions = ezhttp_create_options();
		ezhttp_option_set_header(RequestOptions, "Content-Type", "application/json");
		ezhttp_option_set_user_agent(RequestOptions, "Lambda");
	}

	if (funcID != Functions[FuncOnAuthorization]) {
		ezhttp_option_set_header(RequestOptions, "X-Access-Token", ServerData[ServerAccessToken]);
	}

	new request[RequestStruct];
	copy(request[RequestEndPoint], charsmax(request[RequestEndPoint]), endpoint);
	request[RequestData] = data;
	request[RequestPluginId] = pluginID;
	request[RequestFuncId] = funcID;
	request[RequestParam] = param;

	if (RequestStorage == Invalid_Array) {
		RequestStorage = ArrayCreate(RequestStruct);
	}

	new id = ArrayPushArray(RequestStorage, request, sizeof request);

	ezhttp_option_set_body_from_json(RequestOptions, data);
	ezjson_free(RequestOptions);

	ezhttp_post(fmt("%s/api/%s", RequestUrl, endpoint), "RequestHandler", RequestOptions);

	return id;
}

public RequestHandler(EzHttpRequest:id) {
	if (!isRequestIndexValid(id)) {
		log_amx("Bad request (id #%d).", id);
		return;
	}

	new request[RequestStruct], error[256];
	ArrayGetArray(RequestStorage, id, request, sizeof request);

	new EzHttpErrorCode:code = ezhttp_get_error_code(id);
	if (code != EZH_OK) {
		request[RequestNotProcessed] = true;
		LastNotProcessedRequest = id;

		log_amx("Request (id #%d) finished with '%d' status.", id, code);
/*
		switch (code) {
			case EZH_CONNECTION_FAILURE: {
				log_amx("Request (id #%d) was canceled.", id);
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusCanceled, EzInvalid_JSON, request[RequestParam]);
			}
			case EZH_REQUEST_CANCELLED: {
				log_amx("Request (id #%d) was canceled.", id);
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusCanceled, EzInvalid_JSON, request[RequestParam]);
			}
			case EZH_OPERATION_TIMEDOUT: {
				log_amx("Request (id #%d) finished with timeout.", id);
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusTimeout, EzInvalid_JSON, request[RequestParam]);
			}
			case EZH_NETWORK_SEND_FAILURE: {
				ezjson_free(RequestOptions);
				RequestOptions = EzInvalid_JSON;

				log_amx("Сервер неавторизован, возможно истек срок действия токена доступа! будет произведена попытка авторизации!");
				makeAuthorizationRequest();
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusUnauthorized, EzInvalid_JSON, request[RequestParam]);
			}
			case EZH_INTERNAL_ERROR: {
				ezhttp_get_error_message(id, error, charsmax(error));
				log_amx("Request (id #%d) finished with error: '%s'.", id, error);
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusError, EzInvalid_JSON, request[RequestParam]);
				//callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusServerError, EzInvalid_JSON, request[RequestParam]);
			}
			default: {
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusUnknownError, EzInvalid_JSON, request[RequestParam]);
			}
		}
*/
		ArraySetArray(RequestStorage, id, request, sizeof request);
		return;
	}

	new EzJSON:data = ezhttp_parse_json_response(id);
	if (data == EzInvalid_JSON) {
		ezhttp_get_error_message(id, error, charsmax(error));
		log_amx("Error parse response: '%s'.", error);
		callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusBadResponse, EzInvalid_JSON, request[RequestParam]);
		return;
	}

	request[RequestNotProcessed] = false;

	callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusOk, data, request[RequestParam]);
	ezjson_free(data);
	ArraySetArray(RequestStorage, id, request, sizeof request);
}

callHandlerFunc(const pluginID, const funcID, const LambdaResponseStatus:status, const EzJSON:data, const param) {
	if (pluginID != INVALID_PLUGIN_ID && funcID != INVALID_PLUGIN_ID && callfunc_begin_i(funcID, pluginID) == 1) {
		callfunc_push_int(_:status);
		callfunc_push_int(_:data);
		callfunc_push_int(param);
		callfunc_end();
	}
}

getPluginFunctions() {
	Functions[FuncOnAuthorization] = get_func_id("OnAuthorization");
	Functions[FuncOnInfoResponse] = get_func_id("OnInfoResponse");
	Functions[FuncOnPing] = get_func_id("OnPing");
}

registerForwards() {
	ExecuteForward(Forwards[FwdCoreInit] = CreateMultiForward("Lambda_CoreInit", ET_IGNORE));
	Forwards[FwdConfigExecuted] = CreateMultiForward("Lambda_ConfigExecuted", ET_IGNORE);
	Forwards[FwdCoreLoaded] = CreateMultiForward("Lambda_CoreLoaded", ET_IGNORE);
}

bool:loadConfig() {
	new filePath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));
	format(filePath, charsmax(filePath), "%s/%s/%s", filePath, LambdaFolder, LambdaCoreCfg);

	if (!file_exists(filePath)) {
		set_fail_state("Could not open %s", filePath);
		return false;
	}

	new error[128];
	new EzJSON:cfg = ezjson_parse(filePath, true);

	if (cfg == EzInvalid_JSON) {
		ezhttp_get_error_message(cfg, error, charsmax(error));
		set_fail_state("Could not open '%s'. Error '%s'.", filePath, error);
		return false;
	}

	if (ezjson_get_type(cfg) != EzJSONObject) {
		ezjson_free(cfg);
		set_fail_state("Could not open '%s'. Bad format.", filePath);
		return false;
	}

	ezjson_object_get_string(cfg, "request-url", RequestUrl, charsmax(RequestUrl));
	ezjson_object_get_string(cfg, "server-ip", ServerData[ServerIP], charsmax(ServerData[ServerIP]));
	ezjson_object_get_string(cfg, "server-auth-token", ServerData[ServerAuthToken], charsmax(ServerData[ServerAuthToken]));
	ServerData[ServerPort] = ezjson_object_get_number(cfg, "server-port");

	log_amx("Loading configuration. Request URL is '%s'", RequestUrl);
	ezjson_free(cfg);

	ExecuteForward(Forwards[FwdConfigExecuted]);
	return true;
}

bool:isRequestIndexValid(const index) {
	return bool:(0 <= index && index < ArraySize(RequestStorage));
}

parseAccessToken(const EzJSON:data) {
	ezjson_object_get_string(data, "token", ServerData[ServerAccessToken], charsmax(ServerData[ServerAccessToken]));
	ServerData[ServerAccessTokenExpiresIn] = ezjson_object_get_number(data, "expires_in");
	ServerData[ServerID] = ezjson_object_get_number(data, "server_id");
}

bool:isAccessTokenValid() {
	if (ServerData[ServerAccessToken][0] == EOS || ServerData[ServerAccessTokenExpiresIn] < get_systime()) {
		return false;
	}

	return true;
}

bool:getAccessToken() {
	new EzJSON:data = loadCache("access-token");
	if (data == EzInvalid_JSON) {
		return false;
	}

	parseAccessToken(data);
	ezjson_free(data);

	if (!isAccessTokenValid()) {
		return false;
	}

	return true;
}

parseReasons(const EzJSON:data) {
	if (ReasonsData == Invalid_Array) {
		ReasonsData = ArrayCreate(ReasonStruct);
	}

	new EzJSON:tmp = ezjson_object_get_value(data, "reasons");
	for (new i, n = ezjson_array_get_count(tmp), EzJSON:element, reason[ReasonStruct]; i < n; i++) {
		element = ezjson_array_get_value(tmp, i);
		if (ezjson_is_object(element)) {
			reason[ReasonID] = ezjson_object_get_number(element, "id");
			ezjson_object_get_string(element, "title", reason[ReasonTitle], charsmax(reason[ReasonTitle]));
			reason[ReasonTime] = ezjson_object_get_number(element, "time");

			ArrayPushArray(ReasonsData, reason, sizeof reason);
		}
		ezjson_free(element);
	}

	ReasonsNextUpdate = ezjson_object_get_number(data, "next_update");
	ezjson_free(tmp);
}

bool:isReasonsValid() {
	if (ReasonsNextUpdate < get_systime()) {
		return false;
	}

	return true;
}

bool:getReasons() {
	new EzJSON:data = loadCache("reasons");
	if (data == EzInvalid_JSON) {
		return false;
	}

	parseReasons(data);
	ezjson_free(data);

	if (!isReasonsValid()) {
		return false;
	}

	return true;
}

parseAccessGroups(const EzJSON:data) {
	if (AccessGroupsData == Invalid_Array) {
		AccessGroupsData = ArrayCreate(AccessGroupStruct);
	}

	new EzJSON:tmp = ezjson_object_get_value(data, "access_groups");
	for (new i, n = gezjson_array_get_count(tmp), EzJSON:element, accessGroup[AccessGroupStruct]; i < n; i++) {
		element = ezjson_array_get_value(tmp, i);
		if (ezjson_is_object(element)) {
			accessGroup[AccessGroupID] = ezjson_object_get_number(element, "id");
			ezjson_object_get_string(element, "title", accessGroup[AccessGroupTitle], charsmax(accessGroup[AccessGroupTitle]));
			ezjson_object_get_string(element, "flags", accessGroup[AccessGroupFlags], charsmax(accessGroup[AccessGroupFlags]));
			ezjson_object_get_string(element, "prefix", accessGroup[AccessGroupPrefix], charsmax(accessGroup[AccessGroupPrefix]));

			ArrayPushArray(AccessGroupsData, accessGroup, sizeof accessGroup);
		}
		ezjson_free(element);
	}

	AccessGroupsNextUpdate = ezjson_object_get_number(data, "next_update");
	ezjson_free(tmp);
}

bool:isAccessGroupsValid() {
	if (AccessGroupsNextUpdate < get_systime()) {
		return false;
	}

	return true;
}

bool:getAccessGroups() {
	new EzJSON:data = loadCache("access_groups");
	if (data == EzInvalid_JSON) {
		return false;
	}

	parseAccessGroups(data);
	ezjson_free(data);

	if (!isAccessGroupsValid()) {
		return false;
	}

	return true;
}

getCachePath(buffer[], length) {
	get_localinfo("amxx_datadir", buffer, length);
	format(buffer, length, "%s/%s", buffer, LambdaCacheFolder);

	if (!dir_exists(buffer)) {
		mkdir(buffer);
	}
}

EzJSON:loadCache(const name[]) {
	new path[PLATFORM_MAX_PATH];
	formatex(path, charsmax(path), "%s/%s.json", CachePath, name);

	if (!file_exists(path)) {
		return EzInvalid_JSON;
	}

	new error[1];
	return ezjson_parse(path, true);
}

bool:saveCache(const name[], EzJSON:data) {
	new path[PLATFORM_MAX_PATH];
	formatex(path, charsmax(path), "%s/%s.json", CachePath, name);

	if (ezjson_serial_to_file(EzJSON:data, path)) {
		return true;
	}

	return false;
}

bool:deleteCache(const name[]) {
	new path[PLATFORM_MAX_PATH];
	formatex(path, charsmax(path), "%s/%s.json", CachePath, name);

	if (!file_exists(path)) {
		return false;
	}

	if (delete_file(path)) {
		return true;
	}

	return false;
}

bool:deleteAllCache() {
	new file[PLATFORM_MAX_PATH];
	new dir = open_dir(CachePath, file, charsmax(file));

	if (dir) {
		while (next_file(dir, file, charsmax(file))) {
			// Exclude all directories at a higher level.
			if (file[0] == '.') {
				continue;
			}

			delete_file(fmt("%s/%s", CachePath, file));
		}

		close_dir(dir);
		return true;
	}

	return false;
}
