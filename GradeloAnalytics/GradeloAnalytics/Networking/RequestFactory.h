//
//  RequestFactory.h
//  GradeloAnalytics
//
//  Created by Christian Praiß on 18.07.18.
//  Copyright © 2018 Mettatech LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RequestFactory : NSObject

@property (strong, nonatomic) NSString *trackerID;

- (instancetype)initWithTrackerID:(NSString*)trackerID;
- (instancetype)init NS_UNAVAILABLE;

/**
 Returns the clientID for this device
 */
- (NSString*)clientID;

/**
 Returns a fully populated URL request for the given path and parameters
 */
- (NSURLRequest*)requestWithPath:(NSString*)path andParams:(NSDictionary*)params;

@end
