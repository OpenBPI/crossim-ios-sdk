#import "Callback.h"

@interface HttpUtils : NSObject <NSURLSessionDelegate>
+ (NSData*) doGet:(NSString*)url;
+ (NSData*) doPost:(NSString*)url data:(NSString*)data;
- (void) upload:(NSString*) sUrl type:(NSString*)type name:(NSString*) fileName data:(NSData*) data cb:(onResult)cb progress:(onProgress)progress;
- (void) download:(NSString*) sUrl path:(NSString*) path cb:(onResult)cb progress:(onProgress)progress;
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location;
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;
- (void)URLSession:(NSURLSession *)session task: (NSURLSessionTask *)task didCompleteWithError:(NSError *)error;
@property NSString *downPath;
@property onProgress progress;
@end
