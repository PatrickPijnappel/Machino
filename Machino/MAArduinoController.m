//
// Copyright (c) 2013, Patrick Pijnappel (contact@patrickpijnappel.com)
//
// Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted,
// provided that the above copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
// CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
// NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#import "MAArduinoController.h"
#import "MAArduinoIDE.h"
#import "MABoard.h"
#import "Utility.h"

#pragma mark - Constants

static const unsigned long kBaudRate = 9600;
static const int kMessageStartSequenceLength = 3;
static const Byte kMessageStartSequence[] = { 17, 31, 23 };
static const int kMessageHeaderLength = kMessageStartSequenceLength + 3;

typedef NS_ENUM(NSUInteger, MAMessageType) {
	MAMessageNone = 0,
	MAMessageIterationStart = 1,
	MAMessageIterationEnd = 2,
	MAMessageCurrentState = 3,
	MAMessageWillCheckCondition = 4,
	MAMessageWillPerformTransition = 5,
	MAMessageWillPerformAction = 6
};

#pragma mark - Private Class - MAMessageInfo

@interface MAMessageInfo : NSObject

@property (nonatomic) NSUInteger headerBytesRead;
@property (nonatomic) MAMessageType type;
@property (nonatomic) NSUInteger bodyLength;

@end

@implementation MAMessageInfo

@end

#pragma mark - MAArduinoController

@interface MAArduinoController () <ORSSerialPortDelegate, VDKQueueDelegate>

@property (nonatomic, strong, readonly) NSMutableData *receiveBuffer;
@property (nonatomic, strong) MAMessageInfo *pendingMessageInfo;
// IDE Launching
@property (nonatomic, strong, readonly) MATempDirectory *tempDirectory;
@property (nonatomic, strong, readonly) VDKQueue *fileMonitor;
@property (nonatomic, strong) void (^completionCallback)(BOOL success, NSString *output, NSString *errors);
@property (nonatomic, copy) NSString *lastOutput;
@property (nonatomic, copy) NSString *lastErrors;

@end

@implementation MAArduinoController

- (void)setSerialPort:(ORSSerialPort *)serialPort
{
	if (_serialPort == serialPort) return;
	// Clean up old
	[self disconnect];
	_serialPort.delegate = nil;
	// Set
	_serialPort = serialPort;
	// Set up new
	_serialPort.delegate = self;
}

- (id)init
{
    self = [super init];
    if (self) {
        _tempDirectory = [[MATempDirectory alloc] init];
		_fileMonitor = [[VDKQueue alloc] init];
		_fileMonitor.delegate = self;
		_receiveBuffer = [NSMutableData data];
    }
    return self;
}

- (void)dealloc
{
	if (_serialPort.open) [_serialPort close];
}

#pragma mark - Serial Port

- (BOOL)connect
{
	[self disconnect];
	self.serialPort.baudRate = @(kBaudRate);
	[self.serialPort open];
	return self.serialPort.open;
}

- (void)disconnect
{
	if (self.serialPort.open) [self.serialPort close];
	self.pendingMessageInfo = nil;
}

- (void)sendDataToArduino:(NSData *)data
{
	if (self.serialPort.open) [self.serialPort sendData:data];
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
	[self.receiveBuffer appendData:data];
	[self checkForMessages];
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
	self.serialPort = nil;
}

#pragma mark - Messages

- (void)checkForMessages
{
	MADataReader *reader = [MADataReader readerWithData:self.receiveBuffer];
	NSMutableData *userSerialData;
	while (reader.bytesLeft) {
		NSUInteger headerBytesRead = self.pendingMessageInfo.headerBytesRead;
		NSInteger headerBytesLeft = kMessageHeaderLength-headerBytesRead;
		if (headerBytesLeft <= 0) {
			// If we don't have the entire message yet, end
			if (reader.bytesLeft < self.pendingMessageInfo.bodyLength) break;
			// Read message body
			NSData *data = [reader readDataOfLength:self.pendingMessageInfo.bodyLength];
			[self readMessageWithInfo:self.pendingMessageInfo fromData:data];
			self.pendingMessageInfo = nil;
		} else if (headerBytesRead >= kMessageStartSequenceLength) {
			// If we don't have the entire header yet, end
			if (reader.bytesLeft < headerBytesLeft) break;
			// Read remaining message header
			self.pendingMessageInfo.type = (MAMessageType)[reader readUInt8];
			self.pendingMessageInfo.bodyLength = [reader readUInt16];
			self.pendingMessageInfo.headerBytesRead = kMessageHeaderLength;
		} else {
			// Check for start sequence
			Byte nextByte = [reader readUInt8];
			if (nextByte == kMessageStartSequence[headerBytesRead]) {
				if (!self.pendingMessageInfo) self.pendingMessageInfo = [[MAMessageInfo alloc] init];
				self.pendingMessageInfo.headerBytesRead++;
			} else {
				self.pendingMessageInfo = nil;
				// User (non-messaging) serial
				if (!userSerialData) userSerialData = [NSMutableData data];
				Byte bytes[] = { nextByte };
				[userSerialData appendBytes:bytes length:1];
			}
		}
	}
	// User serial data
	if ([userSerialData length] > 0) {
		[self.delegate arduino:self didReceiveUserSerialData:userSerialData];
	}
	// Delete consumed bytes
	NSUInteger bytesConsumed = reader.index;
	if (bytesConsumed > 0) {
		[self.receiveBuffer replaceBytesInRange:NSMakeRange(0, bytesConsumed) withBytes:NULL length:0];
	}
}

- (void)readMessageWithInfo:(MAMessageInfo *)messageInfo fromData:(NSData *)data
{
	switch (messageInfo.type) {
		case MAMessageIterationStart: [self readMessageIterationStartFromData:data]; break;
		case MAMessageIterationEnd: [self readMessageIterationEndFromData:data]; break;
		case MAMessageCurrentState: [self readMessageCurrentStateFromData:data]; break;
		case MAMessageWillCheckCondition: [self readMessageWillCheckConditionFromData:data]; break;
		case MAMessageWillPerformTransition: [self readMessageWillPerformTransition:data]; break;
		case MAMessageWillPerformAction: [self readMessageWillPerformActionFromData:data]; break;
		default: NSLog(@"Invalid message type: %li", messageInfo.type); break;
	}
}

- (void)readMessageIterationStartFromData:(NSData *)data
{
	[self.delegate arduinoDidStartIteration:self];
}

- (void)readMessageIterationEndFromData:(NSData *)data
{
	[self.delegate arduinoDidEndIteration:self];
}

- (void)readMessageCurrentStateFromData:(NSData *)data
{
	MADataReader *reader = [MADataReader readerWithData:data];
	UInt16 stateID = [reader readUInt16];
	[self.delegate arduino:self didSendCurrentStateID:stateID];
}

- (void)readMessageWillCheckConditionFromData:(NSData *)data
{
	MADataReader *reader = [MADataReader readerWithData:data];
	UInt16 transitionID = [reader readUInt16];
	UInt16 conditionID = [reader readUInt16];
	[self.delegate arduino:self willCheckConditionWithID:conditionID forTransitionWithID:transitionID];
}

- (void)readMessageWillPerformTransition:(NSData *)data
{
	MADataReader *reader = [MADataReader readerWithData:data];
	UInt16 transitionID = [reader readUInt16];
	[self.delegate arduino:self willPerformTransitionWithID:transitionID];
}

- (void)readMessageWillPerformActionFromData:(NSData *)data
{
	MADataReader *reader = [MADataReader readerWithData:data];
	UInt16 transitionID = [reader readUInt16];
	UInt16 actionIndex = [reader readUInt16];
	[self.delegate arduino:self willPerformActionAtIndex:actionIndex forTransitionWithID:transitionID];
}

#pragma mark - Upload

- (void)uploadCode:(NSString *)code error:(NSError **)error completion:(void(^)(BOOL success, NSString *output, NSString *errors))completion
{
	// Save sketch
	NSString *messagingCodePath = [[NSBundle mainBundle] pathForResource:@"Messaging" ofType:@"h"];
	NSString *sketchPath = [self saveSketchForCode:code additionalFiles:@[ messagingCodePath ]];
	if (!sketchPath) return;
	// Get Arduino IDE path
	NSString *arduinoAppPath = [MAArduinoIDE pathWithError:error];
	if (*error) return;
	NSURL *arduinoAppURL = [[NSURL alloc] initWithScheme:NSURLFileScheme host:@"" path:arduinoAppPath];
	if (!arduinoAppURL) return;
	// Build arguments
	NSMutableArray *arguments = [NSMutableArray array];
	if (self.board) [arguments addObjectsFromArray:@[ @"--board", [self.board fullIdentifier] ]];
	if (self.serialPort) [arguments addObjectsFromArray:@[ @"--port", self.serialPort.path ]];
	[arguments addObjectsFromArray:@[ @"--upload", sketchPath ]];
	// Launch
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSDictionary *configuration = @{ NSWorkspaceLaunchConfigurationArguments : arguments };
	NSWorkspaceLaunchOptions options = NSWorkspaceLaunchAndHide | NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchWithoutAddingToRecents
		| NSWorkspaceLaunchNewInstance | NSWorkspaceLaunchAsync;
	[[workspace notificationCenter] addObserver:self selector:@selector(workspaceDidLaunchApplication:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
	[[workspace notificationCenter] addObserver:self selector:@selector(workspaceDidTerminateApplication:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
	[workspace launchApplicationAtURL:arduinoAppURL options:options configuration:configuration error:nil];
	self.completionCallback = completion;
}

- (void)workspaceDidLaunchApplication:(NSNotification *)notification
{
	NSRunningApplication *app = [notification userInfo][NSWorkspaceApplicationKey];
	if ([app.localizedName isEqualTo:@"Arduino"]) {
		[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceDidLaunchApplicationNotification object:nil];
		[self checkForStandardStreamsOfApplication:app];
	}
}

- (void)workspaceDidTerminateApplication:(NSNotification *)notification
{
	NSRunningApplication *app = [notification userInfo][NSWorkspaceApplicationKey];
	if ([app.localizedName isEqualTo:@"Arduino"]) {
		// Remove observers
		[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self name:NSWorkspaceDidTerminateApplicationNotification object:nil];
		[self.fileMonitor removeAllPaths];
		// Invoke callback
		BOOL success = ([self.lastErrors length] == 0);
		self.completionCallback(success, self.lastOutput, self.lastErrors);
		// Clean-up
		self.completionCallback = nil;
		self.lastErrors = nil;
		self.lastOutput = nil;
	}
}

- (void)checkForStandardStreamsOfApplication:(NSRunningApplication *)app
{
	// Create task to launch lsof
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/sbin/lsof"];
	NSString *pidString = [NSString stringWithFormat:@"%i", app.processIdentifier];
	[task setArguments:@[ @"-p", pidString ]];
	// Add pipe to get stdout & stderr
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
	[task launch];
	[task waitUntilExit];

	NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
	NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\S*std...\\.txt)" options:0 error:nil];
	NSArray *matches = [regex matchesInString:output options:0 range:NSMakeRange(0, [output length])];
	if ([matches count] > 0) {
		for (NSTextCheckingResult *match in matches) {
			NSRange range = [match rangeAtIndex:1];
			NSString *path = [output substringWithRange:range];
			[self.fileMonitor addPath:path];
		}
	} else {
		// Try again a little later
		[NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(checkForStandardStreamsWithTimer:) userInfo:app repeats:NO];
	}
}

- (void)checkForStandardStreamsWithTimer:(NSTimer *)timer
{
	NSRunningApplication *app = [timer userInfo];
	[self checkForStandardStreamsOfApplication:app];
}

- (void)VDKQueue:(VDKQueue *)queue receivedNotification:(NSString *)noteName forPath:(NSString *)fpath
{
	if (noteName == VDKQueueWriteNotification) {
		BOOL isError = ([fpath rangeOfString:@"stderr"].location != NSNotFound);
		NSString *contents = [NSString stringWithContentsOfFile:fpath encoding:NSUTF8StringEncoding error:nil];
		if (isError) {
			self.lastErrors = contents;
		} else {
			self.lastOutput = contents;
		}
	}
}

- (NSString *)saveSketchForCode:(NSString *)code additionalFiles:(NSArray *)additionalFilePaths
{
	if (!self.tempDirectory.path) return nil;
	// Prepare
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *sketchName = @"Sketch";
	// Create sketch directory
	NSString *directoryPath = [self.tempDirectory.path stringByAppendingPathComponent:sketchName];
	BOOL directoryCreated = [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
	if (!directoryCreated) return nil;
	// Create .ino file
	NSString *inoName = [sketchName stringByAppendingPathExtension:@"ino"];
	NSString *inoPath = [directoryPath stringByAppendingPathComponent:inoName];
	NSData *codeAsData = [code dataUsingEncoding:NSUTF8StringEncoding];
	BOOL inoFileCreated = [fileManager createFileAtPath:inoPath contents:codeAsData attributes:nil];
	if (!inoFileCreated) return nil;
	// Add additional files
	for (NSString *path in additionalFilePaths) {
		NSString *targetPath = [directoryPath stringByAppendingPathComponent:[path lastPathComponent]];
		// Copy, delete if already exists
		if ([fileManager fileExistsAtPath:targetPath]) [fileManager removeItemAtPath:targetPath error:nil];
		BOOL fileCopied = [fileManager copyItemAtPath:path toPath:targetPath error:nil];
		if (!fileCopied) return nil;
	}
	// Return
	return inoPath;
}

@end
