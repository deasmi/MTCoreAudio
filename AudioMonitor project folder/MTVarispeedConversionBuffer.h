//
//  MTVarispeedConversionBuffer.h
//  AudioMonitor
//
//  Created by Michael Thornburgh on Thu Apr 22 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "MTConversionBufferProto.h"
#import <AudioUnit/AudioUnit.h>


@interface MTVarispeedConversionBuffer : NSObject <MTConversionBuffer> {
	MTAudioBuffer * audioBuffer;
	unsigned audioBufferFrameCount;
	AudioBufferList * outputBufferList;
	unsigned outputBufferListFrameCount;
	Float32 * gainArray;
	id delegate;
	AudioUnit converterUnit;
	AudioUnit varispeedUnit;
	AudioTimeStamp readTimeStamp;
	Boolean readerCanWait;
	Boolean shouldProvideSilence;
	unsigned silenceCounter;
	double conversionFactor;
}

@end