#include <amxmodx>
// #include <fakemeta>
// #include <reapi>
#include <lambda>

#pragma semicolon 1

public const LambdaFolder[] = "lambda";
public const LambdaCacheFolder[] = "lambda_cache";
public const LambdaCoreCfg[] = "lambda-core.json";

/**
 * HTTP request header name.
 */
stock const ACCESS_TOKEN_HEADER[] = "Lambda-X-Access-Token";

const TaskPingIndex = 100;
const Float:PingDelay = 60.0;

#define CHECK_NATIVE_ARGS_NUM(%0,%1,%2) \
	if (%0 < %1) { \
		log_error(AMX_ERR_NATIVE, "Invalid num of arguments (%d). Expected (%d).", %0, %1); \
		return %2; \
	}

#define CHECK_RESPONSE_STATUS(%0) \
	if (%0 != LambdaResponseStatusOk) { \
		log_amx("Bad response (status #%d).", %0); \
		return; \
	}

/**
 * Game Server API routes
 */
#define API_GAME_SERVER_ROUTE_AUTH	"game-servers/auth"
#define API_GAME_SERVER_ROUTE_INFO	fmt("game-servers/%d/info", ServerData[Id])
#define API_GAME_SERVER_ROUTE_PING	fmt("game-servers/%d/ping", ServerData[Id])

enum any:RequestStruct {
	RequestEndPoint[256],
	GripJSONValue:RequestData,
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
new GripRequestOptions:RequestOptions = Empty_GripRequestOptions;
new Array:RequestStorage = Invalid_Array;
new EntryPoint[256];

enum any:ServerDataStruct {
	Id,
	Time,
	TimeDiff,
	Ip[MAX_IP_LENGTH],
	Port,
	AuthToken[65],
	AccessToken[65],
	AccessTokenExpiresAt,
};
new ServerData[ServerDataStruct];

new CachePath[PLATFORM_MAX_PATH];

new Array:ReasonsData = Invalid_Array;
new ReasonsNextUpdate;
new bool:UpdateReasons;

new Array:AccessGroupsData = Invalid_Array;
new AccessGroupsNextUpdate;
new bool:UpdateAccessGroups;

new PluginId;

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
	// 	grip_destroy_json_value(request[RequestData]);
	// }

	// if (RequestOptions != Empty_GripRequestOptions) {
	// 	grip_destroy_options(RequestOptions);
	// }
}

public OnAuthorization(const LambdaResponseStatus:status, GripJSONValue:data) {
	CHECK_RESPONSE_STATUS(status)

	if (!data || grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	new GripJSONValue:tmp = grip_json_object_get_value(data, "access_token");
	parseAccessToken(tmp);
	saveCache("access-token", tmp);
	grip_destroy_json_value(tmp);

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

public OnInfoResponse(const LambdaResponseStatus:status, GripJSONValue:data) {
	CHECK_RESPONSE_STATUS(status)

	if (!data || grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	// ServerData[Id] = grip_json_object_get_number(data, "game_server_id");
	ServerData[Time] = grip_json_object_get_number(data, "time");
	ServerData[TimeDiff] = get_systime(0) - ServerData[Time];

	if (UpdateReasons) {
		new GripJSONValue:tmp = grip_json_object_get_value(data, "reasons_data");
		parseReasons(tmp);
		saveCache("reasons", tmp);
		grip_destroy_json_value(tmp);
	}

	if (UpdateAccessGroups) {
		new GripJSONValue:tmp = grip_json_object_get_value(data, "access_groups_data");
		parseAccessGroups(tmp);
		saveCache("access_groups", tmp);
		grip_destroy_json_value(tmp);
	}

	ExecuteForward(Forwards[FwdCoreLoaded]);
	log_amx("OnInfoResponse | status = ok");

	set_task(PingDelay, "TaskPing", .id = TaskPingIndex, .flags = "b");
}

public OnPing(const LambdaResponseStatus:status, GripJSONValue:data) {
	CHECK_RESPONSE_STATUS(status)
	// if (status != LambdaResponseStatusOk) {
	// 	log_amx("Bad response (status code #%d)", status);
	// 	remove_task(TaskPingIndex);
	// 	return;
	// }

	if (!data || grip_json_get_type(data) != GripJSONObject) {
		return;
	}

	// https://github.com/gm-x/gmx-amxx/blob/1bd75e46b20f5ec98e2afd676d321bf63aefa62b/scripting/gmx.sma#L362-L398
	log_amx("OnPing | status = ok");
}

public TaskPing() {
	makePingRequest();
}

makeAuthorizationRequest() {
	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_string(data, "ip", ServerData[Ip]);
	grip_json_object_set_number(data, "port", ServerData[Port]);
	grip_json_object_set_string(data, "auth_token", ServerData[AuthToken]);
	makeRequest(API_GAME_SERVER_ROUTE_AUTH, data, PluginId, Functions[FuncOnAuthorization]);
}

makeInfoRequest() {
	new GripJSONValue:data = grip_json_init_object();
	grip_json_object_set_string(data, "map", MapName);
	grip_json_object_set_number(data, "max_players", MaxClients);
	UpdateReasons && grip_json_object_set_bool(data, "update_reasons", true);
	UpdateAccessGroups && grip_json_object_set_bool(data, "update_access_groups", true);
	makeRequest(API_GAME_SERVER_ROUTE_INFO, data, PluginId, Functions[FuncOnInfoResponse]);
}

makePingRequest() {
	new GripJSONValue:data = grip_json_init_object();
	// grip_json_object_set_number(data, "num_players", get_playersnum());
	// https://github.com/gm-x/gmx-amxx/blob/1bd75e46b20f5ec98e2afd676d321bf63aefa62b/scripting/gmx.sma#L236-L242
	makeRequest(API_GAME_SERVER_ROUTE_PING, data, PluginId, Functions[FuncOnPing]);
	// https://github.com/gm-x/gmx-amxx/blob/1bd75e46b20f5ec98e2afd676d321bf63aefa62b/scripting/gmx.sma#L245
}

makeRequest(const endpoint[], GripJSONValue:data = Invalid_GripJSONValue, const pluginID = INVALID_PLUGIN_ID, const funcID = INVALID_PLUGIN_ID, const param = 0) {
	if (RequestOptions == Empty_GripRequestOptions) {
		RequestOptions = grip_create_default_options();
		grip_options_add_header(RequestOptions, "Content-Type", "application/json");
		grip_options_add_header(RequestOptions, "User-Agent", "Lambda");
	}

	if (funcID != Functions[FuncOnAuthorization]) {
		grip_options_add_header(RequestOptions, ACCESS_TOKEN_HEADER, ServerData[AccessToken]);
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
	new GripBody:body = data != Invalid_GripJSONValue ? grip_body_from_json(data) : Empty_GripBody;

	grip_request(fmt("%s/api/%s", EntryPoint, endpoint), body, GripRequestTypePost, "RequestHandler", RequestOptions, id);

	if (body != Empty_GripBody) {
		grip_destroy_body(body);
	}

	return id;
}

public RequestHandler(const id) {
	if (!isRequestIndexValid(id)) {
		log_amx("Bad request (id #%d).", id);
		return;
	}

	new request[RequestStruct], error[256];
	ArrayGetArray(RequestStorage, id, request, sizeof request);

	if (grip_get_response_state() != GripResponseStateSuccessful) {
		switch (grip_get_response_state()) {
			case GripResponseStateCancelled: {
				log_amx("Request (id #%d) was canceled.", id);
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusCanceled, Invalid_GripJSONValue, request[RequestParam]);
			}
			case GripResponseStateError: {
				grip_get_error_description(error, charsmax(error));
				log_amx("Request (id #%d) finished with error: '%s'.", id, error);
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusError, Invalid_GripJSONValue, request[RequestParam]);
			}
			case GripResponseStateTimeout: {
				log_amx("Request (id #%d) finished with timeout.", id);
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusTimeout, Invalid_GripJSONValue, request[RequestParam]);
			}
		}

		return;
	}

	new GripHTTPStatus:code = GripHTTPStatus:grip_get_response_status_code();
	if (code != GripHTTPStatusOk) {
		request[RequestNotProcessed] = true;
		LastNotProcessedRequest = id;

		log_amx("Request (id #%d) finished with '%d' status.", id, code);

		switch (code) {
			case GripHTTPStatusUnauthorized, GripHTTPStatusForbidden: {
			// case GripHTTPStatusUnauthorized: {
				grip_destroy_options(RequestOptions);
				RequestOptions = Empty_GripRequestOptions;

				log_amx("Сервер неавторизован, возможно истек срок действия токена доступа! будет произведена попытка авторизации!");
				makeAuthorizationRequest();
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusUnauthorized, Invalid_GripJSONValue, request[RequestParam]);
			}
			// перенести сюда логику для запросов которые не смогли успешно завершиться
/*			case GripHTTPStatusForbidden: {
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusBadToken, Invalid_GripJSONValue, request[RequestParam]);
			}*/
			case GripHTTPStatusNotFound: {
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusNotFound, Invalid_GripJSONValue, request[RequestParam]);
			}
			case GripHTTPStatusInternalServerError: {
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusServerError, Invalid_GripJSONValue, request[RequestParam]);
			}
			default: {
				callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusUnknownError, Invalid_GripJSONValue, request[RequestParam]);
			}
		}

		ArraySetArray(RequestStorage, id, request, sizeof request);
		return;
	}

	new GripJSONValue:data = grip_json_parse_response_body(error, charsmax(error));
	if (data == Invalid_GripJSONValue) {
		log_amx("Error parse response: '%s'.", error);
		callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusBadResponse, Invalid_GripJSONValue, request[RequestParam]);
		return;
	}

	request[RequestNotProcessed] = false;

	callHandlerFunc(request[RequestPluginId], request[RequestFuncId], LambdaResponseStatusOk, data, request[RequestParam]);
	grip_destroy_json_value(data);
	ArraySetArray(RequestStorage, id, request, sizeof request);
}

callHandlerFunc(const pluginID, const funcID, const LambdaResponseStatus:status, const GripJSONValue:data, const param) {
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
	new GripJSONValue:cfg = grip_json_parse_file(filePath, error, charsmax(error));

	if (cfg == Invalid_GripJSONValue) {
		set_fail_state("Could not open '%s'. Error '%s'.", filePath, error);
		return false;
	}

	if (grip_json_get_type(cfg) != GripJSONObject) {
		grip_destroy_json_value(cfg);
		set_fail_state("Could not open '%s'. Bad format.", filePath);
		return false;
	}

	grip_json_object_get_string(cfg, "entry-point", EntryPoint, charsmax(EntryPoint));

	new GripJSONValue:tmp = grip_json_object_get_value(cfg, "server-data");
	grip_json_object_get_string(tmp, "ip", ServerData[Ip], charsmax(ServerData[Ip]));
	grip_json_object_get_string(tmp, "auth-token", ServerData[AuthToken], charsmax(ServerData[AuthToken]));
	ServerData[Port] = grip_json_object_get_number(tmp, "port");

	ExecuteForward(Forwards[FwdConfigExecuted]);
	log_amx("Loading configuration. Entry point for requests: %s", EntryPoint);

	grip_destroy_json_value(tmp);
	grip_destroy_json_value(cfg);

	return true;
}

bool:isRequestIndexValid(const index) {
	return bool:(0 <= index && index < ArraySize(RequestStorage));
}

parseAccessToken(const GripJSONValue:data) {
	grip_json_object_get_string(data, "token", ServerData[AccessToken], charsmax(ServerData[AccessToken]));
	ServerData[AccessTokenExpiresAt] = grip_json_object_get_number(data, "expires_at");
	ServerData[Id] = grip_json_object_get_number(data, "game_server_id");
}

bool:isAccessTokenValid() {
	if (ServerData[AccessToken][0] == EOS || ServerData[AccessTokenExpiresAt] < get_systime()) {
		return false;
	}

	return true;
}

bool:getAccessToken() {
	new GripJSONValue:data = loadCache("access-token");
	if (data == Invalid_GripJSONValue) {
		return false;
	}

	parseAccessToken(data);
	grip_destroy_json_value(data);

	if (!isAccessTokenValid()) {
		return false;
	}

	return true;
}

parseReasons(const GripJSONValue:data) {
	if (ReasonsData == Invalid_Array) {
		ReasonsData = ArrayCreate(ReasonStruct);
	}

	new GripJSONValue:tmp = grip_json_object_get_value(data, "reasons");
	for (new i, n = grip_json_array_get_count(tmp), GripJSONValue:element, reason[ReasonStruct]; i < n; i++) {
		element = grip_json_array_get_value(tmp, i);
		if (grip_json_get_type(element) == GripJSONObject) {
			reason[ReasonID] = grip_json_object_get_number(element, "id");
			grip_json_object_get_string(element, "title", reason[ReasonTitle], charsmax(reason[ReasonTitle]));
			reason[ReasonTime] = grip_json_object_get_number(element, "time");

			ArrayPushArray(ReasonsData, reason, sizeof reason);
		}
		grip_destroy_json_value(element);
	}

	ReasonsNextUpdate = grip_json_object_get_number(data, "next_update");
	grip_destroy_json_value(tmp);
}

bool:isReasonsValid() {
	if (ReasonsNextUpdate < get_systime()) {
		return false;
	}

	return true;
}

bool:getReasons() {
	new GripJSONValue:data = loadCache("reasons");
	if (data == Invalid_GripJSONValue) {
		return false;
	}

	parseReasons(data);
	grip_destroy_json_value(data);

	if (!isReasonsValid()) {
		return false;
	}

	return true;
}

parseAccessGroups(const GripJSONValue:data) {
	if (AccessGroupsData == Invalid_Array) {
		AccessGroupsData = ArrayCreate(AccessGroupStruct);
	}

	new GripJSONValue:tmp = grip_json_object_get_value(data, "access_groups");
	for (new i, n = grip_json_array_get_count(tmp), GripJSONValue:element, accessGroup[AccessGroupStruct]; i < n; i++) {
		element = grip_json_array_get_value(tmp, i);
		if (grip_json_get_type(element) == GripJSONObject) {
			accessGroup[AccessGroupID] = grip_json_object_get_number(element, "id");
			grip_json_object_get_string(element, "title", accessGroup[AccessGroupTitle], charsmax(accessGroup[AccessGroupTitle]));
			grip_json_object_get_string(element, "flags", accessGroup[AccessGroupFlags], charsmax(accessGroup[AccessGroupFlags]));
			grip_json_object_get_string(element, "prefix", accessGroup[AccessGroupPrefix], charsmax(accessGroup[AccessGroupPrefix]));

			ArrayPushArray(AccessGroupsData, accessGroup, sizeof accessGroup);
		}
		grip_destroy_json_value(element);
	}

	AccessGroupsNextUpdate = grip_json_object_get_number(data, "next_update");
	grip_destroy_json_value(tmp);
}

bool:isAccessGroupsValid() {
	if (AccessGroupsNextUpdate < get_systime()) {
		return false;
	}

	return true;
}

bool:getAccessGroups() {
	new GripJSONValue:data = loadCache("access_groups");
	if (data == Invalid_GripJSONValue) {
		return false;
	}

	parseAccessGroups(data);
	grip_destroy_json_value(data);

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

GripJSONValue:loadCache(const name[]) {
	new path[PLATFORM_MAX_PATH];
	formatex(path, charsmax(path), "%s/%s.json", CachePath, name);

	if (!file_exists(path)) {
		return Invalid_GripJSONValue;
	}

	new error[1];
	return grip_json_parse_file(path, error, charsmax(error));
}

bool:saveCache(const name[], GripJSONValue:data) {
	new path[PLATFORM_MAX_PATH];
	formatex(path, charsmax(path), "%s/%s.json", CachePath, name);

	if (grip_json_serial_to_file(GripJSONValue:data, path)) {
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
