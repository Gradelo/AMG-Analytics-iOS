//
//  Framework.m
//  GradeloAnalytics
//
//  Created by Christian Praiß on 18.07.18.
//  Copyright © 2018 Mettatech LLC. All rights reserved.
//

#import "Framework.h"
#import <UIKit/UIKit.h>
#import "RequestFactory.h"

@interface GradeloAnalytics ()

@property (strong, nonatomic) NSURLSession *urlSession;
@property (strong, nonatomic) NSOperationQueue *requestQueue;
@property (strong, nonatomic) NSMutableArray *sessions;
@property (strong, nonatomic) NSTimer *keepaliveTimer;
@property (nonatomic) BOOL autoPingEnabled;
@property (strong, nonatomic) NSMutableDictionary *globalParameters;
@property (strong, nonatomic) RequestFactory *requestFactory;

@end

@implementation GradeloAnalytics

#pragma mark Instance

+ (instancetype)sharedInstance {
    static GradeloAnalytics *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [GradeloAnalytics new];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    self.requestQueue = [NSOperationQueue new];
    self.requestQueue.maxConcurrentOperationCount = 1;
    self.globalParameters = @{}.mutableCopy;
    self.sessions = @[].mutableCopy;
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPShouldSetCookies = YES;
    self.urlSession = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:self.requestQueue];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppMovedToForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppMovedToBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onAppMovedToForeground {
    
}

- (void)onAppMovedToBackground {
    
}

- (void)onAppWillTerminate {
    self.requestQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
    [self.sessions enumerateObjectsUsingBlock:^(NSString*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self stopSessionWithID:obj];
    }];
}

#pragma mark Request Handling

- (void)enqueueRequest:(NSURLRequest*)request {
    [self.urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(error) {
            NSLog(@"[GradeloAnalytics]: %@, %@", error.localizedDescription, error.localizedFailureReason);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self enqueueRequest:request];
            });
            return;
        }
        if([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if(httpResponse.statusCode < 400 && httpResponse.statusCode >= 200) {
                // Request successful
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self enqueueRequest:request];
                });
                NSLog(@"[GradeloAnalytics]: Invalid status code: %ld, %@", httpResponse.statusCode, httpResponse.description);
                return;
            }
        }
    }];
}

#pragma mark Configuration

- (void)initialize:(NSString*)appID autoPing:(BOOL)autoPing {
    self.requestFactory = [[RequestFactory alloc] initWithTrackerID:appID];
    self.autoPingEnabled = autoPing;
}

- (void)setAdditionalParams:(NSDictionary*)params {
    [self.globalParameters addEntriesFromDictionary:params];
}

#pragma mark Events

- (void)triggerEvent:(NSString*)eventID {
    [self triggerEvent:eventID withParams:@{}];
}

- (void)triggerEvent:(NSString*)eventID withParams:(NSDictionary*)params {
    NSURLRequest *request = [self.requestFactory requestWithPath:@"track" andParams:@{
                                                                                      @"nmn": eventID,
                                                                                      @"typ": @"event",
                                                                                      @"tim": [NSDate new]
                                                                                      } andAdditionalParams: params];
    [self enqueueRequest:request];
}

#pragma mark Login / Logout

- (void)loginWithType:(NSString*)type withID:(NSString*)identifier {
    [self loginWithType:type withID:identifier withParams:@{}];
}

- (void)loginWithType:(NSString*)type withID:(NSString*)identifier withParams:(NSDictionary*)params {
    NSURLRequest *request = [self.requestFactory requestWithPath:@"login" andParams:@{
                                                                                      @"nmn": type,
                                                                                      @"typ": type,
                                                                                      @"tim": [NSDate new],
                                                                                      @"emi": params[@"email"],
                                                                                      @"euid": identifier
                                                                                      } andAdditionalParams: params];
    [self enqueueRequest:request];
}

- (void)logout {
    [self logoutWithParams:@{}];
}

- (void)logoutWithParams:(NSDictionary*)params {
    NSURLRequest *request = [self.requestFactory requestWithPath:@"logout" andParams:@{
                                                                                       @"nmn": @"logout",
                                                                                       @"typ": @"logout",
                                                                                       @"tim": [NSDate new]
                                                                                       } andAdditionalParams: params];
    [self enqueueRequest:request];
}

#pragma mark Session

- (NSString*)startSession {
    return [self startSessionWithParams:@{}];
}

- (NSString*)startSessionWithParams:(NSDictionary*)params {
    NSString *uuid = [@[[NSUUID UUID].UUIDString, [NSUUID UUID].UUIDString] componentsJoinedByString:@"-"];
    NSURLRequest *request = [self.requestFactory requestWithPath:@"start"
                                                       andParams:@{
                                                                   @"sei": uuid,
                                                                   @"tim": [NSDate new]
                                                                   }
                                             andAdditionalParams:params];
    [self.sessions addObject:uuid];
    [self enqueueRequest:request];
    return uuid;
}

- (void)stopSessionWithID:(NSString*)sessionID {
    [self stopSessionWithID:sessionID withParams:@{}];
}

- (void)stopSessionWithID:(NSString*)sessionID withParams:(NSDictionary*)params {
    NSURLRequest *request = [self.requestFactory requestWithPath:@"stop"
                                                       andParams:@{
                                                                   @"sei": sessionID,
                                                                   @"tim": [NSDate new]
                                                                   }
                                             andAdditionalParams:params];
    [self enqueueRequest:request];
}

@end
