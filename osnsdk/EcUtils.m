//
//  EcUtils.m
//  WFChatClient
//
//  Created by abc on 2021/1/21.
//  Copyright © 2021 WildFireChat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EcUtils.h"
#import "OsnUtils.h"
#import <ecSSL/ecSSL.h>

@implementation ECUtils

+ (NSData*) toPublicKey:(NSString*) osnID{
    NSString *pubKey = [osnID substringFromIndex:4];
    NSData *pKey = [ECUtils b58Decode:pubKey];
    return [pKey subdataWithRange:NSMakeRange(2, pKey.length-2)];
}
+ (NSData*) toPrivateKey:(NSString*) osnID{
    NSString *priKey = [osnID substringFromIndex:3];
    return [OsnUtils b64Decode:priKey];
}

+ (NSString*) osnHash:(NSData*) data{
    NSData *hash = [OsnUtils sha256:data];
    return [OsnUtils b64Encode:hash];
}
+ (NSString*) osnSign:(NSString*) priKey data:(NSData*) data{
    @try {
        NSData *pKey = [ECUtils toPrivateKey:priKey];
        NSData *sign = [ecSSL ecSignSSL:pKey data:data];
        if(sign == nil)
            return nil;
        return [OsnUtils b64Encode:sign];
    }
    @catch (NSException *e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (BOOL) osnVerify:(NSString*) osnID data:(NSData*) data sign:(NSString*) sign{
    @try {
        NSData *signData = [OsnUtils b64Decode:sign];
        NSData *pKey = [ECUtils toPublicKey:osnID];
        if(pKey == nil)
            return nil;
        return [ecSSL ecVerifySSL:pKey data:data sig:signData];
    }
    @catch (NSException *e){
        NSLog(@"%@",e);
    }
    return false;
}
+ (NSData*) ecIESEncrypt:(NSString*) osnID data:(NSData*) data{
    NSData *pKey = [ECUtils toPublicKey:osnID];
    if(pKey == nil)
        return nil;
    return [ecSSL ecIESEncryptSSL:pKey data:data];
}
+ (NSData*) ecIESDecrypt:(NSString*) priKey data:(NSData*) data{
    NSData *pKey = [ECUtils toPrivateKey:priKey];
    return [ecSSL ecIESDecryptSSL:pKey data:data];
}
+ (NSArray*) createOsnID:(NSString*) type{
    @try {
        NSData *priKey = [ecSSL ecCreateKey];
        NSData *pubKey = [ecSSL ecGetPublicKey:priKey];
        
        int klen = (int)(1 + 1 + pubKey.length);
        uint8_t *addr = (uint8_t*)malloc(klen);
        addr[0] = 1;
        addr[1] = 0;
        NSString *osnType = @"OSNU";
        if([type isEqualToString:@"group"]){
            addr[1] = 1;
            osnType = @"OSNG";
        }
        else if([type isEqualToString:@"service"]){
            addr[1] = 2;
            osnType = @"OSNS";
        }
        memcpy(&addr[2],pubKey.bytes,pubKey.length);
        NSString *osnID = [NSString stringWithFormat:@"%@%@",osnType,[ECUtils b58Encode:[NSData dataWithBytesNoCopy:addr length:klen]]];
        NSString *osnKey = [NSString stringWithFormat:@"VK0%@",[OsnUtils b64Encode:priKey]];
        return [NSArray arrayWithObjects:osnID,osnKey, nil];
    }
    @catch (NSException *e){
        NSLog(@"%@",e);
    }
    return nil;
}
+ (NSString*) ecEncrypt2:(NSString*) osnID data:(NSData*) data{
    NSData *encData = [ECUtils ecIESEncrypt:osnID data:data];
    return [OsnUtils b64Encode:encData];
}
+ (NSData*) ecDecrypt2:(NSString*) priKey data:(NSString*) data{
    return [ECUtils ecIESDecrypt:priKey data:[OsnUtils b64Decode:data]];
}
+ (NSString*) b58Encode:(NSData*) data{
    return [ecSSL b58Encode:data];
}
+ (NSData*) b58Decode:(NSString*) data{
    return [ecSSL b58Decode:data];
}
@end
