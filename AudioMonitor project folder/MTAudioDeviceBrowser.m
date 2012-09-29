//
//  MTAudioDeviceBrowser.m
//  MTCoreAudio
//
//  Created by Michael Thornburgh on Fri Jun 14 2002.
//  Copyright (c) 2003 Michael Thornburgh. All rights reserved.
//

#import "MTAudioDeviceBrowser.h"

static NSArray * _defaultSampleRates = nil;

@implementation MTAudioDeviceBrowser

- (id) init
{
	[super init];
	initted = FALSE;
	deviceUIDs = [[NSMutableArray alloc] init];
	logicalFormatArray = [[NSMutableArray alloc] init];
	physicalFormatArray = [[NSMutableArray alloc] init];
	hasMasterVolumeSlider = FALSE;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioHardwareDeviceListDidChangeNotification:) name:MTCoreAudioHardwareDeviceListDidChangeNotification object:nil];
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MTCoreAudioHardwareDeviceListDidChangeNotification object:nil];
	[deviceUIDs release];
	[logicalFormatArray release];
	[physicalFormatArray release];
	[myDevice release];
	[super dealloc];
}


- (id) delegate
{
	return delegate;
}

- (void) setDelegate:(id)theDelegate
{
	delegate = theDelegate;
}

- (bool) hasMasterVolumeSlider
{
	return hasMasterVolumeSlider;
}

- (void) setHasMasterVolumeSlider:(bool)flag
{
	if ( ! initted )
		hasMasterVolumeSlider = flag;
}


- (MTCoreAudioDirection) direction
{
	return myDirection;
}

- (void) setDirection:(MTCoreAudioDirection)theDirection
{
	myDirection = theDirection;
	initted = TRUE;
	[self audioHardwareDeviceListDidChange];
}


- (MTCoreAudioDevice *) selectedDevice
{
	if ( ! initted )
		return nil;
	
	return [myDevice clone];
}

- (MTCoreAudioDevice *) systemDefaultDevice
{
	if ( myDirection == kMTCoreAudioDeviceRecordDirection )
	{
		return [MTCoreAudioDevice defaultInputDevice];
	}
	else
	{
		return [MTCoreAudioDevice defaultOutputDevice];
	}
}

- (void) selectDevice:(MTCoreAudioDevice *)theDevice
{
	NSString * deviceUID = [theDevice deviceUID];
	UInt32 deviceIndex;
	
	if (( theDevice == nil ) || ( deviceUID == nil ) || ( [theDevice channelsForDirection:myDirection] == 0 ))
	{
		theDevice = [self systemDefaultDevice];
		deviceUID = [theDevice deviceUID];
	}
	deviceIndex = [deviceUIDs indexOfObject:deviceUID];
	if ( deviceIndex == NSNotFound )
	{
		[deviceNameMenu setToolTip:nil];
		return; // shouldn't happen unless there's no device for myDirection
	}
	
	if ( ! [theDevice isEqual:myDevice] )
	{
		[myDevice release];
		myDevice = [[theDevice clone] retain];
		[myDevice setDelegate:self];
		
		[deviceSourceMenu removeAllItems];
		[deviceSourceMenu addItemsWithTitles:[myDevice dataSourcesForDirection:myDirection]];
		if ( [deviceSourceMenu numberOfItems] == 0 )
		{
			[deviceSourceMenu addItemWithTitle:( myDirection == kMTCoreAudioDeviceRecordDirection ? @"Audio Input" : @"Audio Output")];
			[deviceSourceMenu setEnabled:NO];
		}
		else
		{
			[deviceSourceMenu setEnabled:[myDevice canSetDataSourceForDirection:myDirection]];
		}
		[self audioDeviceSourceDidChange:myDevice forDirection:myDirection];
		[self audioDeviceStreamsListDidChange:myDevice];
		 
		if ( [delegate respondsToSelector:@selector(MTAudioDeviceBrowser:selectedDeviceDidChange:)] )
		{
			[delegate MTAudioDeviceBrowser:self selectedDeviceDidChange:[self selectedDevice]];
		}
	}
	
	[deviceUIDMenu selectItemWithTitle:deviceUID];
	[deviceNameMenu selectItemAtIndex:deviceIndex];
	[deviceNameMenu setToolTip:[NSString stringWithFormat:@"Device UID = %@", deviceUID]];
}


- (void) selectDeviceByUID:(NSString *)theUID
{
	[self selectDevice:[MTCoreAudioDevice deviceWithUID:theUID]];
}

- (void) doDeviceMenu:(id)sender
{
	[self selectDeviceByUID:[deviceUIDs objectAtIndex:[sender indexOfSelectedItem]]];
}

- (void) doDeviceSourceMenu:(id)sender
{
	[myDevice setDataSource:[sender titleOfSelectedItem] forDirection:myDirection];
}

- (void) _doFormatMenu:(id)theFormatMenu withFormatArray:(NSArray *)theFormatArray forSide:(MTCoreAudioStreamSide)theSide
{
	MTCoreAudioStream * theStream;
	UInt32 selectedItem;
	
	theStream = [[myDevice streamsForDirection:myDirection] objectAtIndex:0];
	selectedItem = [theFormatMenu indexOfSelectedItem];
	
	if ( ! [theStream setStreamDescription:[theFormatArray objectAtIndex:selectedItem] forSide:theSide] )
	{
		[theFormatMenu setAutoenablesItems:NO];
		[[theFormatMenu itemAtIndex:selectedItem] setEnabled:NO];
		[self audioStreamStreamDescriptionDidChange:theStream forSide:theSide];
	}
}

- (void) doLogicalFormatMenu:(id)sender
{
	[self _doFormatMenu:sender withFormatArray:logicalFormatArray forSide:kMTCoreAudioStreamLogicalSide];
}

- (void) doPhysicalFormatMenu:(id)sender
{
	[self _doFormatMenu:sender withFormatArray:physicalFormatArray forSide:kMTCoreAudioStreamPhysicalSide];
}

- (void) doVolumeSlider:(id)sender
{
	id selectedCell = [sender selectedCell];

	[myDevice setVolume:[selectedCell floatValue] forChannel:([selectedCell tag] + ( hasMasterVolumeSlider ? 0 : 1 )) forDirection:myDirection];
}

- (MTCoreAudioDevice *) defaultDevice
{
	MTCoreAudioDevice * rv = nil;
	
	if ( [delegate respondsToSelector:@selector(MTAudioDeviceBrowser:needsDefaultDeviceForDirection:)] )
	{
		rv = [delegate MTAudioDeviceBrowser:self needsDefaultDeviceForDirection:myDirection];
	}
	
	if (( rv == nil ) || ( [rv deviceUID] == nil ))
	{
		rv = [self systemDefaultDevice];
	}
	
	return rv;
}

- (void) audioHardwareDeviceListDidChange
{
	NSAutoreleasePool * pool;
	NSEnumerator * deviceEnumerator;
	UInt32 deviceIndex = 1;
	NSString * lastDeviceName = nil, * useDeviceName;
	NSString * deviceName, * deviceUID;
	MTCoreAudioDevice * theDevice;
	
	if ( ! initted )
		return;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	[deviceUIDs removeAllObjects];
	[deviceNameMenu removeAllItems];
	[deviceUIDMenu removeAllItems];
	
	deviceEnumerator = [[MTCoreAudioDevice allDevices] objectEnumerator];
	while ( theDevice = [deviceEnumerator nextObject] )
	{
		deviceUID = [theDevice deviceUID];
		deviceName= [theDevice deviceName];
		if (( deviceName == nil ) || ( deviceUID == nil ))
			continue;
		
		if ( [theDevice channelsForDirection:myDirection] > 0 )
		{
			[deviceUIDs addObject:deviceUID];
			[deviceUIDMenu addItemWithTitle:deviceUID];
			
			if ( [deviceName isEqual:lastDeviceName] )
			{
				++deviceIndex;
				useDeviceName = [NSString stringWithFormat:@"%@ #%d", deviceName, deviceIndex];
			}
			else
			{
				deviceIndex = 1;
				useDeviceName = deviceName;
			}
			
			[deviceNameMenu addItemWithTitle:useDeviceName];
			lastDeviceName = deviceName;
		}
	}
	
	if (( myDevice == nil ) || ( [myDevice deviceUID] == nil ))
	{
		[self selectDevice:[self defaultDevice]];
	}
	else
	{
		[self selectDevice:myDevice];
	}
	
	[pool release];
}

- (void) audioHardwareDeviceListDidChangeNotification:(NSNotification *)theNotification
{
	[self audioHardwareDeviceListDidChange];
}

- (void) audioDeviceSourceDidChange:(MTCoreAudioDevice *)theDevice forDirection:(MTCoreAudioDirection)theDirection
{
	NSString * theSource;
	
	if ( theDirection != myDirection )
	{
		return;
	}
	
	theSource = [myDevice dataSourceForDirection:myDirection];
	
	if ( theSource )
	{
		[deviceSourceMenu selectItemWithTitle:theSource];
	}
}

- (void) audioStreamStreamDescriptionDidChange:(MTCoreAudioStream *)theStream forSide:(MTCoreAudioStreamSide)theSide
{
	id theFormatMenu;
	NSMutableArray * theFormatArray;
	MTCoreAudioStreamDescription * theDescription;
	NSString * theDescriptionDescription;
	
	if ( theSide == kMTCoreAudioStreamLogicalSide )
	{
		theFormatMenu = logicalFormatMenu;
		theFormatArray = logicalFormatArray;
	}
	else
	{
		theFormatMenu = physicalFormatMenu;
		theFormatArray = physicalFormatArray;
	}
	
	if ( theFormatMenu == nil )
		return;
	
	if ( [theStream direction] != myDirection )
		return;
	
	if ( [theStream deviceStartingChannel] != 1 )
		return;

	theDescription = [theStream streamDescriptionForSide:theSide];
	if ( nil == theDescription )
	{
		NSLog ( @"-[MTAudioDeviceBrowser audioStreamStreamDescriptionDidChange:forSide:] streamDescription for stream is nil" );
		return;
	}
	
	theDescriptionDescription = [theDescription description];

	if ([theFormatMenu itemWithTitle:theDescriptionDescription] == nil)
	{
		[theFormatMenu addItemWithTitle:theDescriptionDescription];
		[theFormatArray addObject:theDescription];
	}
	
	[theFormatMenu selectItemWithTitle:theDescriptionDescription];
}

- (NSArray *) defaultSampleRatesForStream:(MTCoreAudioStream *)theStream forPrototypeDescription:(MTCoreAudioStreamDescription *)theStreamDescription
{
	if ( [delegate respondsToSelector:@selector(MTAudioDeviceBrowser:needsDefaultSampleRatesForStream:forPrototypeStreamDescription:)] )
		return [delegate MTAudioDeviceBrowser:self needsDefaultSampleRatesForStream:theStream forPrototypeStreamDescription:theStreamDescription];
	
	if ( _defaultSampleRates == nil )
		_defaultSampleRates = [[NSArray alloc] initWithObjects:@"8000.0", @"11025.0", @"12000.0", @"16000.0", @"22050.0", @"24000.0", @"32000.0", @"44100.0", @"48000.0",  @"64000.0", @"88200.0", @"96000.0", @"192000.0",  nil];
	
	return _defaultSampleRates;
}

- (void) setupFormatMenu:(id)theFormatMenu withFormatArray:(NSMutableArray *)theFormatArray forSide:(MTCoreAudioStreamSide)theSide
{
	NSAutoreleasePool * pool;
	MTCoreAudioStream * theStream;
	NSEnumerator * formatEnumerator, * sampleRateEnumerator;
	MTCoreAudioStreamDescription * theDescription, * matchedDescription;
	id theSampleRate;
	NSString * matchedDescriptionDescription;

	if ( nil == theFormatMenu )
		return;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	theStream = [[myDevice streamsForDirection:myDirection] objectAtIndex:0];
	
	[theFormatMenu removeAllItems];
	[theFormatArray removeAllObjects];
	
	formatEnumerator = [[theStream streamDescriptionsForSide:theSide] objectEnumerator];
	while ( theDescription = [formatEnumerator nextObject] )
	{
		if ( [theDescription sampleRate] == 0.0 )
		{
			sampleRateEnumerator = [[self defaultSampleRatesForStream:theStream forPrototypeDescription:theDescription] objectEnumerator];
			while ( theSampleRate = [sampleRateEnumerator nextObject] )
			{
				if ( [myDevice supportsNominalSampleRate:[theSampleRate doubleValue]] )
				{
					matchedDescription = [[[theDescription copy] autorelease] setSampleRate:[theSampleRate floatValue]];
					matchedDescriptionDescription = [matchedDescription description];
					if ( matchedDescription && ( [theFormatMenu indexOfItemWithTitle:matchedDescriptionDescription] == -1 ))
					{
						[theFormatMenu addItemWithTitle:matchedDescriptionDescription];
						[theFormatArray addObject:matchedDescription];
					}
				}
			}
		}
		else
		{
			[theFormatMenu addItemWithTitle:[theDescription description]];
			[theFormatArray addObject:theDescription];
		}
	}
	
	[self audioStreamStreamDescriptionDidChange:theStream forSide:theSide];
	
	[pool release];
}

- (void) audioDeviceStreamsListDidChange:(MTCoreAudioDevice *)theDevice
{
	UInt32 theChannel;
	int numVolumeCells, numRows = 0, numColumns = 0;
	
	[self setupFormatMenu:logicalFormatMenu withFormatArray:logicalFormatArray forSide:kMTCoreAudioStreamLogicalSide];
	[self setupFormatMenu:physicalFormatMenu withFormatArray:physicalFormatArray forSide:kMTCoreAudioStreamPhysicalSide];
	
	[volumeSliderMatrix getNumberOfRows:&numRows columns:&numColumns];
	numVolumeCells = numRows * numColumns;
	[volumeLabelMatrix getNumberOfRows:&numRows columns:&numColumns];
	numVolumeCells = MAX ( numVolumeCells, ( numRows * numColumns ));
	theChannel = ( hasMasterVolumeSlider ? 0 : 1 );
	for ( ; numVolumeCells; numVolumeCells-- )
		[self audioDeviceVolumeInfoDidChange:myDevice forChannel:theChannel++ forDirection:myDirection];
}

- (void) audioDeviceVolumeInfoDidChange:(MTCoreAudioDevice *)theDevice forChannel:(UInt32)theChannel forDirection:(MTCoreAudioDirection)theDirection
{
	UInt32 tag;
	MTCoreAudioVolumeInfo volumeInfo;
	id sliderCell, labelCell;
	
	if (( ! hasMasterVolumeSlider ) && ( theChannel == 0 ))
		return;
	
	if ( theDirection != myDirection )
		return;
	
	if ( volumeSliderMatrix == nil && volumeLabelMatrix == nil )
		return;
	
	tag = theChannel - ( hasMasterVolumeSlider ? 0 : 1 );
	volumeInfo = [theDevice volumeInfoForChannel:theChannel forDirection:theDirection];
	sliderCell = [volumeSliderMatrix cellWithTag:tag];
	labelCell = [volumeLabelMatrix cellWithTag:tag];
	if ( volumeInfo.hasVolume )
	{
		[sliderCell setEnabled:volumeInfo.canSetVolume];
		[sliderCell setFloatValue:volumeInfo.theVolume];
		[labelCell  setEnabled:volumeInfo.canSetVolume];
		[labelCell  setFloatValue:[theDevice volumeInDecibelsForVolume:volumeInfo.theVolume forChannel:theChannel forDirection:theDirection]];
	}
	else
	{
		[sliderCell setEnabled:FALSE];
		[sliderCell setFloatValue:0];
		[labelCell  setEnabled:FALSE];
		[labelCell  setFloatValue:0];
	}
}

@end
