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
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <sys/utsname.h>

@interface GradeloAnalytics ()

@property (strong, nonatomic) NSURLSession *urlSession;
@property (strong, nonatomic) NSOperationQueue *requestQueue;
@property (strong, nonatomic) NSMutableArray *sessions;
@property (strong, nonatomic) NSMutableDictionary *sessionTypes;
@property (strong, nonatomic) NSTimer *keepaliveTimer;
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
    self.globalParameters = @{}.mutableCopy;
    self.sessionTypes = @{}.mutableCopy;
    self.sessions = @[].mutableCopy;
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPShouldSetCookies = YES;
    self.urlSession = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppMovedToForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppMovedToBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if(self.keepaliveTimer) {
        [self.keepaliveTimer invalidate];
    }
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
    [[self.urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
                NSLog(@"[GradeloAnalytics]: Invalid status code: %ld, %@", (long)httpResponse.statusCode, httpResponse.description);
                return;
            }
        }
    }] resume];
}

#pragma mark Configuration

- (void)initialize:(NSString*)appID autoStartSession:(BOOL)startSession {
    self.requestFactory = [[RequestFactory alloc] initWithTrackerID:appID];
    self.keepaliveTimer = [NSTimer scheduledTimerWithTimeInterval:20.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if(self.sessions.count == 0) {
            return;
        }
        NSMutableArray *sessionData = [NSMutableArray array];
        [self.sessions enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [sessionData addObject: [[self.sessionTypes[obj] ?: @"session" stringByAppendingString:@"."] stringByAppendingString:obj]];
        }];
        NSString *encodedString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:sessionData options:0 error:nil] encoding:NSUTF8StringEncoding];
        NSURLRequest *request = [self.requestFactory requestWithPath:@"ping" andParams:@{
                                                                                         @"nmn": @"ping",
                                                                                         @"typ": @"session",
                                                                                         @"seis": encodedString
                                                                                         } andAdditionalParams: @{}];
        [self enqueueRequest:request];
    }];
    if(startSession) {
        [self startSession];
    }
    BOOL debug = NO;
#if DEBUG
    debug = YES;
#endif
    UIDevice *device = [UIDevice currentDevice];
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] ?: @"0.1";
    NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey] ?: @"0";
    NSString *carrier =  [[[[CTTelephonyNetworkInfo alloc] init] subscriberCellularProvider] carrierName];
    struct utsname systemInfo;
    uname(&systemInfo);
    
    NSString *type = [NSString stringWithCString:systemInfo.machine
                                        encoding:NSUTF8StringEncoding];
    NSMutableDictionary *dict = @{
                                  @"language": [[NSLocale currentLocale] languageCode] ?: @"en",
                                  @"app_version": [NSString stringWithFormat: @"%@ (%@)", version, build],
                                  @"debug":[NSNumber numberWithBool:debug],
                                  @"os_name": device.systemName,
                                  @"os_version": device.systemVersion,
                                  @"model": device.model,
                                  @"type": type,
                                  @"carrier":carrier ?: @"",
                                  @"vendor": @"Apple"
                                  }.mutableCopy;
    
    NSURLRequest *request = [self.requestFactory requestWithPath:@"me" andParams:@{
                                                                                     @"nmn": @"me",
                                                                                     @"typ": @"get",
                                                                                     @"device": dict
                                                                                     } andAdditionalParams: @{}];
    [self enqueueRequest:request];
}

- (void)setAdditionalParams:(NSDictionary*)params {
    [self.globalParameters addEntriesFromDictionary:params];
}

#pragma mark Events

- (void)triggerEvent:(NSString*)eventID {
    [self triggerEvent:eventID withParams:@{}];
}

- (void)triggerEvent:(NSString*)eventID withParams:(NSDictionary*)params {
    NSURLRequest *request = [self.requestFactory requestWithPath:@"req" andParams:@{
                                                                                      @"nmn": eventID,
                                                                                      @"typ": @"event"
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
                                                                                      @"emi": params[@"email"] ?: [NSNull null],
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
                                                                                       @"typ": @"logout"
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
                                                                   @"nmn": @"session",
                                                                   @"typ": @"session",
                                                                   @"sei": uuid
                                                                   }
                                             andAdditionalParams:params];
    [self.sessions addObject:uuid];
    [self enqueueRequest:request];
    self.sessionTypes[uuid] = @"session";
    return uuid;
}


- (NSString*)startPageviewWithTitle:(NSString *)title andLocation:(NSString *)location  {
    return [self startPageviewWithTitle:title andLocation:location andParams:@{}];
}

- (NSString*)startPageviewWithTitle:(NSString *)title andLocation:(NSString *)location andParams:(NSDictionary *)params {
    NSString *uuid = [@[[NSUUID UUID].UUIDString, [NSUUID UUID].UUIDString] componentsJoinedByString:@"-"];
    NSURLRequest *request = [self.requestFactory requestWithPath:@"start"
                                                       andParams:@{
                                                                   @"nmn": @"pageview",
                                                                   @"typ": @"session",
                                                                   @"pei": [uuid substringToIndex:8],
                                                                   @"sei": uuid,
                                                                   @"location": location ?: [NSNull null],
                                                                   @"title": title ?: [NSNull null]
                                                                   }
                                             andAdditionalParams:params];
    [self.sessions addObject:uuid];
    self.sessionTypes[uuid] = @"pageview";
    [self enqueueRequest:request];
    return uuid;
}

- (void)stopSessionWithID:(NSString*)sessionID {
    [self stopSessionWithID:sessionID withParams:@{}];
}

- (void)stopSessionWithID:(NSString*)sessionID withParams:(NSDictionary*)params {
    NSURLRequest *request = [self.requestFactory requestWithPath:@"stop"
                                                       andParams:@{
                                                                   @"nmn": @"session",
                                                                   @"typ": @"session",
                                                                   @"sei": sessionID
                                                                   }
                                             andAdditionalParams:params];
    [self.sessions removeObject:sessionID];
    [self.sessionTypes removeObjectForKey:sessionID];
    [self enqueueRequest:request];
}

@end
