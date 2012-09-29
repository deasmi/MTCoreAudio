//
//  main.m
//  AudioMonitor
//
//  Created by Michael Thornburgh on Thu Oct 03 2002.
//  Copyright (c) 2003 Michael Thornburgh. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MTCoreAudio/MTCoreAudio.h>

int main(int argc, const char *argv[])
{
	[MTCoreAudioDevice attachNotificationsToThisThread];
	return NSApplicationMain(argc, argv);
}
