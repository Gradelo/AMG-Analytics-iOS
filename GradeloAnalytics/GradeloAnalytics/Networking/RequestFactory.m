//
//  RequestFactory.m
//  GradeloAnalytics
//
//  Created by Christian Praiß on 18.07.18.
//  Copyright © 2018 Mettatech LLC. All rights reserved.
//

#import "RequestFactory.h"
#import <UIKit/UIKit.h>

NSString * const APIHost = @"api.metta.tech";
NSString * const CachedUUIDString = @"com.gradelo.gradeloanalytics.fallbackClientID";

@implementation RequestFactory

/**
This function initializes a new request factore with the given tracker id
 */
- (instancetype)initWithTrackerID:(NSString *)trackerID {
    self = [super init];
    self.trackerID = trackerID;
    return self;
}

#pragma mark Request Generation

/**
 This function configures an URL request with the specified parameters
 */
- (NSURLRequest*)requestWithPath:(NSString*)path andParams:(NSDictionary*)params andAdditionalParams:(NSDictionary*)additionalParams {
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.host = APIHost;
    components.path = path;
    components.scheme = @"https";
    NSMutableArray *queryItems = [NSMutableArray array];
    NSMutableDictionary *mutableParams = [self defaultParameters:additionalParams].mutableCopy;
    [mutableParams addEntriesFromDictionary:params];
    [mutableParams enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if([obj isKindOfClass:[NSDictionary class]] || [obj isKindOfClass:[NSArray class]]) {
            @try {
                [queryItems addObject: [NSURLQueryItem queryItemWithName:key value:[[NSJSONSerialization dataWithJSONObject:obj options:0 error:nil] base64EncodedStringWithOptions:0]]];
            } @catch (NSException *exception) {
                
            }
        } else {
            [queryItems addObject: [NSURLQueryItem queryItemWithName:key value:obj]];
        }
    }];
    [queryItems addObject: [NSURLQueryItem queryItemWithName:@"cid" value:[self clientID]]];
    [queryItems addObject: [NSURLQueryItem queryItemWithName:@"tid" value:self.trackerID]];

    components.queryItems = queryItems;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: components.URL];
    request.HTTPShouldHandleCookies = YES;
    request.timeoutInterval = 30;
    return request;
}

/**
This function generates the default request parameters merged with the additional parameters
 */
- (NSDictionary*)defaultParameters:(NSDictionary*)additionalParams {
    return @{
        @"scr": @{
            @"w": @([UIScreen mainScreen].nativeBounds.size.width),
            @"h": @([UIScreen mainScreen].nativeBounds.size.height),
            @"aw": @([UIScreen mainScreen].bounds.size.width),
            @"ah": @([UIScreen mainScreen].bounds.size.height)
        },
        @"par": additionalParams,
        @"aid": @"app"
    };
}

#pragma mark Client ID Generation

/**
 This function returns the clientID that is either the fallback or the correct id for vendor
 */
- (NSString*)clientID {
    if([UIDevice currentDevice].identifierForVendor.UUIDString && ![[NSUserDefaults standardUserDefaults] stringForKey:CachedUUIDString]) {
        return [UIDevice currentDevice].identifierForVendor.UUIDString;
    }
    return [self fallbackClientID];
}

/**
 This function generates and caches a fallback clientID to use when the vendor identifier is not available
 */
- (NSString*)fallbackClientID {
    NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:CachedUUIDString];
    if(uuid) {
        return uuid;
    }
    uuid = [NSUUID UUID].UUIDString;
    [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:CachedUUIDString];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return uuid;
}

@end
