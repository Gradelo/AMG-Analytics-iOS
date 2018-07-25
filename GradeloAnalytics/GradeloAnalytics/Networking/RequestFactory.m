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

@interface RequestFactory ()
@property (strong, nonatomic) NSDateFormatter *formatter;
@end

@implementation RequestFactory

- (NSDateFormatter *)formatter {
    if(!_formatter) {
        _formatter = [NSDateFormatter new];
        _formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        _formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    }
    return _formatter;
}

/**
This function initializes a new request factore with the given tracker id
 */
- (instancetype)initWithTrackerID:(NSString *)trackerID {
    self = [super init];
    self.trackerID = trackerID;
    return self;
}

#pragma mark Request Generation

- (NSArray<NSURLQueryItem*>*)recursiveItems:(NSDictionary*)dict forKeyPath:(NSString*)keyPath {
    NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if(keyPath) {
            key = [[keyPath stringByAppendingString:@"."] stringByAppendingString:key];
        }
        if ([obj isKindOfClass:[NSDictionary class]]) {
            [queryItems addObjectsFromArray: [self recursiveItems:obj forKeyPath:key]];
        } else if ([obj isKindOfClass:[NSArray class]]) {
            [(NSArray*)obj enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [queryItems addObject: [NSURLQueryItem queryItemWithName:key value:obj]];
            }];
        } else if ([obj isKindOfClass: [NSDate class]]){
            [queryItems addObject: [NSURLQueryItem queryItemWithName:key value:[NSString stringWithFormat:@"%f", [(NSDate*)obj timeIntervalSince1970] * 1000.0]]];
        } else if([obj isKindOfClass: [NSNumber class]]) {
            [queryItems addObject: [NSURLQueryItem queryItemWithName:key value:[NSString stringWithFormat: @"%@", obj]]];
        } else {
            [queryItems addObject: [NSURLQueryItem queryItemWithName:key value:obj]];
        }
    }];
    return queryItems;
}

/**
 This function configures an URL request with the specified parameters
 */
- (NSURLRequest*)requestWithPath:(NSString*)path andParams:(NSDictionary*)params andAdditionalParams:(NSDictionary*)additionalParams {
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.host = APIHost;
    components.path = [@"/" stringByAppendingString: path];
    components.scheme = @"https";
    NSMutableArray *queryItems = [NSMutableArray array];
    NSMutableDictionary *mutableParams = [self defaultParameters:additionalParams].mutableCopy;
    [mutableParams addEntriesFromDictionary:params];
    [queryItems addObjectsFromArray: [self recursiveItems:mutableParams forKeyPath:nil]];
    [queryItems addObject: [NSURLQueryItem queryItemWithName:@"cid" value:[self clientID]]];
    [queryItems addObject: [NSURLQueryItem queryItemWithName:@"tid" value:self.trackerID]];
    [queryItems addObject: [NSURLQueryItem queryItemWithName:@"bndl" value:[[NSBundle mainBundle] bundleIdentifier]]];

    components.queryItems = queryItems;
    NSLog(@"%@", components.URL.absoluteString);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: components.URL];
    request.HTTPShouldHandleCookies = YES;
    request.timeoutInterval = 10;
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
        @"aid": @"app",
        @"tim": [NSDate date]
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
