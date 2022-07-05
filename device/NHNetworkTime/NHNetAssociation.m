#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <sys/time.h>
#import "NHNetAssociation.h"
#import "NSDate+NetworkClock.h"

/* ┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
   │  NTP Timestamp Structure                                                                         │
   │                                                                                                  │
   │   0                   1                   2                   3                                  │
   │   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                                │
   │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
   │  |                           Seconds                             |                               │
   │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
   │  |                  Seconds Fraction (0-padded)                  | <-- 4294967296 = 1 second     │
   │  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               │
   └──────────────────────────────────────────────────────────────────────────────────────────────────┘ */


#pragma mark - Time converter

#define JAN_1970            0x83aa7e80                      // UNIX epoch in NTP's epoch:
                                                            // 1970-1900 (2,208,988,800s)
typedef struct ntpTimestamp {
    uint32_t wholeSeconds;
    uint32_t fractSeconds;
} NHTimeStamp;

static NHTimeStamp NTP_1970 = {JAN_1970, 0};        // network time for 1 January 1970, GMT

static double pollIntervals[18] = {
    2.0,   16.0,   16.0,   16.0,   16.0,    35.0,    72.0,  127.0,     258.0,
    511.0, 1024.0, 2048.0, 4096.0, 8192.0, 16384.0, 32768.0, 65536.0, 131072.0
};

/// Convert from Unix time to NTP time
NS_INLINE void unix2ntp(const struct timeval *tv, NHTimeStamp *ntp) {
    ntp->wholeSeconds = (uint32_t)(tv->tv_sec + JAN_1970);
    ntp->fractSeconds = (uint32_t)(((double)tv->tv_usec + 0.5) * (double)(1LL << 32) * 1.0e-6);
}

/// Convert from NTP time to Unix time
__attribute__((unused))
NS_INLINE void ntp2unix(const NHTimeStamp *ntp, struct timeval *tv) {
    tv->tv_sec  = ntp->wholeSeconds - JAN_1970;
    tv->tv_usec = (uint32_t)((double)ntp->fractSeconds / (1LL << 32) * 1.0e6);
}

/// Get current time in NTP format
NS_INLINE void ntp_time_now(NHTimeStamp *ntp) {
    struct timeval now;
    gettimeofday(&now, (struct timezone *)NULL);
    unix2ntp(&now, ntp);
}

/// Get (ntpTime2 - ntpTime1) in (double) seconds
NS_INLINE double ntpDiffSeconds(NHTimeStamp *start, NHTimeStamp *stop) {
    int32_t a;
    uint32_t b;
    a = stop->wholeSeconds - start->wholeSeconds;
    if (stop->fractSeconds >= start->fractSeconds) {
        b = stop->fractSeconds - start->fractSeconds;
    }
    else {
        b = start->fractSeconds - stop->fractSeconds;
        b = ~b;
        a -= 1;
    }
    
    return a + b / 4294967296.0;
}


@interface NHNetAssociation () {
    double fifoQueue[8];
    
    NHTimeStamp ntpClientSendTime;
    NHTimeStamp ntpServerRecvTime;
    NHTimeStamp ntpServerSendTime;
    NHTimeStamp ntpClientRecvTime;
    NHTimeStamp ntpServerBaseTime;
}

@property (nonatomic, strong) GCDAsyncUdpSocket *socket;
@property (nonatomic, strong) NSTimer *repeatingTimer;     // fires off an ntp request ...
@property (nonatomic, assign) int pollingIntervalIndex;    // index into polling interval table

@property (nonatomic, assign) int stratum;
@property (nonatomic, assign) double timerWobbleFactor;    // 0.75 .. 1.25
@property (nonatomic, assign) short fifoIndex;

@property (nonatomic, assign, readonly) double dispersion; // milliSeconds
@property (nonatomic, assign, readonly) double roundtrip;  // seconds

@property (nonatomic, strong) NSMutableArray *observers;

@end

@implementation NHNetAssociation {
    dispatch_queue_t _timerQueue;
}

/// Initialize the association with a blank socket and prepare the time transaction to happen every 16 seconds (initial value)
- (instancetype)initWithServerName:(NSString *)serverName {
    if (self = [super init]) {
        self.pollingIntervalIndex = 0;                      // ensure the first timer firing is soon
        _active = NO;                                       // isn't running till it reports time ...
        _trusty = NO;                                       // don't trust this clock to start with ...
        _offset = INFINITY;                                 // start with net clock meaningless
        _server = serverName;
        
        _timerQueue = dispatch_queue_create([serverName cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_CONCURRENT);
        self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
                                                    delegateQueue:_timerQueue];
    }
    
    return self;
}

- (void)enable {
    
    // Create a first-in/first-out queue for time samples.  As we compute each new time obtained from the server we push it into the fifo.  We sample the contents of the fifo for quality and, if it meets our standards we use the contents of the fifo to obtain a weighted average of the times.
    for (short i = 0; i < 8; i++) fifoQueue[i] = NAN;   // set fifo to all empty
    self.fifoIndex = 0;
    
    // Finally, initialize the repeating timer that queries the server, set it's trigger time to the infinite future, and put it on the run loop .. nothing will happen (yet)
    self.repeatingTimer = [NSTimer timerWithTimeInterval:MAXFLOAT
                                                  target:self
                                                selector:@selector(queryTimeServer)
                                                userInfo:nil
                                                 repeats:YES];
    
    self.repeatingTimer.tolerance = 1.0;  // it can be up to 1 second late
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_timerQueue, ^{
        [[NSRunLoop currentRunLoop] addTimer:weakSelf.repeatingTimer forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    });
    
    // now start the timer .. fire the first one soon, and put some wobble in its timing so we don't get pulses of activity.
    self.timerWobbleFactor = ((float)rand() / (float)RAND_MAX / 2.0) + 0.75;       // 0.75 .. 1.25
    NSTimeInterval interval = pollIntervals[self.pollingIntervalIndex] * self.timerWobbleFactor;
    [self.repeatingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:interval]];
    
    self.pollingIntervalIndex = 4;       // subsequent timers fire at default intervals
}

/// Set the receiver and send the time query with 2 second timeout, ...
- (void)queryTimeServer {
    [self sendTimeQuery];
    
    // Put some wobble into the repeating time so they don't synchronize and thump the network
    self.timerWobbleFactor = ((float)rand() / (float)RAND_MAX / 2.0) + 0.75;       // 0.75 .. 1.25
    NSTimeInterval interval = pollIntervals[self.pollingIntervalIndex] * self.timerWobbleFactor;
    [self.repeatingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:interval]];
}

- (void)sendTimeQuery {
    NSError *error = nil;
    
    [self.socket sendData:[self createPacket] toHost:_server port:123 withTimeout:2.0 tag:0];
    
    if (![self.socket beginReceiving:&error]) {
        CHDebugLogSource(@"Unable to start listening on socket for [%@] due to error [%@]", _server, error);
        return;
    }
}

- (void)finish {
    [self.repeatingTimer invalidate];
    
    for (short i = 0; i < 8; i++) fifoQueue[i] = NAN;      // set fifo to all empty
    self.fifoIndex = 0;
    
    _active = NO;
    
    if (self.socket) {
        [self.socket close];
    }
}


#pragma mark - Network transactions

/* ┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
   │      Create a time query packet ...                                                              │
   │──────────────────────────────────────────────────────────────────────────────────────────────────│
   │                                                                                                  │
   │                               1                   2                   3                          │
   │           0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1                        │
   │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
   │     [ 0] | L | Ver |Mode |    Stratum    |     Poll      |   Precision   |                       │
   │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
   │     [ 1] |                        Root  Delay (32)                       | in NTP short format   │
   │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
   │     [ 2] |                     Root  Dispersion (32)                     | in NTP short format   │
   │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
   │     [ 3] |                     Reference Identifier                      |                       │
   │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
   │     [ 4] |                                                               |                       │
   │          |                    Reference Timestamp (64)                   | in NTP long format    │
   │     [ 5] |                                                               |                       │
   │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
   │     [ 6] |                                                               |                       │
   │          |                    Originate Timestamp (64)                   | in NTP long format    │
   │     [ 7] |                                                               |                       │
   │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
   │     [ 8] |                                                               |                       │
   │          |                     Receive Timestamp (64)                    | in NTP long format    │
   │     [ 9] |                                                               |                       │
   │          +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                       │
   │     [10] |                                                               |                       │
   │          |                     Transmit Timestamp (64)                   | in NTP long format    │
   │     [11] |                                                               |                       │
   │                                                                                                  │
   └──────────────────────────────────────────────────────────────────────────────────────────────────┘ */

- (NSData *)createPacket {
    uint32_t wireData[12];
    
    memset(wireData, 0, sizeof wireData);
    wireData[0] = htonl((0 << 30) |                                         // no Leap Indicator
                        (4 << 27) |                                         // NTP v4
                        (3 << 24) |                                         // mode = client sending
                        (0 << 16) |                                         // stratum (n/a)
                        (4 << 8)  |                                         // polling rate (16 secs)
                        (-6 & 0xff));                                       // precision (~15 mSecs)
    wireData[1] = htonl(1 << 16);
    wireData[2] = htonl(1 << 16);
    
    ntp_time_now(&ntpClientSendTime);
    
    wireData[10] = htonl(ntpClientSendTime.wholeSeconds);                   // Transmit Timestamp
    wireData[11] = htonl(ntpClientSendTime.fractSeconds);
    
    return [NSData dataWithBytes:wireData length:48];
}

- (void)decodePacket:(NSData *)data {
    NHNetworkClock *sharedClock = [NHNetworkClock sharedNetworkClock];
    
    dispatch_sync(sharedClock.accessQueue, ^{
        
        // Grab the packet arrival time as fast as possible, before computations below ...
        ntp_time_now(&ntpClientRecvTime);
        
        uint32_t wireData[12];
        [data getBytes:wireData length:48];
        
        int mode = ntohl(wireData[0]) >> 24 & 0x07;
        self.stratum = ntohl(wireData[0]) >> 16 & 0xff;
        
        _dispersion = ntohl(wireData[2]) * 0.0152587890625;                 // error (mS)
        
        ntpServerBaseTime.wholeSeconds = ntohl(wireData[4]);                // when server clock was wound
        ntpServerBaseTime.fractSeconds = ntohl(wireData[5]);
        
        // If the send time in the packet isn't the same as the remembered send time, ditch it ...
        if (ntpClientSendTime.wholeSeconds != ntohl(wireData[6]) ||
            ntpClientSendTime.fractSeconds != ntohl(wireData[7])) return;   //  NO;
        
        ntpServerRecvTime.wholeSeconds = ntohl(wireData[8]);
        ntpServerRecvTime.fractSeconds = ntohl(wireData[9]);
        ntpServerSendTime.wholeSeconds = ntohl(wireData[10]);
        ntpServerSendTime.fractSeconds = ntohl(wireData[11]);
        
        // Determine the quality of this particular time if max_error is less than 50ms (and not zero) AND stratum > 0 AND the mode is 4 (packet came from server) AND the server clock was set less than 1 minute ago
        _offset = INFINITY;                                                 // clock meaningless
        if ((_dispersion < 50.0 && _dispersion > 0.00001) &&
            (self.stratum > 0) && (mode == 4) &&
            (ntpDiffSeconds(&ntpServerBaseTime, &ntpServerSendTime) < 60.0)) {
            
            double t41 = ntpDiffSeconds(&ntpClientSendTime, &ntpClientRecvTime);    // .. (T4-T1)
            double t32 = ntpDiffSeconds(&ntpServerRecvTime, &ntpServerSendTime);    // .. (T3-T2)
            
            _roundtrip  = t41 - t32;
            
            double t21 = ntpDiffSeconds(&ntpServerSendTime, &ntpClientRecvTime);    // .. (T2-T1)
            double t34 = ntpDiffSeconds(&ntpServerRecvTime, &ntpClientSendTime);    // .. (T3-T4)
            
            _offset = (t21 + t34) / 2.0;                                            // calculate offset
            
            _active = YES;
        }
        
        [self calculateTrusty];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(netAssociationDidFinishGetTime:)]) {
            [self.delegate netAssociationDidFinishGetTime:self];
        }
    });
}

- (void)calculateTrusty {
    // The packet is trustworthy -- compute and store offset in 8-slot fifo ...
    
    fifoQueue[self.fifoIndex++ % 8] = _offset;                           // store offset in seconds
    self.fifoIndex %= 8;                                                 // rotate index in range
    
    // look at the (up to eight) offsets in the fifo and and count 'good', 'fail' and 'not used yet'
    short good = 0, fail = 0, none = 0;
    _offset = 0.0;                                                  // reset for averaging
    
    for (short i = 0; i < 8; i++) {
        if (isnan(fifoQueue[i])) {                                  // fifo slot is unused
            none++;
            continue;
        }
        if (isinf(fifoQueue[i]) || fabs(fifoQueue[i]) < 0.0001) {   // server can't be trusted
            fail++;
            continue;
        }
        
        good++;
        _offset += fifoQueue[i];                                    // accumulate good times
    }
    
    // If we have at least one 'good' server response or four or more 'fail' responses, we'll inform our management accordingly.  If we have less than four 'fails' we won't make any note of that ... we won't condemn a server until we get four 'fail' packets.
    double stdDev = 0.0;
    if (good > 0 || fail > 3) {
        _offset = _offset / good;                                   // average good times
        
        for (short i = 0; i < 8; i++) {
            if (isnan(fifoQueue[i])) continue;
            
            if (isinf(fifoQueue[i]) || fabs(fifoQueue[i]) < 0.001) continue;
            
            stdDev += (fifoQueue[i] - _offset) * (fifoQueue[i] - _offset);
        }
        stdDev = sqrt(stdDev / (float)good);
        
        _trusty = (good + none > 4) &&                                // four or more 'fails'
                  (fabs(_offset) > stdDev * 3.0);                     // s.d. < offset
        
        CHDebugLogSource(@"  [%@] {%3.1f,%3.1f,%3.1f,%3.1f,%3.1f,%3.1f,%3.1f,%3.1f} ↑=%i, ↓=%i, %3.1f(%3.1f) %@", _server,
                         fifoQueue[0] * 1000.0, fifoQueue[1] * 1000.0, fifoQueue[2] * 1000.0, fifoQueue[3] * 1000.0,
                         fifoQueue[4] * 1000.0, fifoQueue[5] * 1000.0, fifoQueue[6] * 1000.0, fifoQueue[7] * 1000.0,
                         good, fail, _offset * 1000.0, stdDev * 1000.0, _trusty ? @"↑" : @"↓");
        
    }
    
    // If the association is providing times which don't vary much, we could increase its polling interval.  In practice, once things settle down, the standard deviation on any time server seems to fall in the 70-120ms range (plenty close for our work).  We usually pick up a few stratum=1 servers, it would be a Good Thing to not hammer those so hard ...
    if ((self.stratum == 1 && self.pollingIntervalIndex != 6) ||
        (self.stratum == 2 && self.pollingIntervalIndex != 5)) {
        self.pollingIntervalIndex = 7 - self.stratum;
    }
}


#pragma mark - Network callbacks

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    CHDebugLogSource(@"didConnectToAddress: %@", address);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    CHDebugLogSource(@"didNotConnect - %@", error.description);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    // CHDebugLogSource(@"didSendDataWithTag %ld", tag);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    CHDebugLogSource(@"didNotSendDataWithTag - %@", error.description);
}

- (void)    udpSocket:(GCDAsyncUdpSocket *)sock
       didReceiveData:(NSData *)data
          fromAddress:(NSData *)address
    withFilterContext:(id)filterContext
{
    [self decodePacket:data];
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    CHDebugLogSource(@"Socket closed: [%@]", _server);
}

/// Make an NSDate from ntpTimestamp ... (via seconds from JAN_1970) ...
- (NSDate *)dateFromNetworkTime:(struct ntpTimestamp *) networkTime {
    return [NSDate dateWithTimeIntervalSince1970:ntpDiffSeconds(&NTP_1970, networkTime)];
}


#pragma mark - Pretty printer

- (NSString *)prettyPrintTimers {
    NSMutableString *prettyString = [NSMutableString stringWithFormat:@"prettyPrintTimers\n\n"];
    
    [prettyString appendFormat:@"time server addr: [%@]\n"
     " round trip time: %7.3f (mS)\n"
     "    clock offset: %7.3f (mS)\n\n",
     _server, _roundtrip * 1000.0, _offset * 1000.0];
    
    return prettyString;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [%@] stratum=%i; offset=%3.1f±%3.1fmS",
            _trusty ? @"↑" : @"↓", _server, self.stratum, _offset, _dispersion];
}

@end
