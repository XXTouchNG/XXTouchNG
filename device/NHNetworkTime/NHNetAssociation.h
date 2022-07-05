/**
   NHNetAssociation.h
   Created by Gavin Eadie on Nov03/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved.
   Modified by Nguyen Cong Huy on 9 Sep 2015

   This NetAssociation manages the communication and time calculations for one server.
   Multiple servers are used in a process in which each client/server pair (association) works to obtain its own best version of the time.  The client sends small UDP packets to the server and the server overwrites certain fields in the packet and returns it immediately.  As each packet is received, the offset between the client's network time and the system clock is derived with associated statistics delta, epsilon, and psi.
   Each association makes a best effort at obtaining an accurate time and makes it available as a property.  Another process may use this to select, cluster, and combine the various servers' data to determine the most accurate and reliable candidates to provide an overall best time.
 */

#import <UIKit/UIKit.h>
#import <sys/time.h>


#import "GCDAsyncUdpSocket.h"

@protocol NHNetAssociationDelegate;

@interface NHNetAssociation : NSObject <GCDAsyncUdpSocketDelegate>
    
@property (nonatomic, copy, readonly) NSString *server;    // server name "123.45.67.89"
@property (nonatomic, assign, readonly) BOOL active;       // is this clock running yet?
@property (nonatomic, assign, readonly) BOOL trusty;       // is this clock trustworthy
@property (nonatomic, assign, readonly) double offset;     // offset from device time (secs)
@property (nonatomic, weak) id <NHNetAssociationDelegate> delegate;

- (instancetype)initWithServerName:(NSString *)serverName;

/// This sets the association in a mode where it repeatedly gets time from its server and performs statical check and averages on these multiple values to provide a more accurate time. Starts the timer firing (sets the fire time randonly within the next five seconds) ...
- (void)enable;

/// This stops the timer firing (sets the fire time to the infinite future) ...
- (void)finish;

/// Send one datagram to server ...
- (void)sendTimeQuery;

@end

@protocol NHNetAssociationDelegate <NSObject>
- (void)netAssociationDidFinishGetTime:(NHNetAssociation *)netAssociation;
@end
