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