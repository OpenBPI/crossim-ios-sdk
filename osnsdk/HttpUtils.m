//
//  HttpUtils.m
//  WFChatClient
//
//  Created by abc on 2021/1/20.
//  Copyright © 2021 WildFireChat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HttpUtils.h"
#import "OsnUtils.h"

@implementation HttpUtils

+ (NSData*) doGet:(NSString*)url {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:0 timeoutInterval:5.0f];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    __block NSData *result = nil;
    NSURLSession *session = [NSURLSession sharedSession];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        result = data;
        dispatch_semaphore_signal(semaphore);
    }]resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC*10));
    return result;
}
+ (NSData*) doPost:(NSString*)url data:(NSString*)data{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:0 timeoutInterval:5.0f];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [data dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    __block NSData *result = nil;
    NSURLSession *session = [NSURLSession sharedSession];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        result = data;
        dispatch_semaphore_signal(semaphore);
    }]resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC*10));
    return result;
}
- (void) upload:(NSString*) sUrl type:(NSString*) type name:(NSString*) fileName data:(NSData*) data cb:(onResult)cb progress:(onProgress)progress{
    @try{
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:sUrl] cachePolicy:0 timeoutInterval:5.0f];
    
        NSString *boundary = [NSString stringWithFormat:@"----------%ld",[OsnUtils getTimeStamp]];
        [request setHTTPMethod:@"POST"];
        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary] forHTTPHeaderField:@"Content-Type"];
        
        NSMutableData *body = [NSMutableData data];
        NSString* prefix = [type isEqualToString:@"portrait"] ? @"P":@"C";
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary]dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;name=\"%@%@\"\r\n\r\n\r\n",prefix,fileName]dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary]dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;name=\"file\";filename=\"%@%@\"\r\n",prefix,fileName]dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Type:application/octet-stream\r\n\r\n"]dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:data];
        [body appendData:[[NSString stringWithFormat:@"\r\n\r\n--%@--\r\n",boundary]dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionUploadTask *task = [session uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error) {
                NSDictionary *json = [OsnUtils json2dic:data];
                cb(true,json,nil);
            }else{
                NSLog(@"error --- %@", error.localizedDescription);
                cb(false,nil,error.localizedDescription);
            }
        }];
        self.progress = progress;
        [task resume];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
        if(cb != nil)
            cb(false,nil,e.reason);
    }
}
- (void) download:(NSString*) sUrl path:(NSString*) path cb:(onResult)cb progress:(onProgress)progress{
    @try {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:sUrl] cachePolicy:0 timeoutInterval:5.0f];
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if(!error){
                cb(true,nil,nil);
            }else{
                NSLog(@"error --- %@", error.localizedDescription);
                cb(false,nil,error.localizedDescription);
            }
        }];
        self.downPath = path;
        self.progress = progress;
        [task resume];
    }
    @catch (NSException* e){
        NSLog(@"%@",e);
        cb(false,nil,e.reason);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:self.downPath error:nil];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.progress(bytesWritten,totalBytesWritten);
}
- (void)URLSession:(NSURLSession *)session task: (NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"%@",error);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    self.progress(bytesSent,totalBytesSent);
}

@end

    
