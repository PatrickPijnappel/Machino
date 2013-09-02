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

#import <QuartzCore/QuartzCore.h>
#import "MAController.h"
#import "MACodeController.h"
#import "Graph.h"
#import "Arduino.h"
#import "Utility.h"

const CGFloat kDefaultConsoleHeight = 160;
const CGFloat kMinConsoleHeight = 120;
const CGFloat kMinCodeViewWidth = 260;

typedef NS_ENUM(NSUInteger, MAConsoleMode) {
	MAOutputConsole = 0,
	MASerialConsole = 1
};

typedef NS_ENUM(NSInteger, MAState) {
	MAStateIdle,
	MAStateUploading,
	MAStateRunning
};

@interface MAController () <MAGraphViewDelegate, MACodeControllerDelegate, MAArduinoControllerDelegate, NSSplitViewDelegate>

@property (nonatomic) MAState state;
@property (nonatomic) CGRect consoleFrameBeforeCollapse;
@property (nonatomic) CGFloat sidebarDividerPositionBeforeCollapse;
// Other outlets
@property (nonatomic, weak) IBOutlet NSWindow *patternWindow;
// Console outlets
@property (nonatomic, weak) IBOutlet NSSegmentedControl *consoleSwitch;
@property (nonatomic, weak) IBOutlet NSButton *collapseConsoleToggleButton;
@property (nonatomic, weak) IBOutlet NSSplitView *mainSplitView;
@property (nonatomic, weak) IBOutlet NSSplitView *sidebarSplitView;
@property (nonatomic, weak) IBOutlet NSView *consoleContainer;
@property (nonatomic, weak) IBOutlet NSView *consoleContentView;
@property (nonatomic, weak) IBOutlet NSView *outputView;
@property (nonatomic, weak) IBOutlet NSView *serialView;
@property (nonatomic, assign) IBOutlet NSTextView *outputTextView;
@property (nonatomic, assign) IBOutlet NSTextView *serialTextView;

@end

@implementation MAController

- (void)setState:(MAState)state
{
	if (_state == state) return;
	// Notify
	[self willChangeValueForKey:@"isRunning"];
	[self willChangeValueForKey:@"isUploading"];
	// Set
	_state = state;
	// Notify
	[self didChangeValueForKey:@"isRunning"];
	[self didChangeValueForKey:@"isUploading"];
}

- (BOOL)isRunning
{
	return (self.state == MAStateRunning);
}

- (BOOL)isUploading
{
	return (self.state == MAStateUploading);
}

- (MAConsoleMode)currentConsoleMode
{
	return (MAConsoleMode)[self.consoleSwitch selectedSegment];
}

- (void)setCurrentConsoleMode:(MAConsoleMode)consoleMode
{
	[self.consoleSwitch setSelectedSegment:consoleMode];
	[self updateConsoleView:nil];
}

- (CGFloat)sidebarDividerPosition
{
	return [self.consoleContainer frame].origin.y - [self.sidebarSplitView dividerThickness];
}

- (CGFloat)consoleCollapsedHeight
{
	return [self.consoleContainer frame].size.height - [self.consoleContentView frame].size.height;
}

- (id)init
{
    self = [super init];
    if (self) {
        _arduino = [[MAArduinoController alloc] init];
		_arduino.delegate = self;
    }
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - User Interface

- (void)awakeFromNib
{
	[self updateConsoleView:nil];
	// Set insets
	[self.outputTextView setTextContainerInset:NSMakeSize(6, 10)];
	[self.serialTextView setTextContainerInset:NSMakeSize(6, 10)];
	// Make console view scroll horizontall instead of wrap
	[[self.outputTextView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
	[[self.outputTextView textContainer] setWidthTracksTextView:NO];
	[[self.serialTextView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
	[[self.serialTextView textContainer] setWidthTracksTextView:NO];
	// Set font
	NSFont *font = [NSFont fontWithName:@"Monaco" size:10];
	[self.outputTextView setFont:font];
	[self.serialTextView setFont:font];
	// Boards & serial ports
	[self loadBoards];
	[self updateSerialPortBox];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSerialPortBox) name:ORSSerialPortsWereConnectedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSerialPortBox) name:ORSSerialPortsWereDisconnectedNotification object:nil];
}

- (void)loadBoards
{
	// Load boards
	NSError *error = nil;
	[MABoard findAvailableBoardsWithError:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
		return;
	}
	// Update menu
	NSMenu *menu = [self.boardsBox menu];
	if (!menu) {
		menu = [[NSMenu alloc] init];
		[self.boardsBox setMenu:menu];
	}
	[self updateBoardsMenu:menu];
	// Check state
	if ([menu numberOfItems] > 0) {
		// Enable, select first enabled item
		[self.boardsBox setEnabled:YES];
		for (NSMenuItem *menuItem in [menu itemArray]) {
			if (![menuItem isEnabled]) continue;
			[self.boardsBox selectItem:menuItem];
			break;
		}
	} else {
		// Disable, and add placeholder
		[self.boardsBox setEnabled:NO];
		NSMenuItem *placeholder = [[NSMenuItem alloc] initWithTitle:@"Boards Not Found" action:NULL keyEquivalent:@""];
		[[self.boardsBox cell] setMenuItem:placeholder];
	}
}

- (void)updateSerialPortBox
{
	// Update menu
	NSMenu *menu = [self.serialPortBox menu];
	if (!menu) {
		menu = [[NSMenu alloc] init];
		[self.serialPortBox setMenu:menu];
	}
	[self updateSerialPortsMenu:menu];
	// Check state
	if ([menu numberOfItems] > 0) {
		// Enable, select something if we hadn't already
		[self.serialPortBox setEnabled:YES];
		if ([self.serialPortBox indexOfSelectedItem] == -1) {
			[self.serialPortBox selectItemAtIndex:0];
		}
	} else {
		// Disable, add placeholder
		[self.serialPortBox setEnabled:NO];
		NSMenuItem *placeholder = [[NSMenuItem alloc] initWithTitle:@"No Ports Available" action:NULL keyEquivalent:@""];
		[[self.serialPortBox cell] setMenuItem:placeholder];
	}
}

- (MABoard *)selectedBoard
{
	return [[self.boardsBox selectedItem] representedObject];
}

- (ORSSerialPort *)selectedSerialPort
{
	return [[self.serialPortBox selectedItem] representedObject];
}


#pragma mark - Graph View Delegate

- (void)graphDidChangeForGraphView:(MAGraphView *)graphView
{
	NSArray *states = [graphView getNodes];
	NSArray *transitions = [graphView getArrows];
	[self.codeController updateCodeForStates:states transitions:transitions];
	[self stop:self];
}

- (void)graphView:(MAGraphView *)graphView mouseHoverEventWithInfo:(NSDictionary *)info
{
	MAArrow *arrow = info[MAGraphMouseEventArrowKey];
	MACondition *condition = info[MAGraphMouseEventConditionKey];
	NSNumber *actionIndex = info[MAGraphMouseEventActionIndexKey];
	if (condition) {
		NSArray *items = @[ condition ];
		[self.graphView setHoveredItemsToItems:items];
		[self.codeController setHoveredItemsToItems:items];
	} else if (arrow && actionIndex) {
		NSUInteger index = [actionIndex unsignedIntegerValue];
		MAAction *action = arrow.actions[index];
		NSArray *items = @[ action ];
		[self.graphView setHoveredItemsToItems:items];
		[self.codeController setHoveredItemsToItems:items];
	} else {
		[self.graphView setHoveredItemsToItems:nil];
		[self.codeController setHoveredItemsToItems:nil];
	}
}

- (void)graphView:(MAGraphView *)graphView mouseClickEventWithInfo:(NSDictionary *)info
{
	MAArrow *arrow = info[MAGraphMouseEventArrowKey];
	MACondition *condition = info[MAGraphMouseEventConditionKey];
	NSNumber *actionIndex = info[MAGraphMouseEventActionIndexKey];
	if (condition) {
		[self.codeController scrollToItem:condition];
	} else if (arrow && actionIndex) {
		NSUInteger index = [actionIndex unsignedIntegerValue];
		MAAction *action = arrow.actions[index];
		[self.codeController scrollToItem:action];
	}
}

#pragma mark - Code Controller Delegate

- (void)codeWasEditedForCodeController:(MACodeController *)codeController
{
	[self stop:self];
}

- (void)codeController:(MACodeController *)codeController didSetHoveredItems:(NSArray *)hoveredItems
{
	[self.graphView setHoveredItemsToItems:hoveredItems];
}

#pragma mark - Arduino Controller Delegate

- (void)arduino:(MAArduinoController *)arduino didSendCurrentStateID:(UInt16)stateID
{
	if (!self.isRunning) return;
	MANode *state = [self.codeController objectForSymbolWithID:stateID];
	// Check for error
	if (!state) {
		NSLog(@"Invalid state id %i", stateID);
		return;
	}
	// Show
	[self.graphView makeNodeActive:state];
}

- (void)arduino:(MAArduinoController *)arduino willCheckConditionWithID:(UInt16)conditionID forTransitionWithID:(UInt16)transitionID
{
	if (!self.isRunning) return;
	MACondition *condition = [self.codeController objectForSymbolWithID:conditionID];
	MAArrow *transition = [self.codeController objectForSymbolWithID:transitionID];
	// Check for error
	if (!condition || !transition || condition != transition.condition) {
		NSLog(@"Invalid condition or transition id: %i/%i", conditionID, transitionID);
		return;
	}
	// Show
	[self.graphView makeConditionActive:condition arrow:transition];
	[self.codeController setExecutionItem:condition];
}

- (void)arduino:(MAArduinoController *)arduino willPerformActionAtIndex:(UInt16)index forTransitionWithID:(UInt16)transitionID
{
	if (!self.isRunning) return;
	MAArrow *transition = [self.codeController objectForSymbolWithID:transitionID];
	// Check for error
	if (!transition || index >= [transition.actions count]) {
		NSLog(@"Invalid transition id or index: %i/%i", transitionID, index);
		return;
	}
	[self.graphView makeActionAtIndexActive:index arrow:transition];
	[self.codeController setExecutionItem:transition.actions[index]];
}

- (void)arduino:(MAArduinoController *)arduino didReceiveUserSerialData:(NSData *)data
{
	if (!self.isRunning) return; // Otherwise sometimes partial non-user serial messages on shutdown get misinterpreted as user serial
	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	[string stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]]; // Almost certainly message start sequence leftovers
	if ([string length] > 0 && [[self.serialTextView textStorage] length] == 0 && [self currentConsoleMode] != MASerialConsole) {
		[self setCurrentConsoleMode:MASerialConsole];
	}
	[self appendString:string toTextView:self.serialTextView];
}

// Currently not handled:
- (void)arduinoDidStartIteration:(MAArduinoController *)arduino { }
- (void)arduinoDidEndIteration:(MAArduinoController *)arduino { }
- (void)arduino:(MAArduinoController *)arduino willPerformTransitionWithID:(UInt16)transitionID { }

#pragma mark - Split View Delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if (splitView == self.sidebarSplitView) {
		CGFloat maxPos = [self.sidebarSplitView maxPossiblePositionOfDividerAtIndex:0];
		CGFloat resultingConsoleHeight = maxPos - (proposedPosition + [splitView dividerThickness]);
		if (resultingConsoleHeight < kMinConsoleHeight/2) return maxPos - [self consoleCollapsedHeight];
		if (resultingConsoleHeight < kMinConsoleHeight) return maxPos - (kMinConsoleHeight + [splitView dividerThickness]);
	}
	if (splitView == self.mainSplitView) {
		CGFloat maxPos = [self.mainSplitView maxPossiblePositionOfDividerAtIndex:0];
		CGFloat resultingCodeViewWidth = maxPos - (proposedPosition + [splitView dividerThickness]);
		if (resultingCodeViewWidth < kMinCodeViewWidth/2) return maxPos;
		if (resultingCodeViewWidth < kMinCodeViewWidth) return maxPos - (kMinCodeViewWidth + [splitView dividerThickness]);
	}
	return proposedPosition;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	NSSplitView *splitView = [notification object];
	if (splitView == self.sidebarSplitView) {
		CGFloat dividerPosition = [self sidebarDividerPosition];
		CGFloat maxPos = [self.sidebarSplitView maxPossiblePositionOfDividerAtIndex:0] - [self consoleCollapsedHeight];
		if (dividerPosition >= maxPos) {
			self.sidebarDividerPositionBeforeCollapse = maxPos - kDefaultConsoleHeight;
			self.collapseConsoleToggleButton.state = NSOnState;
		} else {
			self.collapseConsoleToggleButton.state = NSOffState;
		}
	}
}

#pragma mark - Window Delegate

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame
{
	newFrame.origin.x = [window frame].origin.x;
	newFrame.size.width = [window frame].size.width;
	return newFrame;
}

#pragma mark - Commands

- (IBAction)run:(id)sender
{
	if (self.state == MAStateUploading) return;
	[self stop:sender];
	// Clear log
	[self.outputTextView setString:@""];
	[self.serialTextView setString:@""];
	// Get code
	NSString *code = [self.codeController codeWithLogging];
	// Set serial port & board
	self.arduino.board = [self selectedBoard];
	self.arduino.serialPort = [self selectedSerialPort];
	// Upload
	self.state = MAStateUploading;
	NSError *error = nil;
	[self.arduino uploadCode:code error:&error completion:^(BOOL success, NSString *output, NSString *errors) {
		// Print output
		NSMutableDictionary *attributes = [[self.outputTextView typingAttributes] mutableCopy];
		if ([output length] > 0) {
			attributes[NSForegroundColorAttributeName] = [NSColor blackColor];
			[self appendString:output toTextView:self.outputTextView withAttributes:attributes];
		}
		if ([errors length] > 0) {
			attributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedRed:.89 green:.298 blue:0 alpha:1];
			[self appendString:errors toTextView:self.outputTextView withAttributes:attributes];
		}
		// If succes, connect
		if (success) {
			BOOL connected = [self.arduino connect];
			if (!connected) {
				success = false;
			}
		}
		// Set state to running or stop
		if (success) {
			self.state = MAStateRunning;
		} else {
			[self stop:nil];
		}
	}];
	if (error) {
		self.state = MAStateIdle;
		[[NSAlert alertWithError:error] runModal];
		return;
	}
}

- (void)appendString:(NSString *)string toTextView:(NSTextView *)textView
{
	[self appendString:string toTextView:textView withAttributes:[textView typingAttributes]];
}

- (void)appendString:(NSString *)string toTextView:(NSTextView *)textView withAttributes:(NSDictionary *)attributes
{
	if (!string) return;
	// Get scroll position
	BOOL isScrollAtBottom = YES;
	NSScrollView *scrollView = (NSScrollView *)[[textView superview] superview];
	if ([scrollView isKindOfClass:[NSScrollView class]]) { // Just to check
		isScrollAtBottom = CGRectGetMaxY([[scrollView contentView] bounds]) == [textView frame].size.height;
	}
	// Set string
	NSAttributedString *stringAttributed = [[NSAttributedString alloc] initWithString:string attributes:attributes];
	[[textView textStorage] appendAttributedString:stringAttributed];
	// Update scroll position
	if (isScrollAtBottom) {
		CGRect bounds = [[scrollView contentView] bounds];
		bounds.origin.y = [textView frame].size.height-bounds.size.height;
		[[scrollView contentView] setBounds:bounds];
	}
}

- (IBAction)stop:(id)sender
{
	[self.arduino disconnect];
	[self.graphView clearActiveObjects];
	[self.codeController setExecutionItem:nil];
	self.state = MAStateIdle;
}

- (IBAction)clearConsole:(id)sender
{
	MAConsoleMode consoleMode = [self currentConsoleMode];
	if (consoleMode == MAOutputConsole) [self.outputTextView setString:@""];
	if (consoleMode == MASerialConsole) [self.serialTextView setString:@""];
}

- (IBAction)toggleCollapseConsole:(NSButton *)sender
{
	BOOL collapse = ([sender state] == NSOnState);
	if (collapse) {
		CGFloat oldDividerPosition = [self sidebarDividerPosition];
		CGFloat maxPos = [self.sidebarSplitView maxPossiblePositionOfDividerAtIndex:0] - [self consoleCollapsedHeight];
		[self.sidebarSplitView setPosition:maxPos ofDividerAtIndex:0];
		self.sidebarDividerPositionBeforeCollapse = oldDividerPosition; // Set position will modify this, so this needs to be after it
	} else {
		[self.sidebarSplitView setPosition:self.sidebarDividerPositionBeforeCollapse ofDividerAtIndex:0];
	}
}

- (IBAction)updateConsoleView:(id)sender
{
	MAConsoleMode consoleMode = [self currentConsoleMode];
	if (consoleMode == MAOutputConsole) {
		[self.serialView removeFromSuperview];
		[self.consoleContentView addSubview:self.outputView];
		[self.outputView setFrame:[self.consoleContentView bounds]];
		[self.outputView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	} else if (consoleMode == MASerialConsole) {
		[self.outputView removeFromSuperview];
		[self.consoleContentView addSubview:self.serialView];
		[self.serialView setFrame:[self.consoleContentView bounds]];
		[self.serialView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	}
}

- (void)updateBoardsMenu:(NSMenu *)menu
{
	MABoard *selectedBoard = [self selectedBoard];
	// Prepare menu
	[menu removeAllItems];
	[menu setAutoenablesItems:NO];
	// Add items
	for (MABoardArchitecture *architecture in [MABoard allArchitectures]) {
		// Add architecture name (with optional separator)
		if ([menu numberOfItems] > 0) [menu addItem:[NSMenuItem separatorItem]];
		NSMenuItem *architectureItem = [[NSMenuItem alloc] initWithTitle:architecture.name action:NULL keyEquivalent:@""];
		[architectureItem setEnabled:NO];
		[menu addItem:architectureItem];
		// Add boards
		NSArray *boards = [MABoard boardsForArchitecture:architecture];
		for (MABoard *board in boards) {
			NSMenuItem *boardItem = [[NSMenuItem alloc] initWithTitle:board.name action:NULL keyEquivalent:@""];
			[boardItem setRepresentedObject:board];
			if (board == selectedBoard) [boardItem setState:NSOnState];
			[menu addItem:boardItem];
		}
	}
	// Enable, select first enabled item
	for (NSMenuItem *menuItem in [menu itemArray]) {
		if (![menuItem isEnabled]) continue;
		[self.boardsBox selectItem:menuItem];
		break;
	}
}

- (void)updateSerialPortsMenu:(NSMenu *)menu
{
	ORSSerialPort *selectedSerialPort = [self selectedSerialPort];
	[menu removeAllItems];
	[menu setAutoenablesItems:NO];
	NSArray *ports = [ORSSerialPortManager sharedSerialPortManager].availablePorts;
	for (ORSSerialPort *port in ports) {
		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:port.name action:NULL keyEquivalent:@""];
		[menuItem setRepresentedObject:port];
		if (port == selectedSerialPort) [menuItem setState:NSOnState];
		[menu addItem:menuItem];
	}
}

@end
