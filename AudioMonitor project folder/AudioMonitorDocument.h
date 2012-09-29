//
//  AudioMonitorDocument.h
//  AudioMonitor
//
//  Created by Michael Thornburgh on Thu Oct 03 2002.
//  Copyright (c) 2003 Michael Thornburgh. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <MTCoreAudio/MTCoreAudio.h>
#import "MTConversionBufferProto.h"

@class MTConversionBuffer;

@interface AudioMonitorDocument : NSDocument
{
	id adjustLeftSlider;
	id adjustLeftLabel;
	id adjustRightSlider;
	id adjustRightLabel;
	id playthroughButton;
	id recordDeviceBrowser;
	id playbackDeviceBrowser;
	
	MTCoreAudioDevice * inputDevice;
	MTCoreAudioDevice * outputDevice;
	id<MTConversionBuffer> converter;

	double adjustLeft;
	double adjustRight;
}

- (void) playthroughButton:(id)sender;
- (void) setAdjustVolume:(id)sender;
@end
