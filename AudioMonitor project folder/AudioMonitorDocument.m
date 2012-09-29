//
//  AudioMonitorDocument.m
//  AudioMonitor
//
//  Created by Michael Thornburgh on Thu Oct 03 2002.
//  Copyright (c) 2003 Michael Thornburgh. All rights reserved.
//

#import "AudioMonitorDocument.h"
#import "MTAudioDeviceBrowser.h"
#import "MTConversionBuffer.h"
#import "MTVarispeedConversionBuffer.h"
#import <math.h>

// also try MTVarispeedConversionBuffer
#define CONVERSIONBUFFERCLASS MTVarispeedConversionBuffer

static double _db_to_scalar ( Float32 decibels )
{
	return pow ( 10.0, decibels / 20.0 );
}


@implementation AudioMonitorDocument

- (NSString *)displayName
{
	return @"Audio Monitor";
}

- (NSString *)windowNibName
{
	return @"AudioMonitorDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[super windowControllerDidLoadNib:aController];
	
	[self setAdjustVolume:adjustLeftSlider];
	[self setAdjustVolume:adjustRightSlider];
	[recordDeviceBrowser setDirection:kMTCoreAudioDeviceRecordDirection];
	[playbackDeviceBrowser setDirection:kMTCoreAudioDevicePlaybackDirection];
	[[aController window] setFrameAutosaveName:@"Audio Monitor"];
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	return nil;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
	return YES;
}

// ------------------- ioTarget methods ---------------
- (OSStatus) recordIOForDevice:(MTCoreAudioDevice *)theDevice timeStamp:(const AudioTimeStamp *)inNow inputData:(const AudioBufferList *)inInputData inputTime:(const AudioTimeStamp *)inInputTime outputData:(AudioBufferList *)outOutputData outputTime:(const AudioTimeStamp *)inOutputTime clientData:(void *)inClientData
{
	[converter writeFromAudioBufferList:inInputData timestamp:inInputTime];
	return noErr;
}

- (OSStatus) playbackIOForDevice:(MTCoreAudioDevice *)theDevice timeStamp:(const AudioTimeStamp *)inNow inputData:(const AudioBufferList *)inInputData inputTime:(const AudioTimeStamp *)inInputTime outputData:(AudioBufferList *)outOutputData outputTime:(const AudioTimeStamp *)inOutputTime clientData:(void *)inClientData
{
	[converter readToAudioBufferList:outOutputData timestamp:inOutputTime];
	return noErr;
}
// ----------------------------------


- (void) MTAudioDeviceBrowser:(MTAudioDeviceBrowser *)theBrowser selectedDeviceDidChange:(MTCoreAudioDevice *)newDevice
{
	MTCoreAudioDevice ** whichDevice;
	SEL whichSelector;
	
	if ( theBrowser == recordDeviceBrowser )
	{
		whichDevice = &inputDevice;
		whichSelector = @selector(recordIOForDevice:timeStamp:inputData:inputTime:outputData:outputTime:clientData:);
	}
	else if ( theBrowser == playbackDeviceBrowser )
	{
		whichDevice = &outputDevice;
		whichSelector = @selector(playbackIOForDevice:timeStamp:inputData:inputTime:outputData:outputTime:clientData:);
	}
	else
		return;
	
	[*whichDevice release];
	*whichDevice = newDevice;
	
	[newDevice retain];
	[newDevice setDelegate:self];
	[newDevice setIOTarget:self withSelector:whichSelector withClientData:nil];
	[newDevice setDeviceBufferSizeInFrames:ceil(([newDevice nominalSampleRate] / 100))];
	[self playthroughButton:playthroughButton];
}

- (void) allocNewConverter
{
	[converter release];
	converter = [[CONVERSIONBUFFERCLASS alloc] initWithSourceDevice:inputDevice destinationDevice:outputDevice];
	[converter setDelegate:self];
	[converter setGain:adjustLeft forOutputChannel:0];
	[converter setGain:adjustRight forOutputChannel:1];
}

- (void) playthroughButton:(id)sender
{
	if ([sender state])
	{
		[inputDevice  setDevicePaused:YES];  // lock out IO cycles while we change a resource they use
		[outputDevice setDevicePaused:YES];
		[self allocNewConverter];
		[outputDevice setDevicePaused:NO];
		[inputDevice  setDevicePaused:NO];
		
		if ( ! ( [outputDevice deviceStart] && [inputDevice deviceStart] ))
		{
			[sender setState:FALSE];
			[self playthroughButton:sender];
		}
	}
	else
	{
		[inputDevice  deviceStop];
		[outputDevice deviceStop];
	}
}

- (void) setAdjustVolume:(id)sender
{
	double * whichAdjust;
	id whichLabel;
	UInt32 whichChannel;
	
	if (sender == adjustLeftSlider)
	{
		whichLabel = adjustLeftLabel;
		whichAdjust = &adjustLeft;
		whichChannel = 0;
	}
	else
	{
		whichLabel = adjustRightLabel;
		whichAdjust = &adjustRight;
		whichChannel = 1;
	}
	
	[whichLabel setFloatValue:[sender floatValue]];
	*whichAdjust = _db_to_scalar ( [sender floatValue] );
	[converter setGain:*whichAdjust forOutputChannel:whichChannel];
}

- (void) audioDeviceDidOverload:(MTCoreAudioDevice *)theDevice
{
	NSLog ( @"overload: %@", [theDevice deviceUID] );
}

- (void) audioDeviceStartDidFail:(MTCoreAudioDevice *)theDevice forReason:(OSStatus)theReason
{
	NSLog ( @"device:%@ start failed, reason:%4.4s\n", [theDevice deviceUID], (char *)&theReason );
}

- (void) MTConversionBuffer:sender didUnderrunFrames:(unsigned)count
{
	NSLog ( @"underrun frames: %u\n", count );
}

- (void) MTConversionBuffer:sender didOverrunFrames:(unsigned)count
{
	NSLog ( @"overrun frames: %u\n", count );
}

- (void) audioDeviceBufferSizeInFramesDidChange:sender
{
	[self playthroughButton:playthroughButton];
}

- (void) audioDeviceNominalSampleRateDidChange:sender
{
	[self playthroughButton:playthroughButton];
}

- (void) audioDeviceStreamsListDidChange:theDevice
{
	[self playthroughButton:playthroughButton];
}

- (void) audioDeviceChannelsByStreamDidChange:(MTCoreAudioDevice *)theDevice forDirection:(MTCoreAudioDirection)theDirection
{
	if ((( theDevice == inputDevice ) && ( theDirection == kMTCoreAudioDeviceRecordDirection )) ||
	    (( theDevice == outputDevice ) && ( theDirection == kMTCoreAudioDevicePlaybackDirection )))
	{
		[self playthroughButton:playthroughButton];
	}
}

- (void) dealloc
{
	[inputDevice release];
	[outputDevice release];
	[converter release];
	
	[super dealloc];
}

@end
