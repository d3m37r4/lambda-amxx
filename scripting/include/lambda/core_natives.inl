// #include "lambda/misc.inl"

public plugin_natives() {
	ExecuteForward(CreateMultiForward("__lambda_version_check", ET_IGNORE, FP_STRING, FP_STRING), _, LAMBDA_VERSION_MAJOR, LAMBDA_VERSION_MINOR);

	register_library("Lambda_AMXX_API_Core");

	register_native("Lambda_MakeRequest", "NativeMakeRequest");

	register_native("Lambda_GetServerID", "NativeGetServerID");
	register_native("Lambda_GetServerTime", "NativeGetServerTime");
	register_native("Lambda_GetServerTimeDiff", "NativeGetServerTimeDiff");

	register_native("Lambda_LoadCache", "NativeLoadCache");
	register_native("Lambda_SaveCache", "NativeSaveCache");
	register_native("Lambda_DeleteCache", "NativeDeleteCache");
	register_native("Lambda_DeleteAllCache", "NativeDeleteAllCache");

	register_native("Lambda_ReasonsLoaded", "NativeReasonsLoaded");
	register_native("Lambda_GetReasons", "NativeGetReasons");

	register_native("Lambda_AccessGroupsLoaded", "NativeAccessGroupsLoaded");
	register_native("Lambda_GetAccessGroups", "NativeGetAccessGroups");
}

public NativeMakeRequest(const plugin, const argc) {
	enum { arg_endpoint = 1, arg_data, arg_callback, arg_param };

	CHECK_NATIVE_ARGS_NUM(argc, arg_callback, INVALID_REQUEST_ID)

	new endpoint[128];
	get_string(arg_endpoint, endpoint, charsmax(endpoint));

	new callback[64];
	get_string(arg_callback, callback, charsmax(callback));

	new funcId, GripJSONValue:data = GripJSONValue:get_param(arg_data);
	if (callback[0] != EOS) {
		funcId = get_func_id(callback, plugin);
		if (funcId == INVALID_HANDLE) {
			log_error(AMX_ERR_NATIVE, "Could not find function (%s).", callback);
			return INVALID_REQUEST_ID;
		}
	} else {
		funcId = INVALID_REQUEST_ID;
	}

	return makeRequest(endpoint, data, plugin, funcId, argc >= 4 ? get_param(arg_param) : 0);
}

public NativeGetServerID() {
	return ServerData[ServerID];
}

public NativeGetServerTime() {
	return ServerData[ServerTime];
}

public NativeGetServerTimeDiff() {
	return ServerData[ServerTimeDiff];
}

public GripJSONValue:NativeLoadCache(const plugin, const argc) {
	enum { arg_name = 1 };

	CHECK_NATIVE_ARGS_NUM(argc, arg_name, Invalid_GripJSONValue)

	new name[64];
	get_string(arg_name, name, charsmax(name));

	return loadCache(name);
}

public bool:NativeSaveCache(const plugin, const argc) {
	enum { arg_name = 1, arg_data };

	CHECK_NATIVE_ARGS_NUM(argc, arg_data, false)

	new name[64];
	get_string(arg_name, name, charsmax(name));

	if (saveCache(name, GripJSONValue:get_param(arg_data))) {
		return true;
	}

	return false;
}

public bool:NativeDeleteCache(const plugin, const argc) {
	enum { arg_name = 1 };

	CHECK_NATIVE_ARGS_NUM(argc, arg_name, false)

	new name[64];
	get_string(arg_name, name, charsmax(name));

	if (deleteCache(name)) {
		return true;
	}

	return false;
}

public bool:NativeDeleteAllCache(const plugin, const argc) {
	if (deleteAllCache()) {
		return true;
	}

	return false;
}

public bool:NativeReasonsLoaded(const plugin, const argc) {
	if (ReasonsData == Invalid_Array) {
		return false;
	}

	return true;
}

public Array:NativeGetReasons(const plugin, const argc) {
	return ReasonsData;
}

public bool:NativeAccessGroupsLoaded(const plugin, const argc) {
	if (AccessGroupsData == Invalid_Array) {
		return false;
	}

	return true;
}

public Array:NativeGetAccessGroups(const plugin, const argc) {
	return AccessGroupsData;
}
