//
//  Framework.h
//  GradeloAnalytics
//
//  Created by Christian Praiß on 18.07.18.
//  Copyright © 2018 Mettatech LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GradeloAnalytics : NSObject

- (instancetype)init NS_UNAVAILABLE;

/**
 Returns the shared instance of this framework
 */
+ (instancetype)sharedInstance;

/**
 Initializes the Gradelo Analytics SDK

 @param appID - The siteId of the tracker
 @param startSession - Enables automatic session starting for global app
 */
- (void)initialize:(NSString*)appID autoStartSession:(BOOL)startSession;


/**
 Sets default params that will be sent with every request

 @param params - The params to set
 */
- (void)setAdditionalParams:(NSDictionary*)params;

/**
 Triggers an event
 
 @param eventID - The id of the event
 */
- (void)triggerEvent:(NSString*)eventID;
/**
 Triggers an event

 @param eventID - The id of the event
 @param params  - Params to send with the request
 */
- (void)triggerEvent:(NSString*)eventID withParams:(NSDictionary*)params;

/**
 Login in the user to the current session

 @param type - The type of the login
 @param identifier - The user's id
 */
- (void)loginWithType:(NSString*)type withID:(NSString*)identifier;

/**
 Login in the user to the current session
 
 @param type - The type of the login
 @param identifier - The user's id
 @param params  - Params to send with the request
 */
- (void)loginWithType:(NSString*)type withID:(NSString*)identifier withParams:(NSDictionary*)params;

/**
 Logs out the current from the session
*/
- (void)logout;

/**
 Logs out the current from the session
 
 @param params - Params to send with the request
 */
- (void)logoutWithParams:(NSDictionary*)params;

/**
 Starts a new session
 
 @returns - Returns a temporary session id
 */
- (NSString*)startSession;

/**
 Starts a new session
 
 @param params - Params to send with the request
 @returns - Returns a temporary session id
 */
- (NSString*)startSessionWithParams:(NSDictionary*)params;

- (NSString*)startPageviewWithID:(NSString*)pageViewID;
- (NSString*)startPageviewWithID:(NSString*)pageViewID andParams:(NSDictionary*)params;
/**
 Stops the session with the specified id
 
 @param sessionID - The session to stop
 */
- (void)stopSessionWithID:(NSString*)sessionID;

/**
 Stops the session with the specified id
 
 @param sessionID - The session to stop
 @param params - Params to send with the request
 */
- (void)stopSessionWithID:(NSString*)sessionID withParams:(NSDictionary*)params;

@end
