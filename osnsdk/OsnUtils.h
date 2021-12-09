@interface OsnUtils : NSObject
+ (NSString*) b64Encode:(NSData*)data;
+ (NSData*) b64Decode:(NSString*)data;
+ (NSString*) dic2json:(NSDictionary*)json;
+ (NSMutableDictionary*)json2dic:(NSData*)data;
+ (NSData*) sha256:(NSData*) data;
+ (long) getTimeStamp;
+ (NSString*) createUUID;
+ (NSString*) aesEncrypt:(NSData*)data keyData:(NSData*) key;
+ (NSString*) aesEncrypt:(NSString*) data keyStr:(NSString*) key;
+ (NSData*) aesDecrypt:(NSData*) data keyData:(NSData*) key;
+ (NSString*) aesDecrypt:(NSString*) data keyStr:(NSString*) key;
+ (NSMutableDictionary*) makeMessage:(NSString*) command from:(NSString*) from to:(NSString*) to data:(NSDictionary*) data key:(NSString*) key;
+ (NSMutableDictionary*) takeMessage:(NSDictionary*) json key:(NSString*) key;
@end
