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
@property (strong, nonatomic) NSTimer *keepaliveTimer;
@property (strong, nonatomic) BOOL autoPingEnabled;
@property (strong, nonatomic) NSMutableDictionary *trackingSessionMapping;
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
    self.trackingSessionMapping = @{}.mutableCopy;
    self.globalParameters = @{}.mutableCopy;
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
    
}

#pragma mark Request Handling

- (void)enqueueRequest:(NSURLRequest*)request {
    
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
    self.requestFactory requestWithPath:@"track" andParams:<#(NSDictionary *)#>
}

#pragma mark Login / Logout

- (void)loginWithType:(NSString*)type withID:(NSString*)identifier {
    [self loginWithType:type withID:identifier withParams:@{}];
}

- (void)loginWithType:(NSString*)type withID:(NSString*)identifier withParams:(NSDictionary*)params {
    
}

- (void)logout {
    [self logoutWithParams:@{}];
}

- (void)logoutWithParams:(NSDictionary*)params {
    
}

#pragma mark Session

- (NSString*)startSession {
    return [self startSessionWithParams:@{}];
}

- (NSString*)startSessionWithParams:(NSDictionary*)params {
    NSString *uuid = [NSUUID UUID].UUIDString;

    return uuid;
}

- (void)stopSessionWithID:(NSString*)sessionID {
    [self stopSessionWithID:sessionID withParams:@{}];
}

- (void)stopSessionWithID:(NSString*)sessionID withParams:(NSDictionary*)params {
    
}

@end
