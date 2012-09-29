//
//  MTConversionBuffer.h
//  AudioMonitor
//
//  Created by Michael Thornburgh on Wed Jul 09 2003.
//  Copyright (c) 2004 Michael Thornburgh. All rights reserved.
//

#import "MTConversionBufferProto.h"
#import <AudioToolbox/AudioToolbox.h>

@interface MTConversionBuffer : NSObject <MTConversionBuffer> {
	AudioConverterRef converter;
	AudioBufferList * conversionBufferList;
	unsigned conversionBufferListFrameCount;
	AudioBufferList * outputBufferList;
	unsigned outputBufferListFrameCount;
	MTAudioBuffer * audioBuffer;
	unsigned audioBufferFrameCount;
	Float32 * gainArray;
	id delegate;
	Boolean shouldProvideSilence;
	double conversionFactor;
}

@end