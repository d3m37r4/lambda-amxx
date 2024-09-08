#if defined _lambda_consts_included
	#endinput
#endif
#define _lambda_consts_included

#define MAX_REASON_TITLE_LENGTH 			64

#define MAX_ACCESS_GROUP_TITLE_LENGTH 		64
#define MAX_ACCESS_GROUP_FLAGS_LENGTH 		28
#define MAX_ACCESS_GROUP_PREFIX_LENGTH		32

enum LambdaResponseStatus {
	LambdaResponseStatusOk,
	LambdaResponseStatusCanceled,
	LambdaResponseStatusError,
	LambdaResponseStatusTimeout,
	LambdaResponseStatusNotFound,
	LambdaResponseStatusBadToken,
	LambdaResponseStatusServerError,
	LambdaResponseStatusBadResponse,
	LambdaResponseStatusUnknownError,
	LambdaResponseStatusUnauthorized,
};

// enum GmxLogLevel (+=1) {
	// GmxLogCritical = 0,
	// GmxLogError,
	// GmxLogInfo,
	// GmxLogDebug
// };

enum any:ReasonStruct {
	ReasonID,
	ReasonTitle[MAX_REASON_TITLE_LENGTH],
	ReasonTime,
};

enum any:AccessGroupStruct {
	AccessGroupID,
	AccessGroupTitle[MAX_ACCESS_GROUP_TITLE_LENGTH],
	AccessGroupFlags[MAX_ACCESS_GROUP_FLAGS_LENGTH],
	AccessGroupPrefix[MAX_ACCESS_GROUP_PREFIX_LENGTH],
};

/**
 * Invalid request id 
 */
#define INVALID_REQUEST_ID -1

/**
 * Accesses constants
 */
#define FLAG_ALL			0       /* everyone */
#define FLAG_A			(1<<0)
#define FLAG_B			(1<<1)
#define FLAG_C			(1<<2)
#define FLAG_D			(1<<3)
#define FLAG_E			(1<<4)
#define FLAG_F			(1<<5)
#define FLAG_G			(1<<6)
#define FLAG_H			(1<<7)
#define FLAG_I			(1<<8)
#define FLAG_J			(1<<9)
#define FLAG_K			(1<<10)
#define FLAG_L			(1<<11)
#define FLAG_M			(1<<12)
#define FLAG_N			(1<<13)
#define FLAG_O			(1<<14)
#define FLAG_P			(1<<15)
#define FLAG_Q			(1<<16)
#define FLAG_R			(1<<17)
#define FLAG_S			(1<<18)
#define FLAG_T			(1<<19)
#define FLAG_U			(1<<20)
#define FLAG_V			(1<<21)
#define FLAG_W			(1<<22)
#define FLAG_X			(1<<23)
#define FLAG_Y			(1<<24)
#define FLAG_Z			(1<<25)
