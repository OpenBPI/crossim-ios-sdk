
#import <Foundation/Foundation.h>

@interface ecSSL : NSObject
+ (NSData*)sha256:(NSData*) data;
+ (NSData*)aesEncrypt:(NSData*) key data:(NSData*) data;
+ (NSData*)aesDecrypt:(NSData*) key data:(NSData*) data;
+ (NSData*)ecIESEncryptSSL:(NSData*) pubKey data:(NSData*) data;
+ (NSData*)ecIESDecryptSSL:(NSData*) priKey data:(NSData*) data;
+ (NSData*)ecCreateKey;
+ (NSData*)ecGetPublicKey:(NSData*) data;
+ (NSData*)ecSignSSL:(NSData*) priKey data:(NSData*) data;
+ (bool)ecVerifySSL:(NSData*) pubKey data:(NSData*) data sig:(NSData*) sig;
+ (NSString*)b58Encode:(NSData*) data;
+ (NSData*)b58Decode:(NSString*) data;
@end
