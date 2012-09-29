//
//  MTAudioDeviceBrowser.h
//  MTCoreAudio
//
//  Created by Michael Thornburgh on Fri Jun 14 2002.
//  Copyright (c) 2003 Michael Thornburgh. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <MTCoreAudio/MTCoreAudio.h>


@interface MTAudioDeviceBrowser : NSObject {
	id deviceNameMenu;
	id deviceUIDMenu;
	id deviceSourceMenu;
	id logicalFormatMenu;
	id physicalFormatMenu;
	id volumeSliderMatrix;
	id volumeLabelMatrix;
	id delegate;
	
	bool initted;
	bool hasMasterVolumeSlider;
	MTCoreAudioDevice * myDevice;
	MTCoreAudioDirection myDirection;
	NSMutableArray * deviceUIDs;
	NSMutableArray * logicalFormatArray, * physicalFormatArray;
}

- (id) delegate;
- (void) setDelegate:(id)theDelegate;

- (bool) hasMasterVolumeSlider;
- (void) setHasMasterVolumeSlider:(bool)flag;

- (MTCoreAudioDirection) direction;
- (void) setDirection:(MTCoreAudioDirection)theDirection;

- (MTCoreAudioDevice *) selectedDevice;
- (void) selectDevice:(MTCoreAudioDevice *)theDevice;

- (void) doDeviceMenu:(id)sender;
- (void) doDeviceSourceMenu:(id)sender;
- (void) doLogicalFormatMenu:(id)sender;
- (void) doPhysicalFormatMenu:(id)sender;
- (void) doVolumeSlider:(id)sender;

@end

@interface NSObject ( MTAudioDeviceBrowserDelegates )

- (void) MTAudioDeviceBrowser:(MTAudioDeviceBrowser *)theBrowser selectedDeviceDidChange:(MTCoreAudioDevice *)newDevice;
- (MTCoreAudioDevice *) MTAudioDeviceBrowser:(MTAudioDeviceBrowser *)theBrowser needsDefaultDeviceForDirection:(MTCoreAudioDirection)theDirection;
- (NSArray *) MTAudioDeviceBrowser:(MTAudioDeviceBrowser *)theBrowser needsDefaultSampleRatesForStream:(MTCoreAudioStream *)theStream forPrototypeStreamDescription:(MTCoreAudioStreamDescription *)theDescription;

@end