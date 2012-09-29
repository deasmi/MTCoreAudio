#import <Foundation/Foundation.h>
#import <MTCoreAudio/MTCoreAudio.h>
#import <CoreAudio/HostTime.h>
#import <math.h>
#import <unistd.h>
#import <stdio.h>
#import "TestDelegate.h"

MTCoreAudioDevice * globalDevice;

OSStatus mySimpleIOProc (
	AudioDeviceID		inDevice,
	const AudioTimeStamp*	inNow,
	const AudioBufferList*	inInputData,
	const AudioTimeStamp*	inInputTime,
	AudioBufferList*	outOutputData, 
	const AudioTimeStamp*	inOutputTime,
	void*			inClientData
)
{
	static double phase;
	int x, c, s;
	double stride;
	UInt32 samplesPerBuffer;
	double phasePerStream;
	static UInt64 firstTime = 0;
	static UInt64 totalSamples = 0;
	
	if (firstTime == 0)
		firstTime = inOutputTime->mHostTime;
		
	if (totalSamples > 88200)
	{
		printf ( "computed sample rate: %f\n", ((double)totalSamples / (double)(inOutputTime->mHostTime - firstTime)) * AudioGetHostClockFrequency());
		printf ( "reported actual sample rate: %lf\n", [globalDevice actualSampleRate] );
		firstTime = inOutputTime->mHostTime;
		totalSamples = 0;
	}
	
	stride = *(double *)inClientData;
	
	for ( s = 0; s < outOutputData->mNumberBuffers; s++ )
	{
		phasePerStream = phase;
		samplesPerBuffer = outOutputData->mBuffers[s].mDataByteSize / sizeof(Float32);
		totalSamples += samplesPerBuffer / outOutputData->mBuffers[s].mNumberChannels;
		for ( x = 0; x < samplesPerBuffer; x+=outOutputData->mBuffers[s].mNumberChannels )
		{
			for ( c = 0; c < outOutputData->mBuffers[s].mNumberChannels; c++ )
			{
				((Float32 *)(outOutputData->mBuffers[s].mData))[x + c] = sin ( phasePerStream ) * 0.01 ;
			}
			phasePerStream += stride;
			while (phasePerStream > (2.0 * M_PI))
				phasePerStream -= (2.0 * M_PI);
		}
	}
	
	phase = phasePerStream;
	
	return 0;
}

int main (int argc, const char * argv[]) {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSArray * theSources;
	NSEnumerator * deviceEnumerator;
	NSEnumerator * streamEnumerator;
	MTCoreAudioDevice * myDevice;
	MTCoreAudioStream * myStream;
	double myStride;
	TestDelegate * myDelegate;
	MTCoreAudioStreamDescription * myDescription, * physicalDescription;
	UInt32 numChannels;
	
	myDelegate = [[[TestDelegate alloc] init] autorelease];
	
	[MTCoreAudioDevice setDelegate:myDelegate];
    
	// insert code here...
	// [[MTCoreAudioDevice defaultInputDevice] setDataSource:@"Internal Microphone" forChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] ;
	// [[MTCoreAudioDevice defaultInputDevice] setDeviceBufferSizeInFrames:512];
	printf ( "all devices: %s\n", [[[MTCoreAudioDevice allDevices] description] cString] );
	printf ( "all devices by relation: %s\n\n", [[[MTCoreAudioDevice allDevicesByRelation] description] cString] );
	deviceEnumerator = [[MTCoreAudioDevice allDevices] objectEnumerator];
	while ( myDevice = [deviceEnumerator nextObject] )
	{
		printf ( "device %d: %s %s   manufacturer: %s\n", (int) [myDevice deviceID], [[myDevice deviceName] cString], [[myDevice deviceUID] cString], [[myDevice deviceManufacturer] cString]);
		printf ( "related devices: %s\n", [[[myDevice relatedDevices] description] cString] );
		printf ( "   Buffer size in frames: %ld (%ld - %ld), latency (I/O): %ld/%ld, safety (I/O): %ld/%ld\n",
			[myDevice deviceBufferSizeInFrames], [myDevice deviceMinBufferSizeInFrames],
			[myDevice deviceMaxBufferSizeInFrames],
			[myDevice deviceLatencyFramesForDirection:kMTCoreAudioDeviceRecordDirection],
			[myDevice deviceLatencyFramesForDirection:kMTCoreAudioDevicePlaybackDirection],
			[myDevice deviceSafetyOffsetFramesForDirection:kMTCoreAudioDeviceRecordDirection],
			[myDevice deviceSafetyOffsetFramesForDirection:kMTCoreAudioDevicePlaybackDirection]
		);
		printf ( "   Channels: %ld (record)   %ld (playback)\n",
			[myDevice channelsForDirection:kMTCoreAudioDeviceRecordDirection],
			[myDevice channelsForDirection:kMTCoreAudioDevicePlaybackDirection]
		);
		printf ( "    Nominal sample rate: %lf\n", [myDevice nominalSampleRate] );
		printf ( "    Available nominal sample rate ranges: %s\n", [[[myDevice nominalSampleRates] description] cString] );
		if ((numChannels = [myDevice channelsForDirection:kMTCoreAudioDeviceRecordDirection]) > 0)
		{
			printf ( "   Record clock source: %s\n", [[myDevice clockSourceForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] cString] );
			printf ( "      Available record clock sources: %s\n", [[[myDevice clockSourcesForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] description] cString] );
			printf ( "   Record format: %s\n", [[[myDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] description] cString] );
			printf ( "   Available record formats:  %s\n", [[[myDevice streamDescriptionsForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] description] cString] );
			printf ( "   record source: %s\n", [[myDevice dataSourceForDirection:kMTCoreAudioDeviceRecordDirection] cString] );
			theSources = [myDevice dataSourcesForDirection:kMTCoreAudioDeviceRecordDirection];
			if (theSources)
				printf ( "      available sources: %s\n", [[theSources description] cString] );
		}
			
		if ((numChannels = [myDevice channelsForDirection:kMTCoreAudioDevicePlaybackDirection]) > 0)
		{
			printf ( "   Playback clock source: %s\n", [[myDevice clockSourceForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection] cString] );
			printf ( "      Available playback clock sources: %s\n", [[[myDevice clockSourcesForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection] description] cString] );
			printf ( "   Playback format: %s\n", [[[myDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection] description] cString] );
			printf ( "   Available playback formats:  %s\n", [[[myDevice streamDescriptionsForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection] description] cString] );
			printf ( "   playback source: %s\n", [[myDevice dataSourceForDirection:kMTCoreAudioDevicePlaybackDirection] cString] );
			theSources = [myDevice dataSourcesForDirection:kMTCoreAudioDevicePlaybackDirection];
			if (theSources)
				printf ( "      available sources: %s\n", [[theSources description] cString] );
		}

		[myDevice setDelegate:myDelegate];
		
		streamEnumerator = [[myDevice streamsForDirection:kMTCoreAudioDevicePlaybackDirection] objectEnumerator];
		while ( myStream = [streamEnumerator nextObject] )
		{
			printf ("   %s\n", [[myStream description] cString] );
			printf ("   playback stream %ld: %s\n", [myStream streamID], [[myStream streamName] cString]);
			printf ("   data source: %s\n", [[myStream dataSource] cString] );
			printf ("   available sources: %s\n", [[[myStream dataSources] description] cString] );
			printf ("   clock source: %s\n", [[myStream clockSource] cString] );
			printf ("   available clock sources: %s\n", [[[myStream clockSources] description] cString] );
			printf ("   available logical formats: %s\n", [[[myStream streamDescriptionsForSide:kMTCoreAudioStreamLogicalSide] description] cString] );
			printf ("   available physical formats: %s\n", [[[myStream streamDescriptionsForSide:kMTCoreAudioStreamPhysicalSide] description] cString] );
		}
		streamEnumerator = [[myDevice streamsForDirection:kMTCoreAudioDeviceRecordDirection] objectEnumerator];
		while ( myStream = [streamEnumerator nextObject] )
		{
			printf ("   %s\n", [[myStream description] cString] );
			printf ("   record stream %ld: %s\n", [myStream streamID], [[myStream streamName] cString]);
			printf ("   data source: %s\n", [[myStream dataSource] cString] );
			printf ("   available sources: %s\n", [[[myStream dataSources] description] cString] );
			printf ("   clock source: %s\n", [[myStream clockSource] cString] );
			printf ("   available clock sources: %s\n", [[[myStream clockSources] description] cString] );
			printf ("   available logical formats: %s\n", [[[myStream streamDescriptionsForSide:kMTCoreAudioStreamLogicalSide] description] cString] );
			printf ("   available physical formats: %s\n", [[[myStream streamDescriptionsForSide:kMTCoreAudioStreamPhysicalSide] description] cString] );
		}
	}
	
	printf ( "\n\n\n" );
	
	myDevice = [MTCoreAudioDevice defaultOutputDevice];
	myDescription = [MTCoreAudioStreamDescription streamDescription];
	[myDescription setChannelsPerFrame:2];
	[myDescription setSampleRate:44100.0];
	[myDescription setBitsPerChannel:16];
	
	myStream = [[myDevice streamsForDirection:kMTCoreAudioDevicePlaybackDirection] objectAtIndex:0];
	physicalDescription = [myStream matchStreamDescription:myDescription forSide:kMTCoreAudioStreamPhysicalSide];
	printf ( "matched to %s\n", [[physicalDescription description] cString] );
	[myStream setStreamDescription:physicalDescription forSide:kMTCoreAudioStreamPhysicalSide];
	sleep(1);
	myStride = (2.0 * M_PI * 440.0) / [[myDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection] sampleRate];

	globalDevice = myDevice;
	[myDevice setIOProc:mySimpleIOProc withClientData:&myStride];
	[myDevice deviceStart];
	
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:30]];

	[pool release];
	
	printf ( "\nautorelease pool released, objects deallocated, sounds and notifications should stop.\n" );
	sleep(10);
	
	return 0;
}
