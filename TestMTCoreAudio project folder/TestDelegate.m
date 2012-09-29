//
//  TestDelegate.m
//  TestMTCoreAudio
//
//  Created by Michael Thornburgh on Fri Dec 28 2001.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <MTCoreAudio/MTCoreAudio.h>
#import "TestDelegate.h"

static const char * directionDescription ( MTCoreAudioDirection theDirection )
{
	if (theDirection == kMTCoreAudioDeviceRecordDirection )
		return "record";
	else
		return "playback";
}

@implementation TestDelegate : NSObject

- (void) audioHardwareDeviceListDidChange
{
	printf ("audioHardwareDeviceListDidChange\n");
}

- (void) audioHardwareDefaultInputDeviceDidChange
{
	printf ("audioHardwareDefaultInputDeviceDidChange\n");
}

- (void) audioHardwareDefaultOutputDeviceDidChange
{
	printf ("audioHardwareDefaultOutputDeviceDidChange\n");
}

- (void) audioHardwareDefaultSystemOutputDeviceDidChange
{
	printf ("audioHardwareDefaultSystemOutputDeviceDidChange\n");
}

- (void) audioDeviceDidDie:(id)sender
{
	printf ("%s audioDeviceDidDie:%ld\n", [[sender description] cString], [sender deviceID] );
}

- (void) audioDeviceBufferSizeInFramesDidChange:(id)sender
{
	printf ("%s audioDeviceBufferSizeInFramesDidChange\n", [[sender description] cString] );
}

- (void) audioDeviceSomethingDidChange:(id)sender
{
	printf ( "%s audioDeviceSomethingDidChange\n", [[sender description] cString] );
}

- (void) audioDeviceStreamsListDidChange:(id)sender
{
	printf ("%s audioDeviceStreamsListDidChange\n", [[sender description] cString]);
}

- (void) audioDeviceChannelsByStreamDidChange:(id)sender forDirection:(MTCoreAudioDirection)theDirection
{
	printf ("%s audioDeviceChannelsByStreamDidChange for %s direction\n", [[sender description] cString], directionDescription(theDirection));
}

- (void) audioDeviceStreamDescriptionDidChange:(id)sender forChannel:(UInt32)theChannel forDirection:(MTCoreAudioDirection)theDirection
{
	printf ("%s audioDeviceStreamDescriptionDidChange for channel: %ld  for direction: %s\n", [[sender description] cString], theChannel, directionDescription(theDirection));
		
}

- (void) audioDeviceNominalSampleRateDidChange:(MTCoreAudioDevice *)theDevice
{
	printf ( "%s audioDeviceNominalSampleRateDidChange\n", [[theDevice description] cString] );
}

- (void) audioDeviceNominalSampleRatesDidChange:(MTCoreAudioDevice *)theDevice
{
	printf ( "%s audioDeviceNominalSampleRatesDidChange\n", [[theDevice description] cString] );
}

- (void) audioDeviceVolumeInfoDidChange:(id)sender forChannel:(UInt32)theChannel forDirection:(MTCoreAudioDirection)theDirection
{
	printf ("%s audioDeviceVolumeInfoDidChange for channel: %ld  for direction: %s\n", [[sender description] cString], theChannel, directionDescription(theDirection));
}


- (void) audioDeviceVolumeDidChange:(id)sender forChannel:(UInt32)theChannel forDirection:(MTCoreAudioDirection)theDirection
{
	printf ("%s audioDeviceVolumeDidChange for channel: %ld  for direction: %s\n", [[sender description] cString], theChannel, directionDescription(theDirection));
}

- (void) audioDeviceMuteDidChange:(id)sender forChannel:(UInt32)theChannel forDirection:(MTCoreAudioDirection)theDirection
{
	printf ("%s audioDeviceMuteDidChange for channel: %ld  for direction: %s\n", [[sender description] cString], theChannel, directionDescription(theDirection));
}

- (void) audioDevicePlayThruDidChange:(id)sender forChannel:(UInt32)theChannel forDirection:(MTCoreAudioDirection)theDirection
{
	printf ("%s audioDevicePlayThruDidChange for channel: %ld  for direction: %s\n", [[sender description] cString], theChannel, directionDescription(theDirection));
}

- (void) audioDeviceSourceDidChange:(id)sender forDirection:(MTCoreAudioDirection)theDirection
{
	printf ("%s audioDeviceSourceDidChange for direction: %s\n", [[sender description] cString], directionDescription(theDirection));
}

- (void) audioDeviceClockSourceDidChange:(id)sender forChannel:(UInt32)theChannel forDirection:(MTCoreAudioDirection)theDirection
{
	printf ("%s audioDeviceClockSourceDidChange for channel: %ld  for direction: %s\n", [[sender description] cString], theChannel, directionDescription(theDirection));
}

- (void) audioStreamStreamDescriptionDidChange:(id)sender forSide:(MTCoreAudioStreamSide)theSide
{
	printf ("%s audioStreamStreamDescriptionDidChange for stream:%ld forSide:%s\n",
		[[sender description] cString],
		[sender streamID],
		theSide == kMTCoreAudioStreamLogicalSide ? "logical" : "physical"
	);
}

- (void) audioStreamVolumeInfoDidChange:(id)sender forChannel:(UInt32)theChannel
{
	printf ("%s audioStreamVolumeInfoDidChange for stream:%ld forChannel:%ld\n", [[sender description] cString], [sender streamID], theChannel );
}

- (void) audioStreamVolumeDidChange:(id)sender forChannel:(UInt32)theChannel
{
	printf ("%s audioStreamVolumeDidChange for stream:%ld forChannel:%ld\n", [[sender description] cString], [sender streamID], theChannel );
}

- (void) audioStreamMuteDidChange:(id)sender forChannel:(UInt32)theChannel
{
	printf ("%s audioStreamMuteDidChange for stream:%ld forChannel:%ld\n", [[sender description] cString], [sender streamID], theChannel );
}

- (void) audioStreamPlayThruDidChange:(id)sender forChannel:(UInt32)theChannel
{
	printf ("%s audioStreamPlayThruDidChange for stream:%ld forChannel:%ld\n", [[sender description] cString], [sender streamID], theChannel );
}

- (void) audioStreamSourceDidChange:(id)sender
{
	printf ("%s audioStreamSourceDidChange for stream:%ld\n", [[sender description] cString], [sender streamID] );
}

- (void) audioStreamClockSourceDidChange:(id)sender
{
	printf ("%s audioStreamClockSourceDidChange for stream:%ld\n", [[sender description] cString], [sender streamID] );
}

- (void) dealloc
{
	printf ("dealloc TestDelegate\n");
	if (self == [MTCoreAudioDevice delegate])
		[MTCoreAudioDevice setDelegate:nil];
	[super dealloc];
}

@end
