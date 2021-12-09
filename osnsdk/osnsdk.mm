//
//  OsnSDK.m
//  sdktest
//
//  Created by abc on 2021/1/17.
//  Copyright © 2021 test. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "osnsdk.h"
#import <sys/socket.h>
#import <arpa/inet.h>
#import "OsnUtils.h"
#import "HttpUtils.h"
#import "EcUtils.h"

@implementation OsnSDK

NSString *mOsnID=nil;
NSString *mOsnKey=nil;
NSString *mServiceID=nil;
NSString *mAesKey=nil;
NSString *mDeviceID=nil;
bool mLogined=false;
bool mInitSync=false;
bool mConnect=false;
long mMsgSync=0;
long mRID=[OsnUtils getTimeStamp];
int mSock=0;
NSString *mHost=nil;
NSMutableDictionary *mIDMap=nil;
dispatch_queue_t mQueue;
id<OsnCallback> mCallback;

typedef void(^synCall)(NSString*,NSDictionary*);

+ (void)initialize{
    mIDMap = [NSMutableDictionary new];
    mQueue = dispatch_queue_create("com.ospn.osnsdk", DISPATCH_QUEUE_CONCURRENT);
}
+ (void)setCallback:(id<OsnCallback>) cb{
    mCallback = cb;
}
+ (NSMutableDictionary*)sendPackage:(NSDictionary*)jsonPack{
    @try{
        if(!mConnect)
            return nil;
        long timestamp;
        @synchronized (self) {
            timestamp = mRID++;
        }
        NSString *ids = [NSString stringWithFormat:@"%ld",timestamp];
        NSMutableDictionary *json = [[NSMutableDictionary alloc]initWithDictionary:jsonPack copyItems:false];
        json[@"id"] = ids;

        NSLog(@"%@:%@",json[@"command"],[OsnUtils dic2json:json]);
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
        Byte headData[4];
        headData[0] = (jsonData.length>>24)&0xff;
        headData[1] = (jsonData.length>>16)&0xff;
        headData[2] = (jsonData.length>>8)&0xff;
        headData[3] = (jsonData.length>>0)&0xff;
        @synchronized (self) {
            send(mSock,headData,4,0);
            send(mSock,jsonData.bytes,jsonData.length,0);
        }
        __block NSMutableDictionary *waitJson = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        synCall sc = ^(NSString *ids, NSDictionary *data){
            waitJson = [data mutableCopy];
            dispatch_semaphore_signal(semaphore);
        };
        mIDMap[ids] = sc;
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC*10));
        [mIDMap removeObjectForKey:ids];
        return waitJson;
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (NSMutableDictionary*) imRespond:(NSDictionary*) json cb:(onResult)cb{
    if(![OsnSDK isSuccess:json]){
        NSLog(@"error: %@",[OsnSDK errCode:json]);
        if(cb != nil)
            cb(false,nil,[OsnSDK errCode:json]);
        return nil;
    }
    NSMutableDictionary *data = [OsnUtils takeMessage:json key:mOsnKey];
    if(cb != nil){
        if(data == nil){
            NSLog(@"error: takeMessage");
            cb(false,nil,[OsnSDK errCode:data]);
        }
        else
            cb(true,data,nil);
    }
    return data;
}
+ (NSMutableDictionary*) imRequest:(NSString*) command to:(NSString*) to data:(NSDictionary*) data cb:(onResult)cb{
    @try {
        NSDictionary *json = [OsnUtils makeMessage:command from:mOsnID to:to data:data key:mOsnKey];
        if(cb != nil){
            dispatch_async(mQueue, ^{
                NSDictionary *result = [OsnSDK sendPackage:json];
                [OsnSDK imRespond:result cb:cb];
            });
            return nil;
        }
        json = [OsnSDK sendPackage:json];
        return [OsnSDK imRespond:json cb:cb];
    }
    @catch (NSException *e){
        NSLog(@"%@",e);
        if(cb != nil)
            cb(false,nil,e.reason);
    }
    return nil;
}
+ (bool) isSuccess:(NSDictionary*) json{
    if(json == nil)
        return false;
    NSString *errCode = json[@"errCode"];
    if(errCode == nil)
        return false;
    return [errCode isEqualToString:@"success"] || [errCode isEqualToString:@"0:success"];
}
+ (NSString*) errCode:(NSDictionary*) json{
    if(json == nil)
        return @"null";
    NSString *errCode = json[@"errCode"];
    if(errCode == nil)
        return @"none";
    return errCode;
}
+ (bool) login:(NSString*) user key:(NSString*) key type:(NSString*) type cb:(onResult)cb{
    @try{
        NSMutableDictionary *json = [@{}mutableCopy];
        json[@"command"] = @"Login";
        json[@"type"] = type;
        json[@"user"] = user;
        json[@"platform"] = @"ios";
        json[@"1"] = @"ver";
        json[@"state"] = @"request";
        NSMutableDictionary *data = [[OsnSDK sendPackage:json]mutableCopy];
        if(![OsnSDK isSuccess:data]){
            if(cb != nil)
                cb(false,nil,[OsnSDK errCode:data]);
            return false;
        }
        NSString *content = [data objectForKey:@"content"];
        data = [OsnUtils json2dic:[content dataUsingEncoding:NSUTF8StringEncoding]];
        content = [OsnUtils aesDecrypt:[data objectForKey:@"data"] keyStr:key];
        data = [OsnUtils json2dic:[content dataUsingEncoding:NSUTF8StringEncoding]];
        data[@"user"] = user;
        data[@"random"] = [NSNumber numberWithLong:[OsnUtils getTimeStamp]];
        json[@"data"] = [OsnUtils aesEncrypt:[OsnUtils dic2json:data] keyStr:key];
        json[@"state"] = @"verify";
        data = [OsnSDK sendPackage:json];
        if(![OsnSDK isSuccess:data]){
            if(cb != nil)
                cb(false,nil,[OsnSDK errCode:data]);
            return false;
        }
        content = data[@"content"];
        data = [OsnUtils json2dic:[content dataUsingEncoding:NSUTF8StringEncoding]];
        content = [OsnUtils aesDecrypt:[data objectForKey:@"data"] keyStr:key];
        data = [OsnUtils json2dic:[content dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *osnID = mOsnID;
        mAesKey = data[@"aesKey"];
        mOsnID = data[@"osnID"];
        mOsnKey = data[@"osnKey"];
        mServiceID = data[@"serviceID"];
        [[NSUserDefaults standardUserDefaults] setValue:mOsnID forKey:@"osnID"];
        [[NSUserDefaults standardUserDefaults] setValue:mOsnKey forKey:@"osnKey"];
        [[NSUserDefaults standardUserDefaults] setValue:mAesKey forKey:@"aesKey"];
        [[NSUserDefaults standardUserDefaults] setValue:mServiceID forKey:@"serviceID"];
        mLogined = true;
        [mCallback onConnectSuccess:@"logined"];
        if(cb != nil)
            cb(true,data,nil);
        
        dispatch_async(mQueue, ^{
            if(!mInitSync || (osnID != nil && ![osnID isEqualToString:mOsnID])){
                if([OsnSDK syncFriend] && [OsnSDK syncGroup]){
                    mInitSync = true;
                    [[NSUserDefaults standardUserDefaults] setValue:@"true" forKey:@"initSync"];
                }
            }
            while(true){
                long timestamp = mMsgSync;
                if([OsnSDK syncMessage:timestamp count:20] != 20)
                    break;
                if(timestamp == mMsgSync)
                    break;
            }
        });
        return true;
    }
    @catch(NSException* e){
        NSLog(@"%@",e);
        if(cb != nil)
            cb(false,nil,e.reason);
    }
    return false;
}
+(void) setMsgSync:(NSDictionary*) json {
    NSNumber *timestamp = json[@"timestamp"];
    if(timestamp == nil)
        return;
    long ts = [timestamp longValue];
    if(ts < mMsgSync)
        return;
    mMsgSync = ts;
    [[NSUserDefaults standardUserDefaults] setValue:timestamp forKey:@"msgSync"];
}
+(NSArray*) getMessages:(NSDictionary*) json {
    NSMutableArray<OsnMessageInfo*> *messages = [NSMutableArray new];
    @try{
        NSArray *array = json[@"msgList"];
        NSLog(@"msgList: %lu",(unsigned long)array.count);
        for(NSString *o in array){
            json = [OsnUtils json2dic:[o dataUsingEncoding:NSUTF8StringEncoding]];
            NSString *command = json[@"command"];
            if(command != nil && [command isEqualToString:@"Message"]){
                NSDictionary *data = [OsnUtils takeMessage:json key:mOsnKey];
                if(data != nil){
                    OsnMessageInfo *messageInfo = [OsnMessageInfo new];
                    messageInfo.userID = json[@"from"];
                    messageInfo.target = json[@"to"];
                    messageInfo.timeStamp = ((NSNumber*)json[@"timestamp"]).longValue;
                    messageInfo.content = data[@"content"];
                    messageInfo.isGroup = [messageInfo.userID isEqualToString:@"OSNG"];
                    messageInfo.originalUser = data[@"originalUser"];
                    [messages addObject:messageInfo];
                }
            }
        }
    }
    @catch(NSException* e){
        NSLog(@"%@",e);
    }
    return messages;
}
+(bool) syncGroup{
    @try{
        NSMutableDictionary* json = [OsnSDK imRequest:@"GetGroupList" to:mServiceID data:nil cb:nil];
        if(json == nil)
            return false;
        NSArray *groupList = json[@"groupList"];
        for(NSString *o in groupList){
            OsnGroupInfo *groupInfo = [OsnGroupInfo new];
            groupInfo.groupID = o;
            [mCallback onGroupUpdate:@"SyncGroup" info:groupInfo keys:nil];
        }
        return true;
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return false;
}
+(bool) syncFriend {
    @try {
        NSMutableDictionary* json = [OsnSDK imRequest:@"GetFriendList" to:mServiceID data:nil cb:nil];
        if(json == nil)
            return false;
        NSArray *friendList = json[@"friendList"];
        NSMutableArray<OsnFriendInfo*> *friendInfoList = [NSMutableArray new];
        for(NSString *o in friendList){
            OsnFriendInfo *friendInfo = [OsnFriendInfo new];
            friendInfo.state = FriendState_Syncst;
            friendInfo.userID = mOsnID;
            friendInfo.friendID = o;
            [friendInfoList addObject:friendInfo];
        }
        if (friendInfoList.count != 0)
            [mCallback onFriendUpdate:friendInfoList];
        return true;
    }
    @catch (NSException *e) {
        NSLog(@"%@",e);
    }
    return false;
}
+ (int) syncMessage:(long) timestamp count:(int)count{
    @try {
        NSMutableDictionary *data = [@{}mutableCopy];
        data[@"timestamp"] = [NSNumber numberWithLong:timestamp];
        data[@"count"] = [NSNumber numberWithInt:count];
        NSDictionary *json = [OsnSDK imRequest:@"MessageSync" to:mServiceID data:data cb:nil];
        if (json != nil) {
            NSArray *array = [json  objectForKey:@"msgList"];
            NSLog(@"msgList: %lu", (unsigned long)array.count);

            bool flag = false;
            NSMutableArray<NSMutableDictionary*> *messageInfos = [NSMutableArray new];

            for (NSString *o : array) {
                NSMutableDictionary *json = [OsnUtils json2dic:[o dataUsingEncoding:NSUTF8StringEncoding]];
                NSString *command = json[@"command"];
                if(command != nil && [command isEqualToString:@"Message"]){
                    [messageInfos addObject:json];
                    flag = true;
                } else {
                    if(flag){
                        flag = false;
                        [OsnSDK handleMessageRecv:messageInfos];
                        [messageInfos removeAllObjects];
                    }
                    [OsnSDK handleMessage:o];
                }
            }
            if (messageInfos.count)
                [OsnSDK handleMessageRecv:messageInfos];
            return (int)array.count;
        }
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return 0;
}
+ (void) handleAddFriend:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    @try {
        OsnRequestInfo *request = [OsnRequestInfo new];
        request.reason = data[@"reason"];
        request.userID = json[@"from"];
        request.friendID = json[@"to"];
        request.timeStamp = ((NSNumber*)json[@"timestamp"]).longValue;
        request.isGroup = false;
        [mCallback onRecvRequest:request];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) handleAgreeFriend:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    NSLog(@"agreeFriend json: %@",json);
    NSLog(@"agreeFriend data: %@",data);
}
+ (void) handleInviteGroup:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    @try {
        OsnRequestInfo *request = [OsnRequestInfo new];
        request.reason = data[@"reason"];
        request.userID = json[@"from"];
        request.friendID = json[@"to"];
        request.timeStamp = ((NSNumber*)json[@"timestamp"]).longValue;
        request.originalUser = data[@"originalUser"];
        request.isGroup = true;
        request.isApply = false;
        [mCallback onRecvRequest:request];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}

+(void) handleJoinGroup:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    @try {
        OsnRequestInfo *request = [OsnRequestInfo new];
        request.reason = data[@"reason"];
        request.userID = json[@"from"];
        request.friendID = json[@"to"];
        request.timeStamp = ((NSNumber*)json[@"timestamp"]).longValue;
        request.originalUser = data[@"originalUser"];
        request.targetUser = data[@"userID"];
        request.isGroup = true;
        request.isApply = true;
        [mCallback onRecvRequest:request];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) handleMessageRecv:(NSArray<NSMutableDictionary*>*) json {
    @try {
        NSMutableArray<OsnMessageInfo*> *messageInfos = [NSMutableArray new];
        for (NSMutableDictionary *o : json) {
            [OsnSDK setMsgSync:o];
            NSMutableDictionary *data = [OsnUtils takeMessage:o key:mOsnKey];
            if(data != nil){
                OsnMessageInfo *messageInfo = [OsnMessageInfo toMessageInfo:o data:data];
                [messageInfos addObject:messageInfo];
            }
        }
        [mCallback onRecvMessage:messageInfos];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}

+ (void) handleMessageRecv:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    @try {
        [OsnSDK setMsgSync:json];
        
        OsnMessageInfo *messageInfo = [OsnMessageInfo toMessageInfo:json data:data];
        [mCallback onRecvMessage:[[NSArray alloc]initWithObjects:messageInfo, nil]];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) handleMessageSync:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    @try {
        NSArray *array = data[@"msgList"];
        NSLog(@"msgList: %lu", array.count);
        for(NSString *o : array)
            [OsnSDK handleMessage:o];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) handleGroupUpdate:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    @try {
        [OsnSDK setMsgSync:json];

        NSArray *array = data[@"infoList"];
        OsnGroupInfo *groupInfo = [OsnGroupInfo toGroupInfo:data];
        [mCallback onGroupUpdate:data[@"state"] info:groupInfo keys:array];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) handleUserUpdate:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    @try{
        [OsnSDK setMsgSync:json];
        
        OsnUserInfo *userInfo = [OsnUserInfo new];
        NSArray *array = data[@"infoList"];
        [mCallback onUserUpdate:userInfo keys:array];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) handleFriendUpdate:(NSMutableDictionary*) json data:(NSMutableDictionary*) data{
    @try{
        OsnFriendInfo *friendInfo = [OsnFriendInfo toFriendInfo:data];
        [mCallback onFriendUpdate:[[NSArray alloc]initWithObjects:friendInfo, nil]];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) handleMessage:(NSString*) msg{
    @try {
        NSMutableDictionary *json = [OsnUtils json2dic:[msg dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *command = json[@"command"];
        NSLog(@"%@: %@",command,msg);
        
        NSString *ids = json[@"id"];
        if(ids != nil){
            synCall sc = mIDMap[ids];
            if(sc != nil){
                sc(ids,json);
                return;
            }
        }
        
        NSMutableDictionary *data = [OsnUtils takeMessage:json key:mOsnKey];
        if(data == nil){
            NSLog(@"[%@] error: takeMessage",command);
            return;
        }
        
        if([command isEqualToString:@"AddFriend"])
            [OsnSDK handleAddFriend:json data:data];
        else if([command isEqualToString:@"AgreeFriend"])
            [OsnSDK handleAgreeFriend:json data:data];
        else if([command isEqualToString:@"InviteGroup"])
            [OsnSDK handleInviteGroup:json data:data];
        else if([command isEqualToString:@"JoinGroup"])
            [OsnSDK handleJoinGroup:json data:data];
        else if([command isEqualToString:@"Message"])
            [OsnSDK handleMessageRecv:json data:data];
        else if([command isEqualToString:@"MessageSync"])
        [OsnSDK handleMessageSync:json data:data];
        else if([command isEqualToString:@"UserUpdate"])
            [OsnSDK handleUserUpdate:json data:data];
        else if([command isEqualToString:@"FriendUpdate"])
            [OsnSDK handleFriendUpdate:json data:data];
        else if([command isEqualToString:@"GroupUpdate"])
            [OsnSDK handleGroupUpdate:json data:data];
        else if([command isEqualToString:@"KickOff"])
            [mCallback onConnectFailed:@"-1:KickOff"];
        else
            NSLog(@"unknow command: %@",command);
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) initWorker{
    if(mSock != 0)
        return;

    dispatch_async(mQueue, ^{
        NSLog(@"Start worker thread.");
        while(true) {
            @try {
                NSLog(@"connect to server: %@",mHost);
                
                mLogined = false;
                mConnect = false;
                mSock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
                
                struct sockaddr_in ser = {0};
                ser.sin_family = AF_INET;
                ser.sin_port = htons(8100);
                ser.sin_addr.s_addr = inet_addr( mHost.UTF8String );
                
                if(connect(mSock, (struct sockaddr*)&ser, sizeof(ser)) < 0){
                    NSLog(@"connect failed");
                    dispatch_async(mQueue, ^{[mCallback onConnectFailed:@"sock connect error"];});
                    sleep(5);
                    continue;
                }
                mConnect = true;
                NSLog(@"connect to server success");
                dispatch_async(mQueue, ^{[mCallback onConnectSuccess:@"connected"];});
                
                @try {
                    Byte head[4] = {0};
                    while(true){
                        if(recv(mSock, head, 4, 0) < 4){
                            NSLog(@"sock read head error");
                            break;
                        }
                        int length = ((head[0] & 0xff) << 24) | ((head[1] & 0xff) << 16) | ((head[2] & 0xff) << 8) | (head[3] & 0xff);
                        Byte *data = (Byte*)malloc(length);
                        if(!data){
                            NSLog(@"malloc error length: %d", length);
                            break;
                        }
                        int read = 0;
                        while(read < length){
                            int ret = (int)recv(mSock, data+read, length-read, 0);
                            if(ret < 0){
                                NSLog(@"sock read data error");
                                break;
                            }
                            read += ret;
                        }
                        __block NSString *msg = [[NSString alloc]initWithData:[NSData dataWithBytesNoCopy:data length:length] encoding:NSUTF8StringEncoding];
                        dispatch_async(mQueue, ^{
                            [OsnSDK handleMessage:msg];
                        });
                    }
                    dispatch_async(mQueue, ^{[mCallback onConnectFailed:@"sock read error"];});
                }
                @catch (NSException* e){
                    NSLog(@"%@",e);
                    dispatch_async(mQueue, ^{[mCallback onConnectFailed:@"exception"];});
                }
                close(mSock);
            } @catch (NSException* e) {
                NSLog(@"%@",e);
                dispatch_async(mQueue, ^{[mCallback onConnectFailed:@"exception"];});
            }
        }
    });
    
    dispatch_async(mQueue, ^{
        NSLog(@"Start heart thread");
        NSMutableDictionary *json = [@{}mutableCopy];
        json[@"command"] = @"Heart";
        int time = 0;
        while(true){
            @try {
                sleep(5);
                if (mSock && mConnect) {
                    if(!mLogined && mOsnID != nil)
                        [OsnSDK loginWithOsnID:mOsnID cb:nil];
                    else if(++time%2) {
                        NSDictionary *result = [OsnSDK sendPackage:json];
                        if(![OsnSDK isSuccess:result]){
                            NSLog(@"heart timeout");
                            close(mSock);
                        }
                    }
                    
                }
            }
            @catch (NSException* e){
                NSLog(@"%@",e);
            }
        }
    });
}

+ (void) initSDK:(NSString*) ip cb:(id<OsnCallback>)cb{
    mHost = ip;
    mCallback = cb;
    mOsnID = [[NSUserDefaults standardUserDefaults] objectForKey:@"osnID"];
    mOsnKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"osnKey"];
    mAesKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"aesKey"];
    mServiceID = [[NSUserDefaults standardUserDefaults] objectForKey:@"serviceID"];
    NSNumber *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"msgSync"];
    if(data != nil)
        mMsgSync = data.longValue;
    else {
        mMsgSync = [OsnUtils getTimeStamp];
        [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithLong:mMsgSync] forKey:@"msgSync"];
    }
    data = [[NSUserDefaults standardUserDefaults] objectForKey:@"initSync"];
    mInitSync = data != nil;
    mDeviceID = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceID"];
    if(mDeviceID == nil){
        mDeviceID = [OsnUtils createUUID];
        [[NSUserDefaults standardUserDefaults] setValue:mDeviceID forKey:@"deviceID"];
    }
    [OsnSDK initWorker];
}
+ (void) resetHost:(NSString*) ip{
    @try {
        mHost = ip;
        if(mSock != 0)
            close(mSock);
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) registerUser:(NSString*) userName pwd:(NSString*) password sid:(NSString*) serviceID cb:(onResult)cb{
    @try {
        NSMutableDictionary *json = [@{}mutableCopy];
        json[@"username"] = userName;
        json[@"password"] = password;
        [OsnSDK imRequest:@"Register" to:serviceID data:json cb:cb];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
        if(cb != nil)
            cb(false,nil,e.reason);
    }
}
+ (bool) loginWithOsnID:(NSString *)userID cb:(onResult)cb{
    return [OsnSDK login:userID key:mAesKey type:@"osn" cb:cb];
}
+ (bool) loginWithName:(NSString *)userName pwd:(NSString *)password cb:(onResult)cb{
    return [OsnSDK login:userName key:[OsnUtils b64Encode:[OsnUtils sha256:[password dataUsingEncoding:NSUTF8StringEncoding]]] type:@"user" cb:cb];
}
+ (void) logout:(onResult)cb{
    @try {
        mOsnID = nil;
        mLogined = false;
        [[NSUserDefaults standardUserDefaults] setValue:mOsnID forKey:@"osnID"];
        if(mSock != 0)
            close(mSock);
        if(cb != nil)
            cb(true,nil,nil);
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
        if(cb != nil)
            cb(false,nil,e.reason);
    }
}
+ (NSString*) getUserID{
    return mOsnID;
}
+ (NSString*) getServiceID{
    return mServiceID;
}
+ (OsnUserInfo*) getUserInfo:(NSString*) userID cb:(onResultT)cb{
    @try {
        if(cb == nil){
            NSDictionary *json = [OsnSDK imRequest:@"GetUserInfo" to:userID data:nil cb:nil];
            if(json == nil)
                return nil;
            return [OsnUserInfo toUserInfo:json];
        }
        [OsnSDK imRequest:@"GetUserInfo" to:userID data:nil cb:^(bool isSuccess, NSDictionary *json, NSString *error){
            OsnUserInfo *userInfo = nil;
            if(json != nil)
                userInfo = [OsnUserInfo toUserInfo:json];
            cb(isSuccess,userInfo,error);
        }];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (OsnGroupInfo*) getGroupInfo:(NSString*) groupID cb:(onResultT)cb{
    @try {
        if(cb == nil){
            NSDictionary *json = [OsnSDK imRequest:@"GetGroupInfo" to:groupID data:nil cb:nil];
            if(json == nil)
                return nil;
            return [OsnGroupInfo toGroupInfo:json];
        }
        [OsnSDK imRequest:@"GetGroupInfo" to:groupID data:nil cb:^(bool isSuccess, NSDictionary *json, NSString *error){
            OsnGroupInfo *groupInfo = nil;
            if(json != nil)
                groupInfo = [OsnGroupInfo toGroupInfo:json];
            cb(isSuccess,groupInfo,error);
        }];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (NSArray*) getMemberInfo:(NSString*) groupID cb:(onResultT)cb{
    @try {
        if(cb == nil){
            NSDictionary *json = [OsnSDK imRequest:@"GetMemberInfo" to:groupID data:nil cb:nil];
            if(json == nil)
                return nil;
            return [OsnMemberInfo toMemberInfos:json];
        }
        [OsnSDK imRequest:@"GetMemberInfo" to:groupID data:nil cb:^(bool isSuccess, NSDictionary *json, NSString *error){
            NSArray<OsnMemberInfo*> *memberInfos = nil;
            if(json != nil)
                memberInfos = [OsnMemberInfo toMemberInfos:json];
            cb(isSuccess,memberInfos,error);
        }];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (OsnServiceInfo*) getServiceInfo:(NSString*) serviceID cb:(onResultT)cb{
    @try {
        if(cb == nil){
            NSDictionary *json = [OsnSDK imRequest:@"GetServiceInfo" to:serviceID data:nil cb:nil];
            if(json == nil)
                return nil;
            return [OsnServiceInfo toServiceInfo:json];
        }
        [OsnSDK imRequest:@"GetServiceInfo" to:serviceID data:nil cb:^(bool isSuccess, NSDictionary *json, NSString *error){
            OsnServiceInfo *serviceInfo = nil;
            if(json != nil)
                serviceInfo = [OsnServiceInfo toServiceInfo:json];
            cb(isSuccess,serviceInfo,error);
        }];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (OsnFriendInfo*) getFriendInfo:(NSString*) friendID cb:(onResultT)cb{
    @try {
        NSMutableDictionary* data = [NSMutableDictionary new];
        data[@"friendID"] = friendID;
        if(cb == nil){
            NSDictionary *json = [OsnSDK imRequest:@"GetFriendInfo" to:mServiceID data:data cb:nil];
            if(json == nil)
                return nil;
            return [OsnFriendInfo toFriendInfo:json];
        }
        [OsnSDK imRequest:@"GetFriendInfo" to:mServiceID data:data cb:^(bool isSuccess, NSDictionary *json, NSString *error){
            OsnFriendInfo *info = nil;
            if(json != nil)
                info = [OsnFriendInfo toFriendInfo:json];
            cb(isSuccess,info,error);
        }];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (void) modifyUserInfo:(NSArray*) keys info:(OsnUserInfo*) userInfo cb:(onResult)cb{
    @try {
        NSMutableDictionary *data = [@{}mutableCopy];
        for(NSString *k in keys){
            if([k isEqualToString:@"displayName"])
                data[@"displayName"] = userInfo.displayName;
            else if([k isEqualToString:@"portrait"])
                data[@"portrait"] = userInfo.portrait;
            else if([k isEqualToString:@"urlSpace"])
                data[@"urlSpace"] = userInfo.portrait;
        }
        [OsnSDK imRequest:@"SetUserInfo" to:mServiceID data:data cb:cb];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (void) modifyFriendInfo:(NSArray*) keys info:(OsnFriendInfo*) friendInfo cb:(onResult)cb{
    @try {
        NSMutableDictionary *data = [@{}mutableCopy];
        data[@"friendID"] = friendInfo.friendID;
        for(NSString *k in keys){
            if([k isEqualToString:@"remarks"])
                data[@"remarks"] = friendInfo.remarks;
            else if([k isEqualToString:@"state"])
                data[@"state"] = @(friendInfo.state);
        }
        [OsnSDK imRequest:@"SetFriendInfo" to:mServiceID data:data cb:cb];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
}
+ (NSArray*) getFriendList:(onResultT)cb{
    @try {
        if(cb == nil){
            NSDictionary *json = [OsnSDK imRequest:@"GetFriendList" to:mServiceID data:nil cb:nil];
            if(json == nil)
                return nil;
            NSMutableArray *friendInfoList = [NSMutableArray array];
            NSArray *friendList = [json objectForKey:@"friendList"];
            for(NSString *o in friendList)
                [friendInfoList addObject:o];
            return friendInfoList;
        }
        [OsnSDK imRequest:@"GetFriendList" to:mServiceID data:nil cb:^(bool isSuccess, NSDictionary *json, NSString *error){
            NSMutableArray *friendInfoList = [NSMutableArray array];
            if(json != nil){
                NSArray *friendList = [json objectForKey:@"friendList"];
                for(NSString *o in friendList)
                    [friendInfoList addObject:o];
            }
            cb(isSuccess,friendInfoList,error);
        }];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (NSArray*) getGroupList:(onResultT)cb{
    @try {
        if(cb == nil){
            NSMutableDictionary *json = [OsnSDK imRequest:@"GetGroupList" to:mServiceID data:nil cb:nil];
            if(json == nil)
                return nil;
            NSMutableArray *groupInfoList = [NSMutableArray new];
            NSArray *groupList = json[@"groupList"];
            for(NSString *o in groupList)
                [groupInfoList addObject:o];
            return groupInfoList;
        }
        [OsnSDK imRequest:@"GetFriendList" to:mServiceID data:nil cb:^(bool isSuccess, NSDictionary *json, NSString *error){
            NSMutableArray *friendInfoList = [NSMutableArray new];
            if(json != nil){
                NSArray *friendList = json[@"friendList"];
                for(NSString *o in friendList)
                    [friendInfoList addObject:o];
            }
            cb(isSuccess,friendInfoList,error);
        }];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (void) inviteFriend:(NSString*) userID reason:(NSString*) reason cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"reason"] = reason;
    [OsnSDK imRequest:@"AddFriend" to:userID data:data cb:cb];
}
+ (void) deleteFriend:(NSString*) userID cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"friendID"] = userID;
    [OsnSDK imRequest:@"DelFriend" to:mServiceID data:data cb:cb];
}
+ (void) acceptFriend:(NSString*) userID cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    [OsnSDK imRequest:@"AgreeFriend" to:userID data:data cb:cb];
}
+ (void) rejectFriend:(NSString*) userID cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    [OsnSDK imRequest:@"RejectFriend" to:userID data:data cb:cb];
}
+ (void) acceptMember:(NSString*) userID groupID:(NSString*)groupID cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"userID"] = userID;
    [OsnSDK imRequest:@"AgreeMember" to:groupID data:data cb:cb];
}
+ (void) rejectMember:(NSString*) userID groupID:(NSString*)groupID cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"userID"] = userID;
    [OsnSDK imRequest:@"RejectMember" to:groupID data:data cb:cb];
}
+ (void) sendMessage:(NSString*) text userID:(NSString*) userID cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"content"] = text;
    if(!strncmp(text.UTF8String,"OSNG",4))
        data[@"originalUser"] = mOsnID;
    [OsnSDK imRequest:@"Message" to:userID data:data cb:cb];
}
+ (NSArray<OsnMessageInfo*>*) loadMessage:(NSString*) userID timestamp:(long)timestamp count:(int)count before:(bool) before cb:(onResultT)cb {
    @try {
        NSMutableDictionary *data = [NSMutableDictionary new];
        data[@"userID"] = userID;
        data[@"timestamp"] = @(timestamp);
        data[@"count"] = @(count);
        data[@"before"] = @(before);
        if(cb == nil){
            NSMutableDictionary *json = [OsnSDK imRequest:@"MessageLoad" to:mServiceID data:data cb:cb];
            if(json == nil)
                return nil;
            return [OsnSDK getMessages:json];
        }
        [OsnSDK imRequest:@"MessageLoad" to:mServiceID data:data cb:^(bool isSuccess, NSDictionary *json, NSString *error){
            NSArray<OsnMessageInfo*>* messages = [@[]mutableCopy];
            if(json != nil)
                messages = [OsnSDK getMessages:json];
            cb(isSuccess,messages,error);
        }];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (void) createGroup:(NSString*) groupName membser:(NSArray*) member type:(int)type portrait:(NSString*) portrait cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"name"] = groupName;
    data[@"type"] = @(type);
    data[@"portrait"] = portrait;
    data[@"userList"] = member;
    [OsnSDK imRequest:@"CreateGroup" to:mServiceID data:data cb:cb];
}
+ (void) joinGroup:(NSString*) groupID reason:(NSString*)reason cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    if(reason != nil)
        data[@"reason"] = reason;
    [OsnSDK imRequest:@"JoinGroup" to:groupID data:data cb:cb];
}
+ (void) rejectGroup:(NSString*) groupID cb:(onResult)cb{
    [OsnSDK imRequest:@"RejectGroup" to:groupID data:nil cb:cb];
}
+ (void) addMember:(NSString*) groupID members:(NSArray*) members cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"state"] = @"AddMember";
    data[@"memberList"] = members;
    [OsnSDK imRequest:@"AddMember" to:groupID data:data cb:cb];
}
+ (void) delMember:(NSString*) groupID members:(NSArray*) members cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"state"] = @"DelMember";
    data[@"memberList"] = members;
    [OsnSDK imRequest:@"DelMember" to:groupID data:data cb:cb];
}
+ (void) quitGroup:(NSString*) groupID cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"state"] = @"QuitGroup";
    [OsnSDK imRequest:@"QuitGroup" to:groupID data:data cb:cb];
}
+ (void) dismissGroup:(NSString*) groupID cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"state"] = @"DelGroup";
    [OsnSDK imRequest:@"DelGroup" to:groupID data:data cb:cb];
}
+ (void) modifyGroupInfo:(NSArray*) keys groupInfo:(OsnGroupInfo*) groupInfo cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    for(NSString *k in keys){
        if([k isEqualToString:@"name"])
            data[@"name"] = groupInfo.name;
        else if([k isEqualToString:@"portrait"])
            data[@"portrait"] = groupInfo.portrait;
        else if([k isEqualToString:@"type"])
            data[@"type"] = @(groupInfo.type);
        else if([k isEqualToString:@"joinType"])
            data[@"joinType"] = @(groupInfo.joinType);
        else if([k isEqualToString:@"passType"])
            data[@"passType"] = @(groupInfo.passType);
        else if([k isEqualToString:@"mute"])
            data[@"mute"] = @(groupInfo.mute);
    }
    [OsnSDK imRequest:@"SetGroupInfo" to:groupInfo.groupID data:data cb:cb];
}
+ (void) modifyMemberInfo:(NSArray*) keys memberInfo:(OsnMemberInfo*) memberInfo cb:(onResult)cb{
    NSMutableDictionary *data = [NSMutableDictionary new];
    for(NSString *k in keys){
        if([k isEqualToString:@"nickName"])
            data[@"nickName"] = memberInfo.nickName;
    }
    [OsnSDK imRequest:@"SetMemberInfo" to:memberInfo.groupID data:data cb:cb];
}
+ (void) uploadData:(NSString*) fileName type:(NSString*) type data:(NSData*) data cb:(onResult)cb progress:(onProgress)progress{
    HttpUtils *http = [HttpUtils new];
    NSString *url = [NSString stringWithFormat:@"http://%@:8800/",mHost];
    if(cb == nil){
        [http upload:url type:type name:fileName data:data cb:cb progress:progress];
    } else {
        dispatch_async(mQueue, ^(){
            [http upload:url type:type name:fileName data:data cb:cb progress:progress];
        });
    }
}
+ (void) downloadData:(NSString*) remoteUrl localPath:(NSString*) localPath cb:(onResult)cb progress:(onProgress)progress{
    HttpUtils *http = [HttpUtils new];
    if(cb == nil){
        [http download:remoteUrl path:localPath cb:cb progress:progress];
    } else {
        dispatch_async(mQueue, ^(){
            [http download:remoteUrl path:localPath cb:cb progress:progress];
        });
    }
}
+ (void) lpLogin:(OsnLitappInfo*) litappInfo url:(NSString*) url cb:(onResult)cb {
    dispatch_async(mQueue, ^(){
        @try {
            long randClient = [OsnUtils getTimeStamp];
            NSMutableDictionary *json = [NSMutableDictionary new];
            json[@"command"] = @"GetServerInfo";
            json[@"user"] = mOsnID;
            json[@"random"] = @(randClient);
            NSData *data = [HttpUtils doPost:url data:[OsnUtils dic2json:json]];
            if(data == nil){
                cb(false, nil, @"post failed");
                return;
            }
            NSDictionary *jsonRecv = [OsnUtils json2dic:data];
            NSString *serviceID = jsonRecv[@"serviceID"];
            NSString *randServer = jsonRecv[@"random"];
            NSString *serverInfo = jsonRecv[@"serviceInfo"];
            NSString *session = jsonRecv[@"session"];
            NSString *hash = jsonRecv[@"hash"];
            NSString *sign = jsonRecv[@"sign"];
            
            if(![serviceID isEqualToString:litappInfo.target]){
                cb(false, nil, [NSString stringWithFormat:@"serviceID no equals litappID: %@, serviceID: %@",litappInfo.target,serviceID]);
                return;
            }
            NSString *datas = [NSString stringWithFormat:@"%@%@%@%@%@",mOsnID,@(randClient),serviceID,randServer,serverInfo];
            NSString *hashCheck = [ECUtils osnHash:[datas dataUsingEncoding:NSUTF8StringEncoding]];
            NSLog(@"%@",hashCheck);
            if(![hashCheck isEqualToString:hash]){
                cb(false,nil,@"hash verify failed");
                return;
            }
            if(![ECUtils osnVerify:serviceID data:[hash dataUsingEncoding:NSUTF8StringEncoding] sign:sign]){
                cb(false,nil,@"sign verify failed");
                return;
            }
            datas = [NSString stringWithFormat:@"%@%@%@%@",serviceID,randServer,mOsnID,@(randClient)];
            hash = [ECUtils osnHash:[datas dataUsingEncoding:NSUTF8StringEncoding]];
            sign = [ECUtils osnSign:mOsnKey data:[hash dataUsingEncoding:NSUTF8StringEncoding]];
            [json removeAllObjects];
            json[@"command"] = @"Login";
            json[@"user"] = mOsnID;
            json[@"hash"] = hash;
            json[@"sign"] = sign;
            json[@"session"] = session;
            data = [HttpUtils doPost:url data:[OsnUtils dic2json:json]];
            if(data == nil){
                cb(false, nil, @"post 2 failed");
                return;
            }
            jsonRecv = [OsnUtils json2dic:data];
            if(![OsnSDK isSuccess:jsonRecv]){
                cb(false,nil,[OsnSDK errCode:jsonRecv]);
            } else {
                NSString *sessionKey = jsonRecv[@"sessionKey"];
                NSData *sessionData = [ECUtils ecDecrypt2:mOsnKey data:sessionKey];
                NSMutableDictionary *result = [jsonRecv mutableCopy];
                result[@"sessionKey"] = [[NSString alloc]initWithData:sessionData encoding:NSUTF8StringEncoding];
                cb(true,result,nil);
            }
            return;
        }
        @catch (NSException* e){
            NSLog(@"%@",e);
            cb(false,nil,e.reason);
        }
    });
}

+ (NSString*) signData:(NSString*) data {
    return [ECUtils osnSign:mOsnKey data:[data dataUsingEncoding:NSUTF8StringEncoding]];
}
@end
