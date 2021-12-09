#import <Foundation/Foundation.h>
#import <osnsdk/Callback.h>

@interface OsnSDK : NSObject
+ (void) initSDK:(NSString*) ip cb:(id<OsnCallback>)cb;
+ (void) resetHost:(NSString*) ip;
+ (void) registerUser:(NSString*) userName pwd:(NSString*) password sid:(NSString*) serviceID cb:(onResult)cb;
+ (bool) loginWithOsnID:(NSString *)userID cb:(onResult)cb;
+ (bool) loginWithName:(NSString *)userName pwd:(NSString *)password cb:(onResult)cb;
+ (void) logout:(onResult)cb;
+ (NSString*) getUserID;
+ (NSString*) getServiceID;
+ (OsnUserInfo*) getUserInfo:(NSString*) userID cb:(onResultT)cb;
+ (OsnGroupInfo*) getGroupInfo:(NSString*) groupID cb:(onResultT)cb;
+ (NSArray*) getMemberInfo:(NSString*) groupID cb:(onResultT)cb;
+ (OsnServiceInfo*) getServiceInfo:(NSString*) serviceID cb:(onResultT)cb;
+ (OsnFriendInfo*) getFriendInfo:(NSString*) friendID cb:(onResultT)cb;
+ (void) modifyUserInfo:(NSArray*) keys info:(OsnUserInfo*) userInfo cb:(onResult)cb;
+ (void) modifyFriendInfo:(NSArray*) keys info:(OsnFriendInfo*) friendInfo cb:(onResult)cb;
+ (NSArray*) getFriendList:(onResultT)cb;
+ (NSArray*) getGroupList:(onResultT)cb;
+ (void) inviteFriend:(NSString*) userID reason:(NSString*) reason cb:(onResult)cb;
+ (void) deleteFriend:(NSString*) userID cb:(onResult)cb;
+ (void) acceptFriend:(NSString*) userID cb:(onResult)cb;
+ (void) rejectFriend:(NSString*) userID cb:(onResult)cb;
+ (void) acceptMember:(NSString*) userID groupID:(NSString*)groupID cb:(onResult)cb;
+ (void) rejectMember:(NSString*) userID groupID:(NSString*)groupID cb:(onResult)cb;
+ (void) sendMessage:(NSString*) text userID:(NSString*) userID cb:(onResult)cb;
+ (NSArray<OsnMessageInfo*>*) loadMessage:(NSString*) userID timestamp:(long)timestamp count:(int)count before:(bool) before cb:(onResultT)cb;
+ (void) createGroup:(NSString*) groupName membser:(NSArray*) member type:(int)type portrait:(NSString*) portrait cb:(onResult)cb;
+ (void) joinGroup:(NSString*) groupID reason:(NSString*)reason cb:(onResult)cb;
+ (void) rejectGroup:(NSString*) groupID cb:(onResult)cb;
+ (void) addMember:(NSString*) groupID members:(NSArray*) members cb:(onResult)cb;
+ (void) delMember:(NSString*) groupID members:(NSArray*) members cb:(onResult)cb;
+ (void) quitGroup:(NSString*) groupID cb:(onResult)cb;
+ (void) dismissGroup:(NSString*) groupID cb:(onResult)cb;
+ (void) modifyGroupInfo:(NSArray*) keys groupInfo:(OsnGroupInfo*) groupInfo cb:(onResult)cb;
+ (void) modifyMemberInfo:(NSArray*) keys memberInfo:(OsnMemberInfo*) memberInfo cb:(onResult)cb;
+ (void) uploadData:(NSString*) fileName type:(NSString*)type data:(NSData*) data cb:(onResult)cb progress:(onProgress)progress;
+ (void) downloadData:(NSString*) remoteUrl localPath:(NSString*) localPath cb:(onResult)cb progress:(onProgress)progress;
+ (void) lpLogin:(OsnLitappInfo*) litappInfo url:(NSString*) url cb:(onResult)cb;
+ (NSString*) signData:(NSString*) data;
@end
 
