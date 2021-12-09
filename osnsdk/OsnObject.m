
#import <Foundation/Foundation.h>
#import "OsnObject.h"

@implementation OsnUserInfo

+ (OsnUserInfo*) toUserInfo:(NSMutableDictionary*) json{
    if(json == nil)
        return nil;
    OsnUserInfo *userInfo = [OsnUserInfo new];
    userInfo.userID = json[@"userID"];
    userInfo.name = json[@"name"];
    userInfo.displayName = json[@"displayName"];
    userInfo.portrait = json[@"portrait"];
    userInfo.urlSpace = json[@"urlSpace"];
    return userInfo;
}

@end

@implementation OsnMemberInfo
+ (OsnMemberInfo*)toMemberInfo:(NSMutableDictionary*)json{
    OsnMemberInfo *memberInfo = [OsnMemberInfo new];
    memberInfo.osnID = json[@"osnID"];
    memberInfo.groupID = json[@"groupID"];
    memberInfo.nickName = json[@"nickName"];
    memberInfo.remarks = json[@"remarks"];
    memberInfo.type = ((NSNumber*)json[@"type"]).intValue;
    return memberInfo;
}
+ (NSArray<OsnMemberInfo*>*)toMemberInfos:(NSMutableDictionary*)json{
    NSArray<NSMutableDictionary*> *array = json[@"userList"];
    NSMutableArray<OsnMemberInfo*> *members = [NSMutableArray new];
    if(array != nil){
        for(NSMutableDictionary* o in array)
            [members addObject:[OsnMemberInfo toMemberInfo:o]];
    }
    return members;
}
@end

@implementation OsnGroupInfo

- (instancetype)init{
    self = [super init];
    self.userList = [NSMutableArray new];
    return self;
}
+ (OsnGroupInfo*) toGroupInfo:(NSMutableDictionary*) json{
    if(json == nil)
        return nil;
    OsnGroupInfo *groupInfo = [OsnGroupInfo new];
    groupInfo.groupID = json[@"groupID"];
    groupInfo.name = json[@"name"];
    groupInfo.privateKey = @"";
    groupInfo.owner = json[@"owner"];
    groupInfo.portrait = json[@"portrait"];
    NSArray<NSDictionary*> *array = json[@"userList"];
    if(array != nil){
        for(NSDictionary* o in array){
            OsnMemberInfo *memberInfo = [OsnMemberInfo new];
            memberInfo.osnID = o[@"osnID"];
            memberInfo.groupID = o[@"groupID"];
            memberInfo.type = ((NSNumber*)o[@"type"]).intValue;
        }
    }
    return groupInfo;
}
- (OsnMemberInfo*) hasMember:(NSString*) osnID{
    for(OsnMemberInfo* m in self.userList){
        if([osnID isEqualToString:m.osnID])
            return m;
    }
    return nil;
}
@end

@implementation OsnFriendInfo

+ (OsnFriendInfo*) init:(NSString*) userID  friendID:(NSString*) friendID state:(int) state{
    OsnFriendInfo *friendInfo = [OsnFriendInfo new];
    friendInfo.userID = userID;
    friendInfo.friendID = friendID;
    friendInfo.state = state;
    return friendInfo;
}
+ (OsnFriendInfo*) toFriendInfo:(NSDictionary*) json{
    OsnFriendInfo *friendInfo = [OsnFriendInfo new];
    friendInfo.userID = json[@"userID"];
    friendInfo.friendID = json[@"friendID"];
    friendInfo.remarks = json[@"remarks"];
    friendInfo.state = ((NSNumber*)json[@"state"]).intValue;
    return friendInfo;
}

@end

@implementation OsnMessageInfo
+ (OsnMessageInfo*)toMessageInfo:(NSDictionary*)json data:(NSDictionary*)data{
    OsnMessageInfo *messageInfo = [OsnMessageInfo new];
    messageInfo.userID = json[@"from"];
    messageInfo.target = json[@"to"];
    messageInfo.timeStamp = ((NSNumber*)json[@"timestamp"]).longValue;
    messageInfo.content = data[@"content"];
    if(messageInfo.userID != nil)
        messageInfo.isGroup = [messageInfo.userID isEqualToString:@"OSNG"];
    else
        messageInfo.isGroup = false;
    messageInfo.originalUser = data[@"originalUser"];
    return messageInfo;
}
@end

@implementation OsnRequestInfo
@end

@implementation OsnServiceInfo
+ (OsnServiceInfo*)toServiceInfo:(NSDictionary*) json{
    NSString *type = json[@"type"];
    if([type isEqualToString:@"IMS"])
        return [OsnIMInfo toIMInfo:json];
    else if([type isEqualToString:@"Litapp"])
        return [OsnLitappInfo toLitappInfo:json];
    return nil;
}
@end

@implementation OsnIMInfo
+ (OsnIMInfo*)toIMInfo:(NSDictionary*) json{
    OsnIMInfo *info = [OsnIMInfo new];
    info.type = json[@"type"];
    info.urlSpace = json[@"urlSpace"];
    return info;
}
@end

@implementation OsnLitappInfo
+ (OsnLitappInfo*)toLitappInfo:(NSDictionary*) json{
    OsnLitappInfo *info = [OsnLitappInfo new];
    info.type = json[@"type"];
    info.target = json[@"target"];
    info.name = json[@"name"];
    info.displayName = json[@"displayName"];
    info.portrait = json[@"portrait"];
    info.theme = json[@"theme"];
    info.url = json[@"url"];
    return info;
}
@end
