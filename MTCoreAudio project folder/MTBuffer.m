//
//  MTBuffer.m
//  MTCoreAudio.framework
//
//  Created by Michael Thornburgh on Mon Mar 22 2004.
//  Copyright (c) 2004 Michael Thornburgh. All rights reserved.
//

#import "MTBuffer.h"

#include <pthread.h>

// ug!  NSCondition exists but appears buggy in 10.4

@interface _MTCondition : NSObject <NSLocking>
{
	pthread_mutex_t  mutex;
	pthread_cond_t   condition;
}

- (void) wait;
- (void) signal; // wakes one waiting thread
- (void) broadcast; // wake all waiting threads
@end

@implementation _MTCondition

- init
{
	[super init];
	
	pthread_mutex_init(&mutex, NULL);
	pthread_cond_init(&condition, NULL);
	
	return self;
}

- (void) lock
{
	if(pthread_mutex_lock(&mutex))
		[NSException raise:@"LockFailed" format:@"_MTCondition %@ lock failed", self];
}

- (void) unlock
{
	if(pthread_mutex_unlock(&mutex))
		[NSException raise:@"UnlockFailed" format:@"_MTCondition %@ unlock failed", self];
}

- (void) wait
{
	if(pthread_cond_wait(&condition, &mutex))
		[NSException raise:@"CondWaitFailed" format:@"_MTCondition %@ wait failed", self];
}

- (void) signal
{
	if(pthread_cond_signal(&condition))
		[NSException raise:@"CondSignalFailed" format:@"_MTCondition %@ signal failed", self];
}

- (void) broadcast
{
	if(pthread_cond_broadcast(&condition))
		[NSException raise:@"CondBroadcastFailed" format:@"_MTCondition %@ broadcast failed", self];
}

- (void) dealloc
{
	pthread_mutex_destroy(&mutex);
	pthread_cond_destroy(&condition);
	
	[super dealloc];
}

@end


@implementation MTBuffer

- init
{
	[self dealloc];
	return nil;
}

- initWithCapacity:(unsigned)capacity
{
	[super init];
	stillOpen = YES;
	isThreadSafe = YES;
	bufferSize = capacity;
	bufferHead = 0;
	framesInBuffer = 0;
	condition = [_MTCondition new];
	if (nil == condition)
	{
		[self release];
		return nil;
	}
	return self;
}

- (void) performWriteFromContext:(void *)theContext offset:(unsigned)theOffset count:(unsigned)count
{ }

- (void) performReadToContext:   (void *)theContext offset:(unsigned)theOffset count:(unsigned)count
{ }

- (void) bufferDidEmpty
{ }


- (unsigned) writeFromContext:(void *)theContext count:(unsigned)count waitForRoom:(Boolean)wait
{
	unsigned rv = 0;
	unsigned idx;
	unsigned framesToCopy;
	Boolean keepTrying;
	
	[condition lock];
	
	keepTrying = stillOpen && ( count > 0 );
	wait = wait && stillOpen && isThreadSafe;
	
	while (keepTrying)
	{
		while (wait && stillOpen && (framesInBuffer == bufferSize))
			[condition wait];
		
		if (!stillOpen)
			break;
		
		idx = bufferHead + framesInBuffer;
		while (( framesInBuffer < bufferSize) && count )
		{
			if (idx >= bufferSize) idx -= bufferSize;
			framesToCopy = MIN (( bufferSize - framesInBuffer ), count );
			framesToCopy = MIN ( framesToCopy, ( bufferSize - idx ));
			[self performWriteFromContext:theContext offset:idx count:framesToCopy];
			idx += framesToCopy;
			rv += framesToCopy;
			count -= framesToCopy;
			framesInBuffer += framesToCopy;
		}
		
		[condition signal];

		wait = wait && stillOpen;
		keepTrying = wait && ( count > 0 );
	}
	
	[condition unlock];
	
	return rv;
}


- (unsigned) readToContext:   (void *)theContext count:(unsigned)count waitForData:(Boolean)wait
{
	unsigned rv = 0;
	unsigned framesToCopy;
	Boolean keepTrying;
	
	[condition lock];
	
	keepTrying = ( count > 0 );
	wait = wait && stillOpen && isThreadSafe;
	
	while (keepTrying)
	{
		while (wait && stillOpen && (0 == framesInBuffer))
			[condition wait];
		
		if (!stillOpen)
			break;
		
		while (framesInBuffer && count)
		{
			framesToCopy = MIN ( framesInBuffer, count );
			framesToCopy = MIN ( framesToCopy, ( bufferSize - bufferHead ));
			[self performReadToContext:theContext offset:bufferHead count:framesToCopy];
			framesInBuffer -= framesToCopy;
			rv += framesToCopy;
			count -= framesToCopy;
			bufferHead += framesToCopy;
			if (bufferHead >= bufferSize) bufferHead = 0;
		}

		if (framesInBuffer == 0)
			[self bufferDidEmpty];
		
		[condition signal];
		
		wait = wait && stillOpen;
		keepTrying = wait && ( count > 0 );
	}
	
	[condition unlock];
	
	return rv;
}

- (void) close
{
	[condition lock];
	stillOpen = NO;
	[condition broadcast];
	[condition unlock];
}

- (Boolean) isClosed
{
	return (!stillOpen);
}

- (void) configureForSingleThreadedOperation
{
	[condition release];
	condition = nil;
	isThreadSafe = NO;
}

- (void) flush
{
	[condition lock];
	framesInBuffer = 0;
	[self bufferDidEmpty];
	[condition broadcast];
	[condition unlock];
}

- (unsigned) capacity
{
	return bufferSize;
}

- (unsigned) count
{
	return framesInBuffer;
}

- (void) dealloc
{
	[condition release];
	[super dealloc];
}

@end
