//
//  MTVarispeedConversionBuffer.m
//  AudioMonitor
//
//  Created by Michael Thornburgh on Thu Apr 22 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "MTVarispeedConversionBuffer.h"

#import <math.h>
#import <string.h>
#import <vecLib/vecLib.h>

#define SRC_SLOP_FRAMES 8
#define SR_ERROR_ALLOWANCE 1.01 // 1%

@interface MTVarispeedConversionBuffer ( MTVarispeedConversionBufferRenderer )
- (OSStatus) _renderToBuffer:(AudioBufferList *)ioData renderActionFlags:(AudioUnitRenderActionFlags *)ioActionFlags timestamp:(const AudioTimeStamp *)inTimeStamp frames:(unsigned)count;
@end

static OSStatus _renderCallback (
	void                            *inRefCon, 
	AudioUnitRenderActionFlags      *ioActionFlags, 
	const AudioTimeStamp            *inTimeStamp, 
	UInt32                          inBusNumber, 
	UInt32                          inNumberFrames, 
	AudioBufferList                 *ioData )
{
	MTVarispeedConversionBuffer * self = inRefCon;
	return [self _renderToBuffer:ioData renderActionFlags:ioActionFlags timestamp:inTimeStamp frames:inNumberFrames];
}

@implementation MTVarispeedConversionBuffer ( MTVarispeedConversionBufferRenderer )

- (OSStatus) _renderToBuffer:(AudioBufferList *)ioData renderActionFlags:(AudioUnitRenderActionFlags *)ioActionFlags timestamp:(const AudioTimeStamp *)inTimeStamp frames:(unsigned)count
{
	unsigned framesRead;
	unsigned framesAvailable = [audioBuffer count];
	
	if (( framesAvailable < count ) && ( NO == readerCanWait ) && delegate && [delegate respondsToSelector:@selector(MTConversionBuffer:needsInputFrames:)] )
	{
		[delegate MTConversionBuffer:self needsInputFrames:( count - framesAvailable )];
	}

	framesRead = [audioBuffer readToAudioBufferList:ioData maxFrames:count waitForData:readerCanWait];
	if ( framesRead < count )
	{
		MTAudioBufferListClear ( ioData, framesRead, count - framesRead );
		if ( delegate && [delegate respondsToSelector:@selector(MTConversionBuffer:didUnderrunFrames:)] )
			[delegate MTConversionBuffer:self didUnderrunFrames:(count - framesRead)];
	}
	if ( 0 == framesRead )
		silenceCounter++;
	else
		silenceCounter = 0;
	
	return noErr;
}

@end


@implementation MTVarispeedConversionBuffer

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

- (Boolean) _initAudioUnitsWithSourceSampleRate:(Float64)srcRate channels:(UInt32)srcChans destinationSampleRate:(Float64)dstRate channels:(UInt32)dstChans
{
	AudioStreamBasicDescription inputDescription;
	AudioStreamBasicDescription outputDescription;
	UInt32 * channelMap;
	ComponentDescription desc;
	Component comp;
	AURenderCallbackStruct input;
	AudioUnitConnection connection;
	OSStatus theErr;
		
	inputDescription  = [[[[[MTCoreAudioStreamDescription nativeStreamDescription] setSampleRate:srcRate] setChannelsPerFrame:srcChans] setIsInterleaved:NO] audioStreamBasicDescription];
	outputDescription = [[[[[MTCoreAudioStreamDescription nativeStreamDescription] setSampleRate:dstRate] setChannelsPerFrame:dstChans] setIsInterleaved:NO] audioStreamBasicDescription];
	
	desc.componentType = kAudioUnitType_FormatConverter;
	desc.componentSubType = kAudioUnitSubType_AUConverter;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	comp = FindNextComponent ( NULL, &desc );
	theErr = OpenAComponent ( comp, &converterUnit );
	if (  noErr != theErr )
		return FALSE;
	theErr = AudioUnitInitialize ( converterUnit );
	theErr = AudioUnitSetProperty ( converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &inputDescription, sizeof(AudioStreamBasicDescription));
	theErr = AudioUnitSetProperty ( converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outputDescription, sizeof(AudioStreamBasicDescription));
	
	desc.componentType = kAudioUnitType_FormatConverter;
	desc.componentSubType = kAudioUnitSubType_Varispeed;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	comp = FindNextComponent ( NULL, &desc );
	theErr = OpenAComponent ( comp, &varispeedUnit );
	if ( noErr != theErr )
		return FALSE;  // XXX maybe hook up to the converter unit instead
	theErr = AudioUnitSetProperty ( varispeedUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outputDescription, sizeof(AudioStreamBasicDescription));
	theErr = AudioUnitSetProperty ( varispeedUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outputDescription, sizeof(AudioStreamBasicDescription));
	theErr = AudioUnitInitialize ( varispeedUnit );

	connection.sourceAudioUnit = converterUnit;
	connection.sourceOutputNumber = 0;
	connection.destInputNumber = 0;
	theErr = AudioUnitSetProperty ( varispeedUnit, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input, 0, &connection, sizeof(connection));
	if ( noErr != theErr )
		return FALSE;
	
	input.inputProc = _renderCallback;
	input.inputProcRefCon = self;
	theErr = AudioUnitSetProperty ( converterUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &input, sizeof(input));
	
	// if the input is mono, try to route to all channels.
	if (( 1 == srcChans ) && ( dstChans > srcChans ))
	{
		// trick.  The Channel is 0, so we just use calloc() to get an array of zeros.  :)
		channelMap = calloc ( dstChans, sizeof(UInt32));
		if ( channelMap )
		{
			theErr = AudioUnitSetProperty ( converterUnit, kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, channelMap, dstChans * sizeof(UInt32));
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

	readTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
	
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
	 && ( outputBufferList     = MTAudioBufferListNew ( dstChans, dstFrames, NO ))
	 && ( [self _initAudioUnitsWithSourceSampleRate:srcRate channels:conversionChannels destinationSampleRate:dstRate channels:dstChans]  )
	 && ( [self _initGainArray] ))
	{
		audioBufferFrameCount = totalBufferFrames;
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

- (void) _setVarispeedRateScalar:(Float32)theRate
{
	OSStatus theErr;
	theErr = AudioUnitSetParameter ( varispeedUnit, kVarispeedParam_PlaybackRate, kAudioUnitScope_Global, 0, theRate, 0 );
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
	OSStatus theErr;
	AudioUnitRenderActionFlags actionFlags = 0;
	
	readerCanWait = wait;
	
	[self _setVarispeedRateScalar:(rateScalar / [audioBuffer rateScalar])];
	outputChannels = MTAudioBufferListChannelCount(outputBufferList);
	theErr = AudioUnitRender ( varispeedUnit, &actionFlags, &readTimeStamp, 0, framesToRead, outputBufferList );
	MTAudioBufferListSetFrameCount ( outputBufferList, outputBufferListFrameCount ); // gross
	readTimeStamp.mSampleTime += framesToRead;
	if (( noErr == theErr ) && (( silenceCounter < 2 ) || shouldProvideSilence )) // grosser
	{
		for ( chan = 0; chan < outputChannels; chan++ )
		{
			samples = outputBufferList->mBuffers[chan].mData;
			vsmul ( samples, 1, &gainArray[chan], samples, 1, framesToRead );
		}
		MTAudioBufferListCopy ( outputBufferList, 0, dst, offset, framesToRead );
	}
	else
		framesToRead = 0;
		
	return framesToRead;
}

- (void) close
{
	[audioBuffer close];
}

- (void) flush
{
	[audioBuffer flush];
	// AudioConverterReset ( converter );
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
	return [audioBuffer scaledCount] / conversionFactor;
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
	MTAudioBufferListDispose ( outputBufferList );
	[audioBuffer release];
	if ( gainArray )
		free ( gainArray );
	if ( varispeedUnit )
		CloseComponent ( varispeedUnit );
	if ( converterUnit )
		CloseComponent ( converterUnit );
	[super dealloc];
}

@end
