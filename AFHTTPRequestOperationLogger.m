// AFHTTPRequestLogger.h
//
// Copyright (c) 2011 AFNetworking (http://afnetworking.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFHTTPRequestOperationLogger.h"
#import "AFHTTPRequestOperation.h"

#import <objc/runtime.h>

@implementation AFHTTPRequestOperationLogger

+ (instancetype)sharedLogger {
    static AFHTTPRequestOperationLogger *_sharedLogger = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedLogger = [[self alloc] init];
    });
    
    return _sharedLogger;
}

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.level = AFLoggerLevelInfo;
    
    return self;
}

- (void)dealloc {
    [self stopLogging];
}

- (void)startLogging {
    [self stopLogging];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(HTTPOperationDidStart:) name:AFNetworkingOperationDidStartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(HTTPOperationDidFinish:) name:AFNetworkingOperationDidFinishNotification object:nil];
}

- (void)stopLogging {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - NSNotification

static void * AFHTTPRequestOperationStartDate = &AFHTTPRequestOperationStartDate;

- (void)HTTPOperationDidStart:(NSNotification *)notification {
    AFHTTPRequestOperation *operation = (AFHTTPRequestOperation *)[notification object];
    
    if (![operation isKindOfClass:[AFHTTPRequestOperation class]]) {
        return;
    }
    
    objc_setAssociatedObject(operation, AFHTTPRequestOperationStartDate, [NSDate date], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (self.filterPredicate && [self.filterPredicate evaluateWithObject:operation]) {
        return;
    }
    
    NSString *body = nil;
    if ([operation.request HTTPBody]) {
        body = [[NSString alloc] initWithData:[operation.request HTTPBody] encoding:NSUTF8StringEncoding];
    }
    
    switch (self.level) {
        case AFLoggerLevelDebug:
            NSLog(@"%@ '%@': %@ %@", [operation.request HTTPMethod], [[operation.request URL] absoluteString], [operation.request allHTTPHeaderFields], body);
            break;
        case AFLoggerLevelInfo:
            NSLog(@"%@ '%@'", [operation.request HTTPMethod], [[operation.request URL] absoluteString]);
            break;
        default:
            break;
    }
}

- (void)HTTPOperationDidFinish:(NSNotification *)notification {
    AFHTTPRequestOperation *operation = (AFHTTPRequestOperation *)[notification object];
    
    if (![operation isKindOfClass:[AFHTTPRequestOperation class]]) {
        return;
    }
    
    if (self.filterPredicate && [self.filterPredicate evaluateWithObject:operation]) {
        return;
    }
    
    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:objc_getAssociatedObject(operation, AFHTTPRequestOperationStartDate)];
    
    if (operation.error) {
        switch (self.level) {
            case AFLoggerLevelDebug:
            case AFLoggerLevelInfo:
            case AFLoggerLevelWarn:
            case AFLoggerLevelError:
                NSLog(@"[Error] %@ '%@' (%ld) [%.04f s]: %@", [operation.request HTTPMethod], [[operation.response URL] absoluteString], (long)[operation.response statusCode], elapsedTime, operation.error);
            default:
                break;
        }
    } else {
        switch (self.level) {
            case AFLoggerLevelDebug: {
                NSLog(@"%ld '%@' [%.04f s]: %@ %@", (long)[operation.response statusCode], [[operation.response URL] absoluteString], elapsedTime, [operation.response allHeaderFields], operation.responseString);
                
                NSURL *url = [operation.response URL];

                NSString *folderName = [self getFolderNameForURL:url];
                
                NSString *folderComponent = [NSString stringWithFormat:@"Documents/%@", folderName];

                NSString *folder =  [NSHomeDirectory() stringByAppendingPathComponent:folderComponent];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];

                // NSTimeInterval is defined as double
                NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];

                NSString *timeStampString = [[NSNumber numberWithDouble:timeStamp] stringValue];
                NSString *responseJsonFileName = [NSString stringWithFormat:@"response_%@.json", timeStampString];
                NSString *requestJsonFileName = [NSString stringWithFormat:@"request_%@.json", timeStampString];


                NSString *responseJSONPath = [folder stringByAppendingPathComponent:responseJsonFileName];

                if (operation.responseString) {
                    NSString *responseString = operation.responseString;
                    NSString *prettyResponseString = [self convertToPrettyJSON:responseString];

                    [prettyResponseString writeToFile:responseJSONPath
                                           atomically:YES
                                             encoding:NSUTF8StringEncoding
                                                error:NULL];
                }

                
                if (operation.request.HTTPBody) {
                    
                    NSString *requestJSONPath = [folder stringByAppendingPathComponent:requestJsonFileName];
                    
                    NSData *requestBodyData = operation.request.HTTPBody;
                    
                    NSData *requestPrettyData = [self getPrettyDataFromRequestData:requestBodyData];
                    
                    [requestPrettyData writeToFile:requestJSONPath
                                        atomically:YES];
                }
                

                break;
            }
            case AFLoggerLevelInfo:
                NSLog(@"%ld '%@' [%.04f s]", (long)[operation.response statusCode], [[operation.response URL] absoluteString], elapsedTime);
                break;
            default:
                break;
        }
    }
}

- (NSData *)getPrettyDataFromRequestData:(NSData *)requestBodyData {
//data --> NSDictionary --> pretty json
    NSDictionary *requestDictionary = [NSJSONSerialization JSONObjectWithData:requestBodyData options:0 error:nil];
    NSData *requestPrettyData = [NSJSONSerialization dataWithJSONObject:requestDictionary options:NSJSONWritingPrettyPrinted error:nil];
    return requestPrettyData;
}

- (NSString *)convertToPrettyJSON:(NSString *)responseString {
    NSDictionary *prettyResponseDictionary = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

    NSData *jsonData =
                        [NSJSONSerialization dataWithJSONObject:prettyResponseDictionary
                                                        options:NSJSONWritingPrettyPrinted
                                                          error:nil];
    NSString *prettyResponseString =
                        [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return prettyResponseString;
}

- (NSString *)getFolderNameForURL:(NSURL *)url {
    NSString *host = [url host];
    NSString *path = [url path];

    //compose folder name
    NSString *folderName = [NSString stringWithFormat:@"%@_%@", host, [path stringByReplacingOccurrencesOfString:@"/" withString:@"_"]];
    return folderName;
}

@end
