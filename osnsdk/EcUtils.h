
@interface ECUtils : NSObject
+ (NSString*) osnHash:(NSData*) data;
+ (NSString*) osnSign:(NSString*) priKey data:(NSData*) data;
+ (BOOL) osnVerify:(NSString*) osnID data:(NSData*) data sign:(NSString*) sign;
+ (NSData*) ecIESEncrypt:(NSString*) osnID data:(NSData*) data;
+ (NSData*) ecIESDecrypt:(NSString*) priKey data:(NSData*) data;
+ (NSArray*) createOsnID:(NSString*) type;
+ (NSString*) ecEncrypt2:(NSString*) osnID data:(NSData*) data;
+ (NSData*) ecDecrypt2:(NSString*) priKey data:(NSString*) data;
+ (NSString*) b58Encode:(NSData*) data;
+ (NSData*) b58Decode:(NSString*) data;
@end
