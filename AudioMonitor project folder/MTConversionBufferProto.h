//
//  MTConversionBufferProto.h
//  AudioMonitor
//
//  Created by Michael Thornburgh on Thu Apr 29 2004.
//  Copyright (c) 2004 Michael Thornburgh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MTCoreAudio/MTCoreAudio.h>


@protocol MTConversionBuffer <NSObject>

- initWithSourceDevice:(MTCoreAudioDevice *)inputDevice destinationDevice:(MTCoreAudioDevice *)outputDevice;
- initWithSourceSampleRate:(Float64)srcRate
	channels:(UInt32)srcChans
	bufferFrames:(UInt32)srcFrames
	destinationSampleRate:(Float64)dstRate
	channels:(UInt32)dstChans
	bufferFrames:(UInt32)dstFrames
	minimumBufferSeconds:(Float64)minBufferSeconds;

- (void) setGain:(Float32)theGain forOutputChannel:(UInt32)theChannel;
- (Float32) gainForOutputChannel:(UInt32)theChannel;

- (void) writeFromAudioBufferList:(const AudioBufferList *)src timestamp:(const AudioTimeStamp *)timestamp;
- (unsigned) writeFromAudioBufferList:(const AudioBufferList *)src maxFrames:(unsigned)count rateScalar:(Float64)rateScalar waitForRoom:(Boolean)wait;

- (void) readToAudioBufferList:(AudioBufferList *)dst timestamp:(const AudioTimeStamp *)timestamp;
- (unsigned) readToAudioBufferList:(AudioBufferList *)dst offset:(unsigned)offset maxFrames:(unsigned)count rateScalar:(Float64)rateScalar waitForData:(Boolean)wait;

- (void) setProvideSilenceWhenEmpty:(Boolean)aFlag;

- delegate;
- (void) setDelegate:anObject;

- (void) close;
- (void) flush;
- (void) configureForSingleThreadedOperation;

- (unsigned) count;
- (unsigned) destinationCount;

@end


@interface NSObject ( MTConversionBufferDelegateMethods )

- (void) MTConversionBuffer:sender needsInputFrames:(unsigned)minRequestedFrames;
- (void) MTConversionBuffer:sender didUnderrunFrames:(unsigned)count;
- (void) MTConversionBuffer:sender didOverrunFrames:(unsigned)count;

@end
