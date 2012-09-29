//
//  MTDecibelTransformer.m
//  MTCoreAudio
//
//  Created by Michael Thornburgh on 10/27/04.
//  Copyright 2004 Michael Thornburgh. All rights reserved.
//

#import "MTDecibelTransformer.h"
#import <math.h>

static id toLinearTransformer = nil;
static id toDecibelTransformer = nil;

NSString * const MTDecibelToLinearTransformerName = @"MTDecibelToLinearTransformer";
NSString * const MTLinearToDecibelTransformerName = @"MTLinearToDecibelTransformer";

@implementation MTDecibelTransformer

+ (void) initialize
{
	if(!toLinearTransformer)
	{
		toLinearTransformer = [[[self class] alloc] initWithTransformMode:YES];
		toDecibelTransformer = [[[self class] alloc] initWithTransformMode:NO];
		[[self class] setValueTransformer:toLinearTransformer  forName:MTDecibelToLinearTransformerName];
		[[self class] setValueTransformer:toDecibelTransformer forName:MTLinearToDecibelTransformerName];
	}
}

- initWithTransformMode:(Boolean)toLinearMode
{
	self = [super init];
	if ( self )
	{
		toLinear = toLinearMode;
	}
	return self;
}

+ (Class) transformedValueClass
{ return [NSNumber class]; }

+ (BOOL) allowsReverseTransformation
{ return YES; }

- _transformValue:value mode:(Boolean)reverseMode
{
	double inputValue = 0.0;
	double outputValue;
	
	if ( ! value )
		return nil;
		
	if ( [value respondsToSelector:@selector(doubleValue)] )
		inputValue = [value doubleValue];
	else
		[NSException raise: NSInternalInconsistencyException format: @"Value (%@) does not respond to -doubleValue.", [value class]];
	
	if ( reverseMode ? toLinear : !toLinear )
	{
		if ( inputValue < 1e-100 )
			inputValue = 1e-100;
		outputValue = log10 ( inputValue ) * 20.0;
	}
	else
		outputValue = pow ( 10.0, inputValue / 20.0 );
	
	return [NSNumber numberWithDouble:outputValue];
}

- transformedValue:value
{
	return [self _transformValue:value mode:NO];
}

- reverseTransformedValue:value
{
	return [self _transformValue:value mode:YES];
}

@end
