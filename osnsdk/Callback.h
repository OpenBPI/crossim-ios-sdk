#import <osnsdk/OsnObject.h>

typedef void(^onResult)(bool isSuccess, NSDictionary *json, NSString *error);
typedef void(^onResultT)(bool isSuccess, id t, NSString *error);
typedef void(^onProgress)(long progress, long total);

@protocol OsnCallback <NSObject>
- (void) onConnectSuccess:(NSString*) state;
- (void) onConnectFailed:(NSString*) error;
- (void) onRecvMessage:(NSArray<OsnMessageInfo*>*) msgList;
- (void) onRecvRequest:(OsnRequestInfo*) request;
- (void) onFriendUpdate:(NSArray<OsnFriendInfo*>*) userIDList;
- (void) onUserUpdate:(OsnUserInfo*) userInfo keys:(NSArray<NSString*>*) keys;
- (void) onGroupUpdate:(NSString*) state info:(OsnGroupInfo*) groupInfo keys:(NSArray<NSString*>*) keys;
@end
//
//@protocol OsnGeneralCallback <NSObject>
//- (void) onSuccess:(NSString*)json;
//- (void) onFailure:(NSString*)error;
//@end
