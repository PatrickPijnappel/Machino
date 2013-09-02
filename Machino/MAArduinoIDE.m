//
//  MAArduinoIDE.m
//  Machino
//
//  Created by Patrick Pijnappel on 31/8/13.
//  Copyright (c) 2013 Patrick Pijnappel. All rights reserved.
//

#import "MAArduinoIDE.h"

static NSString * const kRequiredVersion = @"1.5.2";
static NSString * const kErrorNotInstalledFormat = @"No installation of the Arduino IDE was found. Machino requires the official Arduino IDE to be installed, version %@ or later (www.arduino.cc).";
static NSString * const kErrorVersionTooOldFormat = @"The installed Arduino IDE version (%@) is too old. Machino requires version %@ or later. Note that in some cases, old versions (even in trash) can prevent Machino from finding a newer version.";
static NSString * const kArduinoAppName = @"Arduino.app";

@implementation MAArduinoIDE

+ (NSString *)pathWithError:(NSError **)error
{
	// Try to find Arduino.app, searching 1) machino's folder 2) the applications folder 3) anywhere
	// We don't just rely on the latter because it is more likely to return old versions, possibly even in the thrash.
	NSString *machinoFolder = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
	NSString *arduinoAppPath = [machinoFolder stringByAppendingPathComponent:kArduinoAppName];
	if (![[NSFileManager defaultManager] fileExistsAtPath:arduinoAppPath]) {
		arduinoAppPath = [@"/Applications" stringByAppendingPathComponent:kArduinoAppName];
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:arduinoAppPath]) {
		arduinoAppPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:kArduinoAppName];
	}
	// Check it exists
	if (!arduinoAppPath) {
		NSString *message = [NSString stringWithFormat:kErrorNotInstalledFormat, kRequiredVersion];
		*error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey : message }];
		return nil;
	}
	// Check the version
	NSString *version = [[NSBundle bundleWithPath:arduinoAppPath] infoDictionary][@"CFBundleShortVersionString"];
	if ([version compare:kRequiredVersion options:NSNumericSearch] == NSOrderedAscending) {
		NSString *message = [NSString stringWithFormat:kErrorVersionTooOldFormat, version, kRequiredVersion];
		*error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey : message }];
		return nil;
	}
	// Return
	return arduinoAppPath;
}

@end
