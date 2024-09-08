// #include "lambda/misc.inl"

public plugin_natives() {
	register_library("Lambda_AMXX_API_Player");

	set_module_filter("ModuleFilterHandler");
	set_native_filter("NativeFilterHandler");
}

public ModuleFilterHandler(const library[], LibType:type) {
	if (equal(library, "Lambda_AMXX_API_Core")) {
		log_amx("Library '%s' not found. Check that the system core is loaded.", library);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public NativeFilterHandler(const native_func[], index, trap) {
	static const core_natives[][] = {
		"Lambda_MakeRequest",
		"Lambda_LoadCache",
		"Lambda_SaveCache",
	};

	for (new i; i < sizeof core_natives; i++) {
		if (equal(native_func, core_natives[i])) {
			log_amx("Native '%s' not found. Check that the system core is loaded.", native_func);
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}