
@interface OsnUserInfo : NSObject
@property NSString* userID;
@property NSString* name;
@property NSString* displayName;
@property NSString* portrait;
@property NSString* urlSpace;
+ (OsnUserInfo*)toUserInfo:(NSDictionary*) json;
@end

@interface OsnRequestInfo : NSObject
@property NSString* reason;
@property NSString* userID;
@property NSString* friendID;
@property NSString* originalUser;
@property NSString* targetUser;
@property long timeStamp;
@property Boolean isGroup;
@property Boolean isApply;
@end

@interface OsnMessageInfo : NSObject
@property NSString* userID;
@property NSString* target;
@property NSString* content;
@property long timeStamp;
@property Boolean isGroup;
@property NSString* originalUser;
+ (OsnMessageInfo*)toMessageInfo:(NSDictionary*)json data:(NSDictionary*)data;
@end

#define MemberType_Wait   0
#define MemberType_Normal 1
#define MemberType_Owner  2
#define MemberType_Admin  3

@interface OsnMemberInfo : NSObject
@property NSString* osnID;
@property NSString* groupID;
@property NSString* remarks;
@property NSString* nickName;
@property int type;
@property int muta;
+ (NSArray<OsnMemberInfo*>*)toMemberInfos:(NSDictionary*)json;
@end

@interface OsnGroupInfo : NSObject
@property NSString* groupID;
@property NSString* name;
@property NSString* privateKey;
@property NSString* owner;
@property NSString* portrait;
@property int memberCount;
@property int type;
@property int joinType;
@property int passType;
@property int mute;
@property NSMutableArray<OsnMemberInfo*>* userList;
+ (OsnGroupInfo*)toGroupInfo:(NSDictionary*) json;
- (OsnMemberInfo*)hasMember:(NSString*) osnID;
@end

#define FriendState_Wait    0
#define FriendState_Normal  1
#define FriendState_Deleted 2
#define FriendState_Blacked 3
#define FriendState_Syncst  4

@interface OsnFriendInfo : NSObject
@property NSString* userID;
@property NSString* friendID;
@property NSString* remarks;
@property int state;
+ (OsnFriendInfo*) init:(NSString*)userID friendID:(NSString*)friendID state:(int)state;
+ (OsnFriendInfo*) toFriendInfo:(NSDictionary*) json;
@end

@interface OsnServiceInfo : NSObject
@property NSString* type;
+ (OsnServiceInfo*)toServiceInfo:(NSDictionary*) json;
@end

@interface OsnIMInfo : OsnServiceInfo
@property NSString* urlSpace;
+ (OsnIMInfo*)toIMInfo:(NSDictionary*) json;
@end

@interface OsnLitappInfo : OsnServiceInfo
@property NSString* target;
@property NSString* name;
@property NSString* displayName;
@property NSString* portrait;
@property NSString* theme;
@property NSString* url;
+ (OsnLitappInfo*)toLitappInfo:(NSDictionary*) json;
@end
