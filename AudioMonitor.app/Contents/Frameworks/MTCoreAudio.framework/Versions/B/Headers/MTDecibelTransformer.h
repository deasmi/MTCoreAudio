//
//  MTDecibelTransformer.h
//  MTCoreAudio
//
//  Created by Michael Thornburgh on 10/27/04.
//  Copyright 2004 Michael Thornburgh. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString * const MTDecibelToLinearTransformerName;
extern NSString * const MTLinearToDecibelTransformerName;

@interface MTDecibelTransformer : NSValueTransformer
{
	Boolean toLinear;
}

- initWithTransformMode:(Boolean)toLinearMode;

@end
