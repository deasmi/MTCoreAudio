//
//  MTConversionBuffer.m
//  AudioMonitor
//
//  Created by Michael Thornburgh on Wed Jul 09 2003.
//  Copyright (c) 2004 Michael Thornburgh. All rights reserved.
//

#import "MTConversionBuffer.h"
#import <math.h>
#import <string.h>
#import <vecLib/vecLib.h>

#define SRC_SLOP_FRAMES 8
#define SR_ERROR_ALLOWANCE 1.01 // 1%

static const unsigned kMTConversionBufferTryAgainLater = 'NoMo';

typedef struct CallbackContext_t {
	MTConversionBuffer * theConversionBuffer;
	Boolean wait;
} CallbackContext;

@interface MTConversionBuffer (MTConversionBufferPrivateMethods)
- (OSStatus) _fillComplexBuffer:(AudioBufferList *)ioData countPointer:(UInt32 *)ioNumberFrames waitForData:(Boolean)wait;
@end


static OSStatus _FillComplexBufferProc (
	AudioConverterRef aConveter,
	UInt32 * ioNumberDataPackets,
	AudioBufferList * ioData,
	AudioStreamPacketDescription ** outDataPacketDescription,
	void * inUserData
)
{
	CallbackContext * ctx = inUserData;
	
	return [ctx->theConversionBuffer _fillComplexBuffer:ioData countPointer:ioNumberDataPackets waitForData:ctx->wait];
}


@implementation MTConversionBuffer ( MTConversionBufferPrivateMethods )

- (OSStatus) _fillComplexBuffer:(AudioBufferList *)ioData countPointer:(UInt32 *)ioNumberFrames waitForData:(Boolean)wait
{
	unsigned x;
	unsigned channelsThisBuffer;
	unsigned framesToCopy;
	unsigned framesInBuffer = [audioBuffer count];
	unsigned framesCopied;
	
	framesToCopy = MIN ( *ioNumberFrames, conversionBufferListFrameCount );
	
	if (( 0 == framesInBuffer ) && ( NO == wait ) && delegate && [delegate respondsToSelector:@selector(MTConversionBuffer:needsInputFrames:)] )
	{
		[delegate MTConversionBuffer:self needsInputFrames:( MIN ( framesToCopy, audioBufferFrameCount ))];
	}
	
	framesCopied = [audioBuffer readToAudioBufferList:conversionBufferList maxFrames:framesToCopy waitForData:wait];
	if (( framesCopied < framesToCopy ) && ( NO == wait ))
	{
		if ( delegate && [delegate respondsToSelector:@selector(MTConversionBuffer:didUnderrunFrames:)] )
			[delegate MTConversionBuffer:self didUnderrunFrames:(framesToCopy - framesCopied)];
		if ( shouldProvideSilence )
			framesCopied += MTAudioBufferListClear ( conversionBufferList, framesCopied, framesToCopy - framesCopied );
	}

	// link the appropriate amount of data into the proto-AudioBufferList in ioData
	for ( x = 0; x < ioData->mNumberBuffers; x++ )
	{
		channelsThisBuffer = ioData->mBuffers[x].mNumberChannels;
		ioData->mBuffers[x].mDataByteSize = channelsThisBuffer * framesCopied * sizeof(Float32);
		ioData->mBuffers[x].mData = conversionBufferList->mBuffers[x].mData;
	}
	*ioNumberFrames = framesCopied;

	return (( NO == wait) && ( 0 == framesCopied )) ? kMTConversionBufferTryAgainLater : noErr;
}

@end


@implementation MTConversionBuffer

- (Boolean) _initGainArray
{
	unsigned chan;
	unsigned numChannels = MTAudioBufferListChannelCount(outputBufferList);
	
	gainArray = malloc ( numChannels * sizeof(Float32));
	if ( NULL == gainArray )
		return FALSE;
	
	for ( chan = 0; chan < numChannels; chan++ )
	{
		gainArray[chan] = 1.0;
	}
	return TRUE;
}

- (Boolean) _initAudioConverterWithSourceSampleRate:(Float64)srcRate channels:(UInt32)srcChans destinationSampleRate:(Float64)dstRate channels:(UInt32)dstChans
{
	AudioStreamBasicDescription inputDescription;
	AudioStreamBasicDescription outputDescription;
	UInt32 primeMethod, srcQuality;
	UInt32 * channelMap;
		
	inputDescription  = [[[[[MTCoreAudioStreamDescription nativeStreamDescription] setSampleRate:srcRate] setChannelsPerFrame:srcChans] setIsInterleaved:NO] audioStreamBasicDescription];
	outputDescription = [[[[[MTCoreAudioStreamDescription nativeStreamDescription] setSampleRate:dstRate] setChannelsPerFrame:dstChans] setIsInterleaved:NO] audioStreamBasicDescription];
	
	if ( noErr != AudioConverterNew ( &inputDescription, &outputDescription, &converter ))
	{
		converter = NULL; // just in case
		return FALSE;
	}
	
	primeMethod = kConverterPrimeMethod_None;
	srcQuality = kAudioConverterQuality_Max;
	
	(void) AudioConverterSetProperty ( converter, kAudioConverterPrimeMethod, sizeof(UInt32), &primeMethod );
	(void) AudioConverterSetProperty ( converter, kAudioConverterSampleRateConverterQuality, sizeof(UInt32), &srcQuality );
	
	// if the input is mono, try to route to all channels.
	if (( 1 == srcChans ) && ( dstChans > srcChans ))
	{
		// trick.  The Channel is 0, so we just use calloc() to get an array of zeros.  :)
		channelMap = calloc ( dstChans, sizeof(UInt32));
		if ( channelMap )
		{
			(void) AudioConverterSetProperty ( converter, kAudioConverterChannelMap, dstChans * sizeof(UInt32), channelMap );
			free ( channelMap );
		}
	}
	
	return TRUE;
}

- (UInt32) numBufferFramesForSourceSampleRate:(Float64)srcRate sourceFrames:(UInt32)srcFrames effectiveDestinationFrames:(UInt32)effDstFrames minimumBufferSeconds:(Float64)minBufferSeconds;
{
	// shouldn't be smaller than this, to accommodate imprecise/jittery sample rates and ioproc dispatching,
	// the combination of which can cause significant underrun+overrun distortion as the ioproc dispatches
	// come into and go out of phase
	return MAX ( srcFrames + effDstFrames, minBufferSeconds * srcRate );
}

- initWithSourceSampleRate:(Float64)srcRate channels:(UInt32)srcChans bufferFrames:(UInt32)srcFrames destinationSampleRate:(Float64)dstRate channels:(UInt32)dstChans bufferFrames:(UInt32)dstFrames minimumBufferSeconds:(Float64)minBufferSeconds
{
	UInt32 effectiveDstFrames;
	UInt32 totalBufferFrames;
	UInt32 conversionChannels;
	
	[super init];

	conversionFactor = srcRate / dstRate;
	effectiveDstFrames = ceil ( dstFrames * conversionFactor );
	totalBufferFrames = [self numBufferFramesForSourceSampleRate:srcRate sourceFrames:srcFrames effectiveDestinationFrames:effectiveDstFrames minimumBufferSeconds:minBufferSeconds];	
	if ( srcRate != dstRate )
	{
		effectiveDstFrames += SRC_SLOP_FRAMES;
		totalBufferFrames += SRC_SLOP_FRAMES;
	}
	
	conversionChannels = MIN ( srcChans, dstChans );
	
	audioBuffer = [[MTAudioBuffer alloc] initWithCapacityFrames:totalBufferFrames channels:conversionChannels];
	if (( audioBuffer )
	 && ( conversionBufferList = MTAudioBufferListNew ( conversionChannels, effectiveDstFrames, NO ))
	 && ( outputBufferList     = MTAudioBufferListNew ( dstChans, dstFrames, NO ))
	 && ( [self _initAudioConverterWithSourceSampleRate:srcRate channels:conversionChannels destinationSampleRate:dstRate channels:dstChans]  )
	 && ( [self _initGainArray] ))
	{
		audioBufferFrameCount = totalBufferFrames;
		conversionBufferListFrameCount = effectiveDstFrames;
		outputBufferListFrameCount = dstFrames;
		return self;
	}
	else
	{
		[self dealloc];
		return nil;
	}
}

- (Boolean) _verifyDeviceIsCanonicalFormat:(MTCoreAudioDevice *)theDevice inDirection:(MTCoreAudioDirection)theDirection
{
	NSEnumerator * streamEnumerator = [[theDevice streamsForDirection:theDirection] objectEnumerator];
	MTCoreAudioStream * aStream;
	
	while ( aStream = [streamEnumerator nextObject] )
	{
		if ( ! [[aStream streamDescriptionForSide:kMTCoreAudioStreamLogicalSide] isCanonicalFormat] )
		{
			return FALSE;
		}
	}
	
	return TRUE;
}

- initWithSourceDevice:(MTCoreAudioDevice *)inputDevice destinationDevice:(MTCoreAudioDevice *)outputDevice
{
	if ( [self _verifyDeviceIsCanonicalFormat:inputDevice inDirection:kMTCoreAudioDeviceRecordDirection]
	  && [self _verifyDeviceIsCanonicalFormat:outputDevice inDirection:kMTCoreAudioDevicePlaybackDirection] )
	{
		self = [self
			initWithSourceSampleRate:[inputDevice nominalSampleRate]
			channels:                [inputDevice channelsForDirection:kMTCoreAudioDeviceRecordDirection]
			bufferFrames:            ceil ( [inputDevice deviceMaxVariableBufferSizeInFrames] * SR_ERROR_ALLOWANCE )
			destinationSampleRate:   [outputDevice nominalSampleRate]
			channels:                [outputDevice channelsForDirection:kMTCoreAudioDevicePlaybackDirection]
			bufferFrames:            ceil ( [outputDevice deviceMaxVariableBufferSizeInFrames] * SR_ERROR_ALLOWANCE )
			minimumBufferSeconds:    0.0
		];
		return self;
	}
	else
	{
		[self dealloc];
		return nil;
	}
}

- (void) setGain:(Float32)theGain forOutputChannel:(UInt32)theChannel
{
	if ( theChannel < MTAudioBufferListChannelCount(outputBufferList))
	{
		gainArray[theChannel] = theGain;
	}
}

- (Float32) gainForOutputChannel:(UInt32)theChannel
{
	if ( theChannel < MTAudioBufferListChannelCount(outputBufferList) )
	{
		return gainArray[theChannel];
	}
	else
	{
		return 0.0;
	}
}


- (Float64) _fudgeFactorFromTimeStamp:(const AudioTimeStamp *)timestamp
{
	Float64 rv;
	
	if ( timestamp && ( timestamp->mFlags & kAudioTimeStampRateScalarValid ))
		rv = timestamp->mRateScalar;
	else
		rv = 1.0;
	
	if ( rv > SR_ERROR_ALLOWANCE )
		rv = SR_ERROR_ALLOWANCE;
	else if ( rv < ( 1.0 / SR_ERROR_ALLOWANCE ))
		rv = ( 1.0 / SR_ERROR_ALLOWANCE );
	
	return rv;
}


- (void) writeFromAudioBufferList:(const AudioBufferList *)src timestamp:(const AudioTimeStamp *)timestamp
{
	Float64 rateScalar = [self _fudgeFactorFromTimeStamp:timestamp];
	[self writeFromAudioBufferList:src maxFrames:SIZE_MAX rateScalar:rateScalar waitForRoom:NO];
}

- (unsigned) writeFromAudioBufferList:(const AudioBufferList *)src maxFrames:(unsigned)count rateScalar:(Float64)rateScalar waitForRoom:(Boolean)wait
{
	unsigned framesRequested, framesQueued;
	
	framesRequested = MTAudioBufferListFrameCount ( src );
	framesRequested = MIN ( framesRequested, count );
	framesQueued = [audioBuffer writeFromAudioBufferList:src maxFrames:framesRequested rateScalar:rateScalar waitForRoom:wait];
	if (( framesQueued != framesRequested ) && delegate && [delegate respondsToSelector:@selector(MTConversionBuffer:didOverrunFrames:)] )
		[delegate MTConversionBuffer:self didOverrunFrames:(framesRequested - framesQueued)];
	return framesQueued;
}


- (void) readToAudioBufferList:(AudioBufferList *)dst timestamp:(const AudioTimeStamp *)timestamp
{
	Float64 rateScalar = [self _fudgeFactorFromTimeStamp:timestamp];
	[self readToAudioBufferList:dst offset:0 maxFrames:SIZE_MAX rateScalar:rateScalar waitForData:NO];
}

- (unsigned) readToAudioBufferList:(AudioBufferList *)dst offset:(unsigned)offset maxFrames:(unsigned)count rateScalar:(Float64)rateScalar waitForData:(Boolean)wait
{
	unsigned dstFrameCount = MTAudioBufferListFrameCount ( dst );
	UInt32 framesToRead = MIN ( MIN (( dstFrameCount > offset ) ? ( dstFrameCount - offset ) : 0, outputBufferListFrameCount ), count );
	UInt32 chan, outputChannels;
	Float32 * samples;
	UInt32 framesRead;
	CallbackContext callbackContext;
	
	callbackContext.theConversionBuffer = self;
	callbackContext.wait = wait;
		
	outputChannels = MTAudioBufferListChannelCount(outputBufferList);
	framesRead = framesToRead;
	AudioConverterFillComplexBuffer ( converter, _FillComplexBufferProc, &callbackContext, &framesRead, outputBufferList, NULL );
	MTAudioBufferListSetFrameCount ( outputBufferList, outputBufferListFrameCount ); // gross
	if ( framesRead > 0 )
	{
		// XXX requires that outputBufferList is de-interleaved, which it should be
		for ( chan = 0; chan < outputChannels; chan++ )
		{
			samples = outputBufferList->mBuffers[chan].mData;
			vsmul ( samples, 1, &gainArray[chan], samples, 1, framesRead );
		}
		MTAudioBufferListCopy ( outputBufferList, 0, dst, offset, framesRead );
	}
	
	return framesRead;
}

- (void) close
{
	[audioBuffer close];
}

- (void) flush
{
	[audioBuffer flush];
	AudioConverterReset ( converter );
}

- (void) setProvideSilenceWhenEmpty:(Boolean)aFlag
{
	shouldProvideSilence = aFlag;
}

- (void) configureForSingleThreadedOperation
{
	[audioBuffer configureForSingleThreadedOperation];
}

- (unsigned) count
{
	return [audioBuffer count];
}

- (unsigned) destinationCount
{
	return [self count] / conversionFactor;
}

- delegate
{
	return delegate;
}

- (void) setDelegate:anObject
{
	delegate = anObject;
}

- (void) dealloc
{
	if ( converter )
		AudioConverterDispose ( converter );
	MTAudioBufferListDispose ( conversionBufferList );
	MTAudioBufferListDispose ( outputBufferList );
	[audioBuffer release];
	if ( gainArray )
		free ( gainArray );
	[super dealloc];
}

@end
