//
//  OsnUtils.m
//  sdktest
//
//  Created by abc on 2021/1/14.
//  Copyright © 2021 test. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>
#import "OsnUtils.h"
#import "EcUtils.h"
#import <ecSSL/ecSSL.h>
#import "osnsdk.h"

@implementation OsnUtils

+ (NSString*) b64Encode:(NSData*)data{
    data = [data base64EncodedDataWithOptions:0];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}
+ (NSData*) b64Decode:(NSString*)data{
    return [[NSData alloc]initWithBase64EncodedString:data options:0];
}
+ (NSString*) dic2json:(NSDictionary*)json{
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
+ (NSMutableDictionary*)json2dic:(NSData*)data{
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
}
+ (NSData*) sha256:(NSData*) data{
    Byte result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes,(int)data.length,result);
    return [NSMutableData dataWithBytes:result length:CC_SHA256_DIGEST_LENGTH];
}
+ (NSString*) aesEncrypt:(NSData*)data keyData:(NSData*) key{
    @try {
        NSData *encData = [ecSSL aesEncrypt:key data:data];
        return [OsnUtils b64Encode:encData];
    }
    @catch (NSException *exception){
        NSLog(@"%@", exception);
    }
    return nil;
}
+ (NSString*) aesEncrypt:(NSString*) data keyStr:(NSString*) key{
    NSData *hash = [OsnUtils sha256:[NSData dataWithData:[key dataUsingEncoding:NSUTF8StringEncoding]]];
    return [OsnUtils aesEncrypt:[data dataUsingEncoding:NSUTF8StringEncoding] keyData:hash];
}
+ (NSData*) aesDecrypt:(NSData*) data keyData:(NSData*) key{
    @try {
        return [ecSSL aesDecrypt:key data:data];
    }
    @catch (NSException *exception){
        NSLog(@"%@", exception);
    }
    return nil;
}
+ (NSString*) aesDecrypt:(NSString*) data keyStr:(NSString*) key{
    NSData *hash = [OsnUtils sha256:[NSData dataWithData:[key dataUsingEncoding:NSUTF8StringEncoding]]];
    NSData *decData = [OsnUtils b64Decode:data];
    decData = [OsnUtils aesDecrypt:decData keyData:hash];
    return [[NSString alloc]initWithData:decData encoding:NSUTF8StringEncoding];
}
+ (NSData*) getAesKey{
    uint8_t *key = (uint8_t*)malloc(32);
    for(int i = 0; i < 32; ++i)
        key[i] = arc4random_uniform(256);
    return [NSData dataWithBytesNoCopy:key length:32];
}
+ (long) getTimeStamp{
    return [[NSDate date] timeIntervalSince1970] * 1000;
}
+ (NSString*) createUUID{
    CFUUIDRef uuid_ref = CFUUIDCreate(nil);
    CFStringRef uuid_string_ref = CFUUIDCreateString(nil, uuid_ref);
    NSString *uuid = [NSString stringWithString:(__bridge NSString*)uuid_string_ref];
    CFRelease(uuid_string_ref);
    CFRelease(uuid_ref);
    return [uuid lowercaseString];
}
+ (NSMutableDictionary*) makeMessage:(NSString*) command from:(NSString*) from to:(NSString*) to data:(NSDictionary*) data key:(NSString*) key{
    @try {
        NSMutableDictionary *json = [NSMutableDictionary new];
        json[@"command"] = command;
        json[@"from"] = from;
        json[@"to"] = to;
        
        if(data == nil){
            json[@"content"] = @"{}";
            json[@"crypto"] = @"none";
        }
        else{
            NSData *aesKey = [OsnUtils getAesKey];
            NSString *encData = [OsnUtils aesEncrypt:[NSJSONSerialization dataWithJSONObject:data options:kNilOptions error:nil] keyData:aesKey];
            json[@"content"] = encData;
            json[@"crypto"] = @"ecc-aes";
            
            NSString *encKey = [ECUtils ecEncrypt2:to data:aesKey];
            json[@"ecckey"] = encKey;
            
            if(key != nil){
                NSData *msgKey = [OsnUtils sha256:[key dataUsingEncoding:NSUTF8StringEncoding]];
                json[@"aeskey"] = [OsnUtils aesEncrypt:aesKey keyData:msgKey];
            }
        }

        long timestamp = [OsnUtils getTimeStamp];
        NSString *calc = [from stringByAppendingFormat:@"%@%ld%@",to,timestamp,[json objectForKey:@"content"]];
        NSString *hash = [ECUtils osnHash:[calc dataUsingEncoding:NSUTF8StringEncoding]];
        json[@"hash"] = hash;
        json[@"timestamp"] = @(timestamp);

        if(key != nil){
            NSString *sign = [ECUtils osnSign:key data:[hash dataUsingEncoding:NSUTF8StringEncoding]];
            json[@"sign"] = sign;
        }
        
        return json;
    }
    @catch (NSException *exception){
        NSLog(@"%@", exception);
    }
    return nil;
}
+ (NSMutableDictionary*) takeMessage:(NSMutableDictionary*) json key:(NSString*) key{
    @try {
        NSData *data;
        NSData *aesKey;
        NSString *crypto = json[@"crypto"];
        if([crypto isEqualToString:@"none"]){
            NSString *content = json[@"content"];
            return [OsnUtils json2dic:[content dataUsingEncoding:NSUTF8StringEncoding]];
        }
        else if([crypto isEqualToString:@"ecc-aes"]){
            if([json[@"to"] isEqualToString:[OsnSDK getUserID]])
                aesKey = [ECUtils ecDecrypt2:key data:json[@"ecckey"]];
            else if(json[@"aeskey"] != nil){
                data = [OsnUtils b64Decode:json[@"aeskey"]];
                aesKey = [OsnUtils aesDecrypt:data keyData:[OsnUtils sha256:[key dataUsingEncoding:NSUTF8StringEncoding]]];
            }
            else{
                NSLog(@"unknown key mode");
                return nil;
            }
        }
        else if([crypto isEqualToString:@"aes"]){
            data = [OsnUtils b64Decode:json[@"aeskey"]];
            aesKey = [OsnUtils aesDecrypt:data keyData:[OsnUtils sha256:[key dataUsingEncoding:NSUTF8StringEncoding]]];
        }
        else{
            NSLog(@"unsupport crypto");
            return nil;
        }
        
        data = [OsnUtils b64Decode:json[@"content"]];
        data = [OsnUtils aesDecrypt:data keyData:aesKey];
        return [OsnUtils json2dic:data];
    }
    @catch (NSException *exception){
        NSLog(@"%@", exception);
    }
    return nil;
}

@end
