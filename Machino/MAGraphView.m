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
#import "Graph.h"
#import "Utility.h"

#pragma mark - Constants & Enums

NSString * const MAGraphMouseEventNodeKey = @"node";
NSString * const MAGraphMouseEventArrowKey = @"arrow";
NSString * const MAGraphMouseEventConditionKey = @"condition";
NSString * const MAGraphMouseEventActionIndexKey = @"actionIndex";

static const float kNodeRadius = 50;
static const float kArrowBallRadius = 5;
static const float MAArrowHeadAngle = M_PI/6;
static const float MAArrowHeadLength = 15;

static const float kNodeEdgeHitDistance = 10;
static const float kArrowEndHitDistance = 15;
static const float kArrowTextHitDistance = 10;

static const float kNodeFontSize = 14;
static const float kArrowFontSize = 12;
static NSString * const kActionSeparatorString = @",";
static NSString * const kActionSeparatorDisplayString = @", ";

typedef NS_ENUM(NSUInteger, MAState) {
	MAStateIdle,
	MAStateDragNodes,
	MAStateDragSelectionBox,
	MAStateDragCancelled,
	MAStateDragNewArrow,
	MAStateDragArrowEnd,
	MAStateEditNodeName,
	MAStateEditArrowCondition,
	MAStateEditArrowActions
};

typedef NS_OPTIONS(NSUInteger, MAHitTests) {
	MAHitTestNone = 0,
	MAHitTestNode = 1 << 0,
	MAHitTestNodeEdge = 1 << 1,
	MAHitTestAllNode = MAHitTestNode | MAHitTestNodeEdge,
	MAHitTestArrowTail = 1 << 2,
	MAHitTestArrowHead = 1 << 3,
	MAHitTestArrowCondition = 1 << 4,
	MAHitTestArrowActions = 1 << 5,
	MAHitTestArrowText = 1 << 6,
	MAHitTestAllArrow = MAHitTestArrowTail | MAHitTestArrowHead | MAHitTestArrowCondition | MAHitTestArrowActions | MAHitTestArrowText,
	MAHitTestAll = ~MAHitTestNone
};

#pragma mark - Private Interface

@interface MAGraphView () <NSTextFieldDelegate>

// Outlets
@property (nonatomic, weak) IBOutlet NSTextField *startHintLabel;
@property (nonatomic, weak) IBOutlet NSPopover *transitionPopover;
// State
@property (nonatomic) MAState state;
// General
@property (nonatomic, strong, readonly) NSMutableArray *nodes;
@property (nonatomic, strong, readonly) NSMutableArray *arrows;
@property (nonatomic, strong, readonly) NSMutableArray *selection;
// Layer
@property (nonatomic, strong) CALayer *selectionBoxLayer;
@property (nonatomic, strong) CALayer *arrowHintLayer;
@property (nonatomic, strong) CALayer *nodesLayer;
@property (nonatomic, strong) CALayer *arrowsLayer;
// Mouse down
@property (nonatomic, strong) NSTrackingArea *trackingArea;
@property (nonatomic, weak) MANode *mouseDownNode;
@property (nonatomic, weak) MAArrow *mouseDownArrow;
@property (nonatomic) CGPoint mouseDownPoint;
@property (nonatomic) BOOL mouseDownCommandPressed;
@property (nonatomic) MAHitTests mouseDownPassedHitTest;
// Editing node texts, conditions & actions
@property (nonatomic, weak) id editedObject;
@property (nonatomic, weak) NSTextField *editingTextField;
// Arrows
@property (nonatomic, strong) MAArrow *draggedArrow;
@property (nonatomic) MAArrowEnd draggedArrowEnd;
// Stored old vars
@property (nonatomic, strong, readonly) NSMutableArray *selectionBeforeBoxSelection;
@property (nonatomic, strong) NSDictionary *nodePositionsBeforeDrag;
@property (nonatomic, weak) MANode *arrowEndNodeBeforeDrag;
@property (nonatomic) CGFloat arrowEndAngleBeforeDrag;
// Colors
@property (nonatomic, strong) NSColor *activeObjectFillColor;
@property (nonatomic, strong) NSColor *activeObjectStrokeColor;
@property (nonatomic, strong) NSColor *hoveredObjectStrokeColor;
@property (nonatomic, strong) NSColor *selectedObjectFillColor;
@property (nonatomic, strong) NSColor *selectedObjectStrokeColor;
// Active & Hovered
@property (nonatomic, strong, readonly) NSMutableArray *activatedNodesMutable;
@property (nonatomic, weak, readwrite) MANode *activeNode;
@property (nonatomic, weak, readwrite) MAArrow *activeArrow;
@property (nonatomic, weak, readwrite) MACondition *activeCondition;
@property (nonatomic, readwrite) NSUInteger activeActionIndex;
@property (nonatomic, strong, readonly) NSMutableArray *hoveredItems;

@end

#pragma mark - Implementation

@implementation MAGraphView

- (NSArray *)getNodes
{
	return [self.nodes copy];
}

- (NSArray *)getArrows
{
	return [self.arrows copy];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (NSFont *)defaultNodeFont
{
	return [NSFont userFontOfSize:kNodeFontSize];
}

- (NSFont *)defaultArrowFont
{
	return [NSFont userFontOfSize:kArrowFontSize];
}

- (NSArray *)activedNodes
{
	return [self.activatedNodesMutable copy];
}

#pragma mark - Initialization

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		_nodes = [NSMutableArray array];
		_arrows = [NSMutableArray array];
		_selection = [NSMutableArray array];
		_selectionBeforeBoxSelection = [NSMutableArray array];
		_activeObjectFillColor = [NSColor yellowColor];
		_activeObjectStrokeColor = [NSColor orangeColor];
		_hoveredObjectStrokeColor = [NSColor colorWithCalibratedRed:0 green:.5 blue:1 alpha:1];
		_selectedObjectFillColor = [NSColor selectedControlColor];
		_selectedObjectStrokeColor = [NSColor alternateSelectedControlColor];
		_activatedNodesMutable = [NSMutableArray array];
		_hoveredItems = [NSMutableArray array];
		[self initialize];
    }    
    return self;
}

- (void)initialize
{
    [self setupLayers];
	[NSEvent setMouseCoalescingEnabled:NO];
	[self updateTrackingAreas];
}

- (void)setupLayers
{
	// Enable managing our own layers
	[self setLayer:[CALayer layer]];
	[self setWantsLayer:YES];
	// Create selection layer
    CALayer *selectionBoxLayer = [CALayer layer];
	selectionBoxLayer.backgroundColor = [[[NSColor grayColor] colorWithAlphaComponent:.25] CGColor];
	selectionBoxLayer.borderWidth = 1;
	selectionBoxLayer.borderColor = [[NSColor grayColor] CGColor];
	selectionBoxLayer.anchorPoint = CGPointMake(0, 0);
	selectionBoxLayer.hidden = YES;
	self.selectionBoxLayer = selectionBoxLayer;
	// Create new arrow drag hint layer
	CALayer *dragHintLayer = [CALayer layer];
	dragHintLayer.bounds = CGRectMake(0, 0, kArrowBallRadius*2, kArrowBallRadius*2);
	dragHintLayer.backgroundColor = [[NSColor blackColor] CGColor];
	dragHintLayer.cornerRadius = kArrowBallRadius;
	dragHintLayer.hidden = YES;
	self.arrowHintLayer = dragHintLayer;
	// Create nodes & arrows layer
	self.nodesLayer = [CALayer layer];
	self.arrowsLayer = [CALayer layer];
	// Add layers (lower ones first)
	[[self layer] addSublayer:self.arrowsLayer];
	[[self layer] addSublayer:self.nodesLayer];
	[[self layer] addSublayer:self.arrowHintLayer];
	[[self layer] addSublayer:self.selectionBoxLayer];
}

- (void)setNodes:(NSMutableArray *)nodes arrows:(NSMutableArray *)arrows
{
	// Clean
	for (MANode *node in [self.nodes copy]) {
		[self deleteNode:node];
	}
	for (MAArrow *arrow in [self.arrows copy]) {
		[self deleteArrow:arrow];
	}
	[self.selection removeAllObjects];
	[self clearActiveObjects];
	self.state = MAStateIdle;
	// Set
	_nodes = nodes;
	_arrows = arrows;
	// Update
	for (MANode *node in nodes) {
		[self createLayersForNode:node];
		[self addNode:node];
	}
	for (MAArrow *arrow in arrows) {
		[self createLayersForArrow:arrow];
		[self addArrow:arrow];
		[self updateArrow:arrow];
	}
}

#pragma mark - View Updates

- (void)viewDidChangeBackingProperties
{
	CGFloat scale = [[self window] backingScaleFactor];
	for (MANode *node in self.nodes) {
		node.textLayer.contentsScale = scale;
	}
	for (MAArrow *arrow in self.arrows) {
		arrow.conditionLayer.contentsScale = scale;
		arrow.slashLayer.contentsScale = scale;
		arrow.actionsLayer.contentsScale = scale;
	}
}

#pragma mark - Active & Hovered Objects

- (void)clearActiveObjects
{
	[self.activatedNodesMutable removeAllObjects];
	self.activeNode = nil;
	self.activeArrow = nil;
	self.activeCondition = nil;
	self.activeActionIndex = NSNotFound;
	[self updateAllColors];
}

- (void)makeNodeActive:(MANode *)node
{
	[self makeNodeActive:node updateColors:YES];
}

- (void)makeNodeActive:(MANode *)node updateColors:(BOOL)updateColors
{
	// Set current
	self.activeNode = node;
	if (![self.activatedNodesMutable containsObject:node]) {
		[self.activatedNodesMutable addObject:node];
	}
	// Deactive conflicting nodes
	NSArray *connectedNodes = [node findConnectedNodes];
	for (MANode *otherNode in [self.activatedNodesMutable copy]) {
		if (otherNode == node) continue;
		if ([connectedNodes containsObject:otherNode]) {
			[self.activatedNodesMutable removeObject:otherNode];
		}
	}
	// Update rest
	self.activeArrow = nil;
	self.activeActionIndex = NSNotFound;
	if (updateColors) [self updateAllColors];
}

- (void)makeConditionActive:(MACondition *)condition arrow:(MAArrow *)arrow
{
	[self makeNodeActive:arrow.sourceNode updateColors:NO];
	self.activeArrow = nil;
	self.activeCondition = condition;
	self.activeActionIndex = NSNotFound;
	[self updateAllColors];
}

- (void)makeActionAtIndexActive:(NSUInteger)index arrow:(MAArrow *)arrow
{
	[self makeNodeActive:arrow.sourceNode updateColors:NO];
	self.activeArrow = arrow;
	self.activeCondition = nil;
	self.activeActionIndex = index;
	[self updateAllColors];
}

- (void)updateAllColors
{
	[self updateNodeColors];
	[self updateArrowColors];
}

- (void)setHoveredItemsToItems:(NSArray *)items
{
	if ([items isEqual:self.hoveredItems]) return;
	if ([items count] == 0 && [self.hoveredItems count] == 0) return;
	[self.hoveredItems removeAllObjects];
	if (items) [self.hoveredItems setArray:items];
	[self updateAllColors];
}

#pragma mark - Menus

- (NSMenu *)menuForEvent:(NSEvent *)event
{
	CGPoint p = NSPointToCGPoint([self convertPoint:[event locationInWindow] fromView:nil]);
	// Do hit tests
	MAHitTests passedTests;
	id hitObject = [self performHitTests:MAHitTestAll onPoint:p passedTest:&passedTests];
	// Get appropriate menu
	if (passedTests == MAHitTestNode) {
		MANode *node = hitObject;
		return [self menuForNode:node];
	} else {
		return [self generalMenuForPoint:p];
	}
}

- (NSMenu *)menuForNode:(MANode *)node
{
	NSMenu *menu = [[NSMenu alloc] init];
	[menu setAutoenablesItems:NO];
	// Make initial state
	NSMenuItem *makeInitialStateItem = [[NSMenuItem alloc] initWithTitle:@"Make Initial State" action:@selector(makeInitialStateFromMenuItem:) keyEquivalent:@""];
	[makeInitialStateItem setRepresentedObject:node];
	[makeInitialStateItem setEnabled:!node.isInitialState];
	[menu addItem:makeInitialStateItem];
	// Seperator
	[menu addItem:[NSMenuItem separatorItem]];
	// Rename
	NSMenuItem *renameItem = [[NSMenuItem alloc] initWithTitle:@"Rename" action:@selector(renameNodeFromMenuItem:) keyEquivalent:@""];
	[renameItem setRepresentedObject:node];
	[menu addItem:renameItem];
	// Delete
	NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"Delete" action:@selector(deleteNodeFromMenuItem:) keyEquivalent:@""];
	[deleteItem setRepresentedObject:node];
	[menu addItem:deleteItem];
	// Return
	return menu;
}

- (NSMenu *)generalMenuForPoint:(CGPoint)p
{
	NSMenu *menu = [[NSMenu alloc] init];
	// Add state
	NSMenuItem *newNodeItem = [[NSMenuItem alloc] initWithTitle:@"New State" action:@selector(newNodeFromMenuItem:) keyEquivalent:@""];
	NSValue *pointObject = [NSValue valueWithPoint:NSPointFromCGPoint(p)];
	[newNodeItem setRepresentedObject:pointObject];
	[menu addItem:newNodeItem];
	// Return
	return menu;
}

#pragma mark Menu Actions

- (void)makeInitialStateFromMenuItem:(NSMenuItem *)menuItem
{
	MANode *node = [menuItem representedObject];
	[self performActionSetIsInitialState:YES forNode:node];
}

- (void)renameNodeFromMenuItem:(NSMenuItem *)menuItem
{
	MANode *node = [menuItem representedObject];
	[self editNameForNode:node];
}

- (void)deleteNodeFromMenuItem:(NSMenuItem *)menuItem
{
	[self performActionDeleteNodes:self.selection clearSelection:NO];
}

- (void)newNodeFromMenuItem:(NSMenuItem *)menuItem
{
	CGPoint p = NSPointToCGPoint([[menuItem representedObject] pointValue]);
	[self performActionAddNewNodeAtPoint:p];
}

#pragma mark - Mouse Events

- (void)mouseMoved:(NSEvent *)event
{
	CGPoint p = NSPointToCGPoint([self convertPoint:[event locationInWindow] fromView:nil]);
	// Hit-test
	MAHitTests tests = MAHitTestArrowTail | MAHitTestArrowHead | MAHitTestNodeEdge | MAHitTestArrowText;
	MAHitTests passedTest;
	id hitObject = [self performHitTests:tests onPoint:p passedTest:&passedTest];
	// Arrow hint
	BOOL showArrowEndHint = NO;
	CGPoint arrowEndHintPosition;
	if (self.state == MAStateIdle) {
		if (passedTest == MAHitTestArrowTail || passedTest == MAHitTestArrowHead) {
			MAArrow *arrow = hitObject;
			arrowEndHintPosition = (passedTest == MAHitTestArrowHead) ? arrow.targetPoint : arrow.sourcePoint;
			showArrowEndHint = YES;
		} else if (passedTest == MAHitTestNodeEdge) {
			MANode *node = hitObject;
			arrowEndHintPosition = [self arrowPointOnNode:node towardsPoint:p];
			showArrowEndHint = YES;
		}
	}
	if (self.arrowHintLayer.hidden != !showArrowEndHint) {
		[self doWithoutAnimation:^{ self.arrowHintLayer.hidden = !showArrowEndHint; }];
	}
	if (showArrowEndHint) {
		[self doWithoutAnimation:^{ self.arrowHintLayer.position = arrowEndHintPosition; }];
	}
	for (MAArrow *arrow in self.arrows) {
		[self updateTextLayerVisibilityForArrow:arrow];
	}
	// Notify delegate
	if ([self.delegate respondsToSelector:@selector(graphView:mouseHoverEventWithInfo:)]) {
		NSDictionary *info = [self mouseEventInfoForEvent:event];
		[self.delegate graphView:self mouseHoverEventWithInfo:info];
	}
}

- (NSDictionary *)mouseEventInfoForEvent:(NSEvent *)event
{
	CGPoint p = NSPointToCGPoint([self convertPoint:[event locationInWindow] fromView:nil]);
	// Hit-test
	MAHitTests tests = MAHitTestNode | MAHitTestArrowCondition | MAHitTestArrowActions;
	MAHitTests passedTest;
	id hitObject = [self performHitTests:tests onPoint:p passedTest:&passedTest];
	// Create info
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	if ([hitObject isKindOfClass:[MANode class]]) {
		info[MAGraphMouseEventNodeKey] = hitObject;
	}
	if ([hitObject isKindOfClass:[MAArrow class]]) {
		MAArrow *arrow = hitObject;
		info[MAGraphMouseEventArrowKey] = arrow;
		if (passedTest == MAHitTestArrowCondition && arrow.condition && !arrow.conditionLayer.hidden) {
			info[MAGraphMouseEventConditionKey] = arrow.condition;
		} else if (passedTest == MAHitTestArrowActions && [arrow.actions count] > 0 && !arrow.actionsLayer.hidden) {
			info[MAGraphMouseEventArrowKey] = arrow;
			NSUInteger index = [self actionIndexAtPoint:p forArrow:arrow];
			if (index != NSNotFound) info[MAGraphMouseEventActionIndexKey] = @(index);
		}
	}
	return info;
}

- (void)mouseDown:(NSEvent *)event
{
	NSPoint p = NSPointToCGPoint([self convertPoint:[event locationInWindow] fromView:nil]);
	// Hit-test
	MAHitTests passedTest;
	id hitObject = [self performHitTests:MAHitTestAll onPoint:p passedTest:&passedTest];
	// Update selection
	BOOL commandPressed = (([event modifierFlags] & NSCommandKeyMask) == NSCommandKeyMask);
	MANode *nodeForSelection = (passedTest == MAHitTestNode) ? hitObject : nil;
	[self updateSelectionForClickOnNode:nodeForSelection withCommandPressed:commandPressed];
	// Track mouse down properties for dragging
	self.mouseDownPoint = p;
	self.mouseDownCommandPressed = commandPressed;
	self.mouseDownNode = [hitObject isKindOfClass:[MANode class]] ? hitObject : nil;
	self.mouseDownArrow = [hitObject isKindOfClass:[MAArrow class]] ? hitObject : nil;
	self.mouseDownPassedHitTest = passedTest;
}

- (void)rightMouseDown:(NSEvent *)event
{
	NSPoint p = NSPointToCGPoint([self convertPoint:[event locationInWindow] fromView:nil]);
	// Hit-test
	MAHitTests passedTest;
	id hitObject = [self performHitTests:MAHitTestAll onPoint:p passedTest:&passedTest];
	// Update selection
	BOOL commandPressed = ([event modifierFlags] & NSCommandKeyMask) == NSCommandKeyMask;
	MANode *nodeForSelection = (passedTest == MAHitTestNode) ? hitObject : nil;
	[self updateSelectionForClickOnNode:nodeForSelection withCommandPressed:commandPressed];
	[super rightMouseDown:event];
}

- (void)mouseDragged:(NSEvent *)event
{
	[self mouseMoved:event];
	NSPoint p = NSPointToCGPoint([self convertPoint:[event locationInWindow] fromView:nil]);
	// Drag start
	if (self.state == MAStateIdle) {
		MAHitTests hitType = self.mouseDownPassedHitTest;
		if (hitType == MAHitTestNode) {
			[self startDragItems];
		} else if (hitType == MAHitTestNodeEdge) {
			[self startDragNewArrow]; // Change to drag both old and new arrows
		} else if (hitType == MAHitTestArrowTail || hitType == MAHitTestArrowHead) {
			self.draggedArrowEnd = (hitType == MAHitTestArrowTail) ? MAArrowTail : MAArrowHead;
			[self startDragArrowEnd];
		} else {
			[self startDragSelectionBox];
		}
	}
	// Update drag
	if (self.state == MAStateDragNodes) {
		[self updateDragNodesToPoint:p];
	} else if (self.state == MAStateDragNewArrow) {
		[self updateDragNewArrowToPoint:p];
	} else if (self.state == MAStateDragArrowEnd) {
		[self updateDragArrowEndToPoint:p];
	} else if (self.state == MAStateDragSelectionBox) {
		[self updateDragSelectionBoxToPoint:p];
	}
}

- (void)mouseUp:(NSEvent *)event
{
	NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
	// Double click
	if (event.clickCount == 2) {
		// Hit test
		MAHitTests passedTest;
		id hitObject = [self performHitTests:MAHitTestAll onPoint:p passedTest:&passedTest];
		// Determine what to do
		if (passedTest == MAHitTestNode) {
			MANode *node = hitObject;
			[self editNameForNode:node];
		} else if (passedTest == MAHitTestArrowCondition) {
			MAArrow *arrow = hitObject;
			[self editConditionForArrow:arrow];
		} else if (passedTest == MAHitTestArrowActions) {
			MAArrow *arrow = hitObject;
			[self editActionsForArrow:arrow];
		} else if (passedTest == MAHitTestNone) {
			MANode *newNode = [self performActionAddNewNodeAtPoint:p];
			[self editNameForNode:newNode];
		}
	}
	// End drag
	if (self.state == MAStateDragNodes) {
		[self endDragNodes];
	} else if (self.state == MAStateDragNewArrow) {
		[self endDragNewArrow];
	} else if (self.state == MAStateDragArrowEnd) {
		[self endDragArrowEnd];
	} else if (self.state == MAStateDragSelectionBox) {
		[self endDragSelectionBox];
	} else if (self.state == MAStateDragCancelled) {
		self.state = MAStateIdle;
	}
	// Notify delegate
	if ([self.delegate respondsToSelector:@selector(graphView:mouseClickEventWithInfo:)]) {
		NSDictionary *eventInfo = [self mouseEventInfoForEvent:event];
		[self.delegate graphView:self mouseClickEventWithInfo:eventInfo];
	}
}

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	// Remove old tracking areas
	if (self.trackingArea) [self removeTrackingArea:self.trackingArea];
	// Add new tracking area
	NSTrackingAreaOptions options = NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect;
	self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil];
	[self addTrackingArea:self.trackingArea];
}

#pragma mark - Action Messages

- (void)delete:(id)sender
{
	[self performActionDeleteNodes:self.selection clearSelection:YES];
}

- (void)selectAll:(id)sender
{
	[self.selection setArray:self.nodes];
	[self updateSelectionDisplay];
}

- (void)deselectAll:(id)sender
{
	[self.selection removeAllObjects];
	[self updateSelectionDisplay];
}

- (void)cancelOperation:(id)sender
{
	if (self.state == MAStateDragNodes) {
		[self cancelDragNodes];
	} else if (self.state == MAStateDragNewArrow) {
		[self cancelDragNewArrow];
	} else if (self.state == MAStateDragArrowEnd) {
		[self cancelDragArrowEnd];
	} else {
		[self.selection removeAllObjects];
		[self updateSelectionDisplay];
	}
}

#pragma mark - Selection

- (void)updateSelectionForClickOnNode:(MANode *)node withCommandPressed:(BOOL)commandPressed
{
	if ([self.selection count] > 0) {
		if ([self.selection containsObject:node]) {
			if (commandPressed) [self.selection removeObject:node];
		} else {
			if (!commandPressed) [self.selection removeAllObjects];
			if (node) [self.selection addObject:node];
		}
	} else if (node) {
		[self.selection addObject:node];
	}
	[self updateSelectionDisplay];
}

- (void)updateSelectionDisplay
{
	[self updateNodeColors];
}

#pragma mark - Edit Text

- (void)editNameForNode:(MANode *)node
{
	[self editTextLayer:node.textLayer withFont:[self defaultNodeFont] forObject:node];
	self.state = MAStateEditNodeName;
}

- (void)editConditionForArrow:(MAArrow *)arrow
{
	if (!arrow.condition) arrow.conditionLayer.string = nil; // Remove placeholder text
	[self editTextLayer:arrow.conditionLayer withFont:[self defaultArrowFont] forObject:arrow];
	self.state = MAStateEditArrowCondition;
}

- (void)editActionsForArrow:(MAArrow *)arrow
{
	if ([arrow.actions count] == 0) arrow.actionsLayer.string = nil; // Remove placeholder text
	[self editTextLayer:arrow.actionsLayer withFont:[self defaultArrowFont] forObject:arrow];
	self.state = MAStateEditArrowActions;
}

- (void)editTextLayer:(CATextLayer *)textLayer withFont:(NSFont *)font forObject:(id)object
{
	// Deselect all
	[self.selection removeAllObjects];
	[self updateSelectionDisplay];
	// Create text field
	NSTextField *textField = [[NSTextField alloc] init];
	[self addSubview:textField];
	// Set properties
	[textField setFocusRingType:NSFocusRingTypeNone];
	NSTextAlignment alignment = NSTextAlignmentFromCAAlignmentMode(textLayer.alignmentMode);
	[textField setAlignment:alignment];
	[textField setDelegate:self];
	[textField setFont:font];
	[[textField cell] setWraps:NO];
	[[textField cell] setScrollable:YES];
	NSString *string = [textLayer.string string];
	if (string) [textField setStringValue:string];
	[textField selectText:self];

	// Get frame from layer
	CGRect frame = [self.layer convertRect:textLayer.bounds fromLayer:textLayer];
	frame = NSRectToCGRect([self convertRectFromLayer:NSRectFromCGRect(frame)]);
	// Get preferred size
	[textField sizeToFit];
	CGFloat height = [textField frame].size.height;
	CGFloat width = clamp([textField frame].size.width, 80, 120);
	CGSize size = CGSizeMake(width, height);
	// Get anchor point
	CGPoint anchorPoint = CGPointMake(0, 0);
	if (alignment == NSRightTextAlignment) anchorPoint.x = 1;
	if (alignment == NSCenterTextAlignment) anchorPoint.x = .5;
	// Calculate & set
	frame = CGRectSetSizeWithAnchorPoint(frame, size, anchorPoint);
	[textField setFrame:frame];
	
	// Hide layer
	[self doWithoutAnimation:^{ textLayer.hidden = YES; }];
	// Store source
	self.editedObject = object;
	self.editingTextField = textField;
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	[self endEditing];
}

- (void)endEditing
{
	MAState editState = self.state;
	self.state = MAStateIdle;
	// Commit
	NSString *newString = [self.editingTextField stringValue];
	// Perform rename
	if (editState == MAStateEditNodeName) {
		MANode *node = self.editedObject;
		[self performActionSetName:newString forNode:node];
		node.textLayer.hidden = NO;
	} else if (editState == MAStateEditArrowCondition) {
		MAArrow *arrow = self.editedObject;
		MACondition *condition = [self parseConditionFromInput:newString];
		[self performActionSetCondition:condition forArrow:arrow];
	} else if (editState == MAStateEditArrowActions) {
		MAArrow *arrow = self.editedObject;
		NSArray *actions = [self parseActionsFromInput:newString];
		[self performActionSetActions:actions forArrow:arrow];
	}
	// Clean-up
	[self.editingTextField removeFromSuperview];
	self.editingTextField = nil;
}

#pragma mark - Drag Selection Box

- (void)startDragSelectionBox
{
	[self.selectionBeforeBoxSelection removeAllObjects];
	[self.selectionBeforeBoxSelection addObjectsFromArray:self.selection];
	self.state = MAStateDragSelectionBox;
}

- (void)updateDragSelectionBoxToPoint:(CGPoint)p
{
	CGRect selectionBox = CGRectBetweenPoints(self.mouseDownPoint, p);
	// Update selection
	for (MANode *node in self.nodes) {
		// Determine if selected
		BOOL isNodeSelected;
		BOOL isNodeInBox = [self isNode:node inRect:selectionBox];
		if (self.mouseDownCommandPressed) {
			BOOL wasSelected = [self.selectionBeforeBoxSelection containsObject:node];
			isNodeSelected = isNodeInBox ^ wasSelected;
		} else {
			isNodeSelected = isNodeInBox;
		}
		// Apply it
		if (isNodeSelected && ![self.selection containsObject:node]) [self.selection addObject:node];
		if (!isNodeSelected && [self.selection containsObject:node]) [self.selection removeObject:node];
	}
	[self updateSelectionDisplay];
	// Update box display
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	self.selectionBoxLayer.frame = selectionBox;
	self.selectionBoxLayer.hidden = NO;
	[CATransaction commit];
}

- (void)endDragSelectionBox
{
	[self.selectionBeforeBoxSelection removeAllObjects];
	self.selectionBoxLayer.hidden = YES;
	self.state = MAStateIdle;
}

#pragma mark - Drag Nodes

- (void)startDragItems
{
	self.nodePositionsBeforeDrag = [self dictionaryWithPositionsOfNodes:self.selection];
	self.state = MAStateDragNodes;
}

- (void)updateDragNodesToPoint:(CGPoint)p
{
	CGPoint totalDelta = CGPointSubtractPoint(p, self.mouseDownPoint);
	for (MANode *node in self.selection) {
		id key = [NSValue valueWithNonretainedObject:node];
		CGPoint startPosition = [[self.nodePositionsBeforeDrag objectForKey:key] pointValue];
		CGPoint currentPosition = CGPointAddPoint(startPosition, totalDelta);
		[self setPosition:currentPosition forNode:node];
	}
	[self updateAllArrows];
}

- (void)endDragNodes
{
	// Move was already executed while dragging, so now just register we did it (for undo)
	NSArray *nodes = [self.selection copy];
	NSDictionary *oldPositions = [self.nodePositionsBeforeDrag copy];
	[self registerActionMoveNodes:nodes withOldPositions:oldPositions];
	// Clear stored old positions
	self.nodePositionsBeforeDrag = nil;
	self.state = MAStateIdle;
}

- (void)cancelDragNodes
{
	// Restore positions
	[self setNodePositionsFromDictionary:self.nodePositionsBeforeDrag];
	// Clear stored old positions
	self.nodePositionsBeforeDrag = nil;
	self.state = MAStateDragCancelled;
}

- (NSDictionary *)dictionaryWithPositionsOfNodes:(NSArray *)nodes
{
	NSMutableDictionary *positions = [NSMutableDictionary dictionary];
	for (MANode *node in nodes) {
		id key = [NSValue valueWithNonretainedObject:node];
		id obj = [NSValue valueWithPoint:node.position];
		[positions setObject:obj forKey:key];
	}
	return positions;
}

- (void)setNodePositionsFromDictionary:(NSDictionary *)positions
{
	for (id key in [positions keyEnumerator]) {
		MANode *node = [key nonretainedObjectValue];
		CGPoint oldPosition = [positions[key] pointValue];
		[self setPosition:oldPosition forNode:node];
	}
	[self updateAllArrows];
}

#pragma mark - Drag New Arrow

- (void)startDragNewArrow
{
	MANode *node = self.mouseDownNode;
	CGFloat angle = CGPointAngleToPoint(node.position, self.mouseDownPoint);
	MAArrow *newArrow = [self createArrowFromNode:node towardsAngle:angle];
	[self addArrow:newArrow];
	self.draggedArrow = newArrow;
	self.state = MAStateDragNewArrow;
}

- (void)updateDragNewArrowToPoint:(CGPoint)p
{
	[self updateDragArrowEnd:MAArrowHead forArrow:self.draggedArrow toPoint:p];
}

- (void)endDragNewArrow
{
	if (self.draggedArrow.targetNode) {
		[self finalizeActionAddArrow:self.draggedArrow];
	} else {
		[self deleteArrow:self.draggedArrow];
	}
	self.draggedArrow = nil;
	self.state = MAStateIdle;
}

- (void)cancelDragNewArrow
{
	[self deleteArrow:self.draggedArrow];
	self.draggedArrow = nil;
	self.state = MAStateDragCancelled;
}

#pragma mark - Drag Arrow End

- (void)startDragArrowEnd
{
	MAArrow *arrow = self.mouseDownArrow;
	MAArrowEnd end = self.draggedArrowEnd;
	self.draggedArrow = arrow;
	// Store end node & angle
	self.arrowEndNodeBeforeDrag = [arrow nodeForEnd:end];
	self.arrowEndAngleBeforeDrag = [arrow angleForEnd:end];
	self.state = MAStateDragArrowEnd;
}

- (void)updateDragArrowEndToPoint:(CGPoint)p
{
	[self updateDragArrowEnd:self.draggedArrowEnd forArrow:self.draggedArrow toPoint:p];
}

- (void)updateDragArrowEnd:(MAArrowEnd)arrowEnd forArrow:(MAArrow *)arrow toPoint:(CGPoint)p
{
	// Hit-test
	MAHitTests tests = MAHitTestNode | MAHitTestNodeEdge;
	MAHitTests passedTest;
	id hitObject = [self performHitTests:tests onPoint:p passedTest:&passedTest];
	// Set point for end
	MANode *oldNode = [arrow nodeForEnd:arrowEnd];
	if ([hitObject isKindOfClass:[MANode class]]) {
		MANode *node = hitObject;
		if (node != oldNode) {
			[arrow setNode:node forEnd:arrowEnd];
		}
		CGFloat angle = CGPointAngleToPoint(node.position, p);
		[arrow setAngle:angle forEnd:arrowEnd];
	} else {
		[arrow setNode:nil forEnd:arrowEnd];
		[arrow setPoint:p forEnd:arrowEnd];
		arrow.targetPoint = p;
	}
	[self updateArrow:arrow];
}

- (void)endDragArrowEnd
{
	MAArrow *arrow = self.draggedArrow;
	MAArrowEnd arrowEnd = self.draggedArrowEnd;
	if ([arrow nodeForEnd:arrowEnd]) {
		[self registerActionMoveArrowEnd:arrowEnd forArrow:arrow oldNode:self.arrowEndNodeBeforeDrag oldAngle:self.arrowEndAngleBeforeDrag];
	} else {
		[self restoreDraggedArrowEnd];
		[self performActionDeleteArrow:arrow];
	}
	self.draggedArrow = nil;
	self.state = MAStateIdle;
}

- (void)cancelDragArrowEnd
{
	[self restoreDraggedArrowEnd];
	// Clean-up
	self.draggedArrow = nil;
	self.state = MAStateDragCancelled;
}

- (void)restoreDraggedArrowEnd
{
	MAArrow *arrow = self.draggedArrow;
	MAArrowEnd end = self.draggedArrowEnd;
	[arrow setNode:self.arrowEndNodeBeforeDrag forEnd:end];
	[arrow setAngle:self.arrowEndAngleBeforeDrag forEnd:end];
	[self updateArrow:arrow];
}

#pragma mark - Arrow

- (void)updateArrowDisplay:(MAArrow *)arrow;
{
	// Add main curve
	CGMutablePathRef linePath = CGPathCreateMutable();
	// Points and control points
	CGPoint p1 = arrow.sourcePoint;
	CGPoint p3 = arrow.targetPoint;
	CGFloat d = (arrow.sourceNode != arrow.targetNode) ? CGPointDistanceToPoint(p1, p3) : kNodeRadius*4;
	CGPoint cp1 = arrow.sourceNode ? CGPointMoveDistanceInAngle(p1, d/4, arrow.sourceAngle) : p1;
	CGFloat targetAngle = arrow.targetNode ? arrow.targetAngle : CGPointAngleToPoint(p3, cp1);
	CGPoint p2 = CGPointMoveDistanceInAngle(p3, MAArrowHeadLength, targetAngle);
	CGPoint cp2 = arrow.targetNode ? CGPointMoveDistanceInAngle(p2, d/4, arrow.targetAngle) : p2;
	// Make curve
	CGPathMoveToPoint(linePath, NULL, p1.x, p1.y);
	CGPathAddCurveToPoint(linePath, NULL, cp1.x, cp1.y, cp2.x, cp2.y, p2.x, p2.y);
	CGPathAddLineToPoint(linePath, NULL, p3.x, p3.y);
	// Set
	arrow.layer.path = linePath;
	CFRelease(linePath);

	// Dot at tail (disabled)
//	CGMutablePathRef tailPath = CGPathCreateMutable();
//	CGRect ballRect = CGRectAroundPoint(CGPointZero, CGSizeMakeUniform(2*kArrowBallRadius));
//	CGPathAddEllipseInRect(tailPath, NULL, ballRect);
//	arrow.tailLayer.path = tailPath;
//	CFRelease(tailPath);
//	[self doWithoutAnimation:^{
//		arrow.tailLayer.hidden = NO;
//		arrow.tailLayer.position = arrow.sourcePoint;
//	}];
	[self doWithoutAnimation:^{ arrow.tailLayer.hidden = YES; }];

	// Add triangle at end
	CGMutablePathRef headPath = CGPathCreateMutable();
	// Points
	CGPoint hp1 = NSZeroPoint;
	CGPoint hp2 = CGPointMoveDistanceInAngle(hp1, MAArrowHeadLength, targetAngle+MAArrowHeadAngle);
	CGPoint hp3 = CGPointMoveDistanceInAngle(hp1, MAArrowHeadLength, targetAngle-MAArrowHeadAngle);
	// Make curve
	CGPathMoveToPoint(headPath, NULL, hp1.x, hp1.y);
	CGPathAddLineToPoint(headPath, NULL, hp2.x, hp2.y);
	CGPathAddLineToPoint(headPath, NULL, hp3.x, hp3.y);
	// Set
	arrow.headLayer.path = headPath;
	CFRelease(headPath);
	[self doWithoutAnimation:^{ arrow.headLayer.position = arrow.targetPoint; }];

	CGPoint midPoint = CGPointOnBezier(.5, p1, cp1, cp2, p2);
	arrow.midPoint = midPoint;
	// Text
	CGPoint tp = midPoint;
	tp.y -= 5;
	tp = CGPointRound(tp); // To avoid fuzzy text
	[self doWithoutAnimation:^{ arrow.textLayer.position = tp; }];
}

- (void)updateAllArrows
{
	for (MAArrow *arrow in self.arrows) {
		[self updateArrow:arrow];
	}
}

- (void)updateArrow:(MAArrow *)arrow
{
	if (arrow.sourceNode) arrow.sourcePoint = [self arrowPointOnNode:arrow.sourceNode towardsAngle:arrow.sourceAngle];
	if (arrow.targetNode) arrow.targetPoint = [self arrowPointOnNode:arrow.targetNode towardsAngle:arrow.targetAngle];
	[self updateArrowDisplay:arrow];
}

- (CGPoint)arrowPointOnNode:(MANode *)node towardsPoint:(CGPoint)p
{
	CGFloat angle = CGPointAngleToPoint(node.position, p);
	return [self arrowPointOnNode:node towardsAngle:angle];
}

- (CGPoint)arrowPointOnNode:(MANode *)node towardsAngle:(CGFloat)angle
{
	return CGPointMoveDistanceInAngle(node.position, kNodeRadius, angle);
}

- (MAArrow *)createArrowFromNode:(MANode *)node towardsAngle:(CGFloat)angle
{
	MAArrow *arrow = [[MAArrow alloc] init];
	arrow.sourceNode = node;
	arrow.sourceAngle = angle;
	arrow.sourcePoint = [self arrowPointOnNode:node towardsAngle:angle];
	[self createLayersForArrow:arrow];
	return arrow;
}

- (void)createLayersForArrow:(MAArrow *)arrow
{
	// Main layer
	CAShapeLayer *layer = [CAShapeLayer layer];
	layer.fillColor = nil;
	layer.strokeColor = [[NSColor blackColor] CGColor];
	layer.lineWidth = 2;
	arrow.layer = layer;
	// Tail layer
	CAShapeLayer *tailLayer = [CAShapeLayer layer];
	tailLayer.fillColor = [[NSColor blackColor] CGColor];
	[layer addSublayer:tailLayer];
	arrow.tailLayer = tailLayer;
	// Head layer
	CAShapeLayer *headLayer = [CAShapeLayer layer];
	headLayer.fillColor = [[NSColor blackColor] CGColor];
	[layer addSublayer:headLayer];
	arrow.headLayer = headLayer;
	// Default text attributes
	CGColorRef backColor = [[NSColor controlColor] CGColor];
	// Condition
	CATextLayer *conditionLayer = [CATextLayer layer];
	conditionLayer.contentsScale = [[self window] backingScaleFactor];
	conditionLayer.alignmentMode = kCAAlignmentRight;
	conditionLayer.backgroundColor = backColor;
	conditionLayer.anchorPoint = CGPointMake(1, 0);
	conditionLayer.position = CGPointMake(0, 0);
	arrow.conditionLayer = conditionLayer;
	// Slash
	CATextLayer *slashLayer = [CATextLayer layer];
	NSMutableDictionary *slashAttributes = [NSMutableDictionary dictionary];
	slashAttributes[NSFontAttributeName] = [self defaultArrowFont];
	NSAttributedString *slashString = [[NSAttributedString alloc] initWithString:@"/" attributes:slashAttributes];
	[self setAndFitString:slashString forTextLayer:slashLayer];
	slashLayer.contentsScale = [[self window] backingScaleFactor];
	slashLayer.alignmentMode = kCAAlignmentCenter;
	slashLayer.backgroundColor = backColor;
	slashLayer.anchorPoint = CGPointMake(0, 0);
	slashLayer.bounds = CGRectMake(0, 0, 14, slashLayer.bounds.size.height);
	arrow.slashLayer = slashLayer;
	// Actions
	CATextLayer *actionsLayer = [CATextLayer layer];
	actionsLayer.contentsScale = [[self window] backingScaleFactor];
	actionsLayer.alignmentMode = kCAAlignmentLeft;
	actionsLayer.backgroundColor = backColor;
	actionsLayer.anchorPoint = CGPointMake(0, 0);
	actionsLayer.position = CGPointMake(14, 0);
	arrow.actionsLayer = actionsLayer;
	// Group all text in a layer
	CALayer *textLayer = [CALayer layer];
	[textLayer addSublayer:conditionLayer];
	[textLayer addSublayer:actionsLayer];
	[textLayer addSublayer:slashLayer];
	[layer addSublayer:textLayer];
	arrow.textLayer = textLayer;
	// Set
	[self setCondition:arrow.condition forArrow:arrow];
	[self setActions:arrow.actions forArrow:arrow];
}

- (MACondition *)parseConditionFromInput:(NSString *)input
{
	NSString *name = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([name length] > 0) {
		MACondition *condition = [self conditionWithName:name];
		if (!condition) condition = [MACondition conditionWithName:name];
		return condition;
	}
	return nil;
}

- (MACondition *)conditionWithName:(NSString *)name
{
	for (MAArrow *arrow in self.arrows) {
		MACondition *condition = arrow.condition;
		if (!condition) continue;
		NSComparisonResult compareResult = [condition.name compare:name options:NSCaseInsensitiveSearch];
		if (compareResult == NSOrderedSame) return condition;
	}
	return nil;
}

- (NSArray *)parseActionsFromInput:(NSString *)input
{
	NSMutableArray *actions = [NSMutableArray array];
	NSArray *actionStrings = [input componentsSeparatedByString:kActionSeparatorString];
	for (NSString *actionString in actionStrings) {
		NSString *name = [actionString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if ([name length] > 0) {
			MAAction *action = [self actionWithName:name];
			if (!action) action = [MAAction actionWithName:name];
			[actions addObject:action];
		}
	}
	return actions;
}

- (MAAction *)actionWithName:(NSString *)name
{
	for (MAArrow *arrow in self.arrows) {
		for (MAAction *action in arrow.actions) {
			NSComparisonResult compareResult = [action.name compare:name options:NSCaseInsensitiveSearch];
			if (compareResult == NSOrderedSame) return action;
		}
	}
	return nil;
}

- (void)setCondition:(MACondition *)condition forArrow:(MAArrow *)arrow
{
	arrow.condition = condition;
	// Get display string
	NSString *displayString = condition ? condition.name : @"condition";
	// Add attributes
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	attributes[NSFontAttributeName] = [self defaultArrowFont];
	if (!condition) attributes[NSForegroundColorAttributeName] = [NSColor grayColor];
	NSAttributedString *displayStringAttributed = [[NSAttributedString alloc] initWithString:displayString attributes:attributes];
	// Set display string & update
	[self setAndFitString:displayStringAttributed forTextLayer:arrow.conditionLayer];
	[self updateTextLayerVisibilityForArrow:arrow];
}

- (void)setActions:(NSArray *)actions forArrow:(MAArrow *)arrow
{
	arrow.actions = actions;
	// Get display string
	BOOL hasActions = ([actions count] > 0);
	NSString *displayString = hasActions ? [actions componentsJoinedByString:@", "] : @"actions";
	// Add attributes
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	attributes[NSFontAttributeName] = [self defaultArrowFont];
	if (!hasActions) attributes[NSForegroundColorAttributeName] = [NSColor grayColor];
	NSAttributedString *displayStringAttributed = [[NSAttributedString alloc] initWithString:displayString attributes:attributes];
	// Set display string & update
	[self setAndFitString:displayStringAttributed forTextLayer:arrow.actionsLayer];
	[self updateTextLayerVisibilityForArrow:arrow];
}

- (void)updateTextLayerVisibilityForArrow:(MAArrow *)arrow
{
	// Get mouse position
	NSPoint mousePosition = [self.window mouseLocationOutsideOfEventStream];
	CGPoint p = NSPointToCGPoint([self convertPoint:mousePosition fromView:nil]);
	// Do hit tests
	MAHitTests passedTest = [self performHitTests:MAHitTestArrowText onPoint:p forArrow:arrow];
	BOOL mouseIsOverText = (passedTest == MAHitTestArrowText);
	// Update layer visibility
	BOOL isEditingCondition = (self.state == MAStateEditArrowCondition && self.editedObject == arrow);
	BOOL isEditingActions = (self.state == MAStateEditArrowActions && self.editedObject == arrow);
	[self doWithoutAnimation:^{
		arrow.conditionLayer.hidden = (arrow.condition == nil && !mouseIsOverText) || isEditingCondition;
		arrow.actionsLayer.hidden = ([arrow.actions count] == 0 && !mouseIsOverText) || isEditingActions;
		arrow.slashLayer.hidden = ([arrow.actions count] == 0 && !mouseIsOverText) && !isEditingActions;
	}];
}

- (void)setAndFitString:(NSAttributedString *)string forTextLayer:(CATextLayer *)textLayer
{
	textLayer.string = string;
	CGFloat padding = 1;
	CGSize size = [textLayer preferredFrameSize];
	size = CGSizeAdd(size, 2*padding);
	[self doWithoutAnimation:^{
		textLayer.bounds = CGRectMake(0, 0, size.width, size.height);
	}];
}

- (void)deleteArrow:(MAArrow *)arrow
{
	if (self.state == MAStateEditNodeName || self.state == MAStateEditArrowCondition || self.state == MAStateEditArrowActions) {
		// TODO: Do this nicer, by making a setState method that handles all state ending actions.
		[self endEditing];
	}
	[self.arrows removeObject:arrow];
	arrow.sourceNode = nil;
	arrow.targetNode = nil;
	[self doWithoutAnimation:^{ [arrow.layer removeFromSuperlayer]; }];
}

- (NSArray *)arrowsForNodes:(NSArray *)nodes
{
	NSMutableArray *arrows = [NSMutableArray array];
	for (MANode *node in nodes) {
		for (MAArrow *arrow in node.arrows) {
			if (![arrows containsObject:arrow]) [arrows addObject:arrow];
		}
	}
	return arrows;
}

- (void)updateArrowColors
{
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	for (MAArrow *arrow in self.arrows) {
		// Update arrow
		if (arrow == self.activeArrow) {
			[arrow.headLayer setFillColor:[self.activeObjectStrokeColor CGColor]];
			[arrow.layer setStrokeColor:[self.activeObjectStrokeColor CGColor]];
		} else {
			[arrow.headLayer setFillColor:[[NSColor blackColor] CGColor]];
			[arrow.layer setStrokeColor:[[NSColor blackColor] CGColor]];
		}
		// Update condition
		if (arrow.condition) {
			// Determine color
			NSColor *foregroundColor = [NSColor blackColor];
			BOOL isActive = (arrow.sourceNode == self.activeNode && arrow.condition == self.activeCondition);
			if (isActive) {
				foregroundColor = self.activeObjectStrokeColor;
			} else if ([self.hoveredItems containsObject:arrow.condition]) {
				foregroundColor = self.hoveredObjectStrokeColor;
			}
			// Append with attributes
			NSDictionary *attributes = @{ NSForegroundColorAttributeName : foregroundColor, NSFontAttributeName : [self defaultArrowFont] };
			NSAttributedString *conditionNameAttributed = [[NSAttributedString alloc] initWithString:arrow.condition.name attributes:attributes];
			[arrow.conditionLayer setString:conditionNameAttributed];
		}
		// Update actions
		if ([arrow.actions count] > 0) {
			NSMutableAttributedString *newActionsText = [[NSMutableAttributedString alloc] init];
			NSDictionary *separatorAttributes = @{ NSForegroundColorAttributeName : [NSColor blackColor], NSFontAttributeName : [self defaultArrowFont] };
			for (int i=0; i<[arrow.actions count]; i++) {
				MAAction *action = arrow.actions[i];
				// Determine color
				NSColor *foregroundColor = [NSColor blackColor];
				BOOL isActive = (arrow == self.activeArrow && i == self.activeActionIndex);
				if (isActive) {
					foregroundColor = self.activeObjectStrokeColor;
				} else if ([self.hoveredItems containsObject:action]) {
					foregroundColor = self.hoveredObjectStrokeColor;
				}
				// Append with attributes
				NSDictionary *attributes = @{ NSForegroundColorAttributeName : foregroundColor, NSFontAttributeName : [self defaultArrowFont] };
				NSAttributedString *actionNameAttributed = [[NSAttributedString alloc] initWithString:action.name attributes:attributes];
				if (i > 0) [newActionsText appendAttributedString:[[NSAttributedString alloc] initWithString:kActionSeparatorDisplayString attributes:separatorAttributes]];
				[newActionsText appendAttributedString:actionNameAttributed];
			}
			[arrow.actionsLayer setString:newActionsText];
		}
	}
	[CATransaction commit];
}

#pragma mark - Nodes

- (BOOL)isNode:(MANode *)node inRect:(CGRect)rect
{
	CGPoint p = node.position;
	rect = CGRectExpand(rect, kNodeRadius);
	return CGRectContainsPoint(rect, p);
}

- (void)setPosition:(CGPoint)position forNode:(MANode *)node
{
	node.position = position;
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	node.layer.position = CGPointRound(position);
	[CATransaction commit];
}

- (MANode *)createNode
{
	MANode *node = [[MANode alloc] init];
	node.name = @" ";
	[self createLayersForNode:node];
	return node;
}

- (void)createLayersForNode:(MANode *)node
{
	// Create layer
	CALayer *layer = [CALayer layer];
	layer.bounds = CGRectMake(0, 0, kNodeRadius*2, kNodeRadius*2);
	layer.backgroundColor = [[NSColor whiteColor] CGColor];
	layer.cornerRadius = kNodeRadius;
	layer.borderColor = [[NSColor blackColor] CGColor];
	layer.borderWidth = 2;
	layer.shadowOpacity = .2;
	layer.shadowRadius = 5;
	node.layer = layer;
	// Second border layer
	CGFloat secondBorderRadius = kNodeRadius-6;
	CALayer *secondBorderLayer = [CALayer layer];
	[layer addSublayer:secondBorderLayer];
	secondBorderLayer.position = CGPointMake(layer.bounds.size.width/2, layer.bounds.size.height/2);
	secondBorderLayer.bounds = CGRectMake(0, 0, secondBorderRadius*2, secondBorderRadius*2);
	secondBorderLayer.cornerRadius = secondBorderRadius;
	secondBorderLayer.borderColor = [[NSColor blackColor] CGColor];
	secondBorderLayer.borderWidth = 2;
	secondBorderLayer.hidden = !node.isInitialState;
	node.secondBorderLayer = secondBorderLayer;
	// Create text layer
	CATextLayer *textLayer = [CATextLayer layer];
	textLayer.contentsScale = [[self window] backingScaleFactor];
	[node.layer addSublayer:textLayer];
	textLayer.anchorPoint = CGPointMake(0, 0);
	textLayer.alignmentMode = kCAAlignmentCenter;
	node.textLayer = textLayer;
	// Set to update stuff
	[self setName:node.name forNode:node];
}

- (void)addNode:(MANode *)node
{
	if (![self.nodes containsObject:node]) [self.nodes addObject:node];
	[self.nodesLayer addSublayer:node.layer];
	node.layer.position = CGPointRound(node.position);
	// Misc UI update
	[self.startHintLabel setHidden:YES];
}

- (void)addArrow:(MAArrow *)arrow
{
	if (![self.arrows containsObject:arrow]) {
		[self.arrows addObject:arrow];
	}
	[self.arrowsLayer addSublayer:arrow.layer];
}

- (void)deleteNode:(MANode *)node
{
	if (self.state == MAStateEditNodeName || self.state == MAStateEditArrowCondition || self.state == MAStateEditArrowActions) {
		// TODO: Do this nicer, by making a setState method that handles all state ending actions.
		[self endEditing];
	}
	[self.nodes removeObject:node];
	[self doWithoutAnimation:^{ [node.layer removeFromSuperlayer]; }];
	while ([node.arrows count] > 0) {
		MAArrow *arrow = [node.arrows objectAtIndex:0];
		[self deleteArrow:arrow];
	}
	[self.selection removeObject:node]; // If present
	// Misc UI update
	[self.startHintLabel setHidden:([self.nodes count] > 0)];
}

- (void)setName:(NSString *)text forNode:(MANode *)node
{
	node.name = text;
	// Create attributed string
	NSDictionary *textAttributes = @{ NSFontAttributeName : [self defaultNodeFont] };
	NSAttributedString *string = [[NSAttributedString alloc] initWithString:node.name attributes:textAttributes];
	// Resize
	CGFloat height = ceil([string size].height);
	CGFloat parentWidth = round(node.layer.bounds.size.width);
	CGFloat parentHeight = round(node.layer.bounds.size.height);
	// Set
	[self doWithoutAnimation:^{
		node.textLayer.string = string;
		node.textLayer.frame = CGRectMake(0, round(parentHeight/2-height/2), parentWidth, height);
	}];
}

- (void)setIsInitialState:(BOOL)isInitialState forNode:(MANode *)node
{
	if (node.isInitialState == isInitialState) return;
	// If we want make it initial state we have to unset the current initial state (if any)
	if (isInitialState) {
		MANode *oldNode = [self getInitialStateConnectedToNode:node];
		[self setIsInitialState:NO forNode:oldNode];
	}
	// Set
	node.isInitialState = isInitialState;
	// Update
	[self doWithoutAnimation:^{
		node.secondBorderLayer.hidden = !isInitialState;
	}];
}

- (MANode *)unsetInitialStateForAddingArrow:(MAArrow *)arrow // For managing conflict of initial state when two node networks are connected
{
	// Get nodes connected to source (before this arrow was there)
	NSArray *sourceNodes = [arrow.sourceNode findConnectedNodesIgnoringArrows:@[ arrow ]];
	// If they were already connected there shouldn't be a conflict
	if ([sourceNodes containsObject:arrow.targetNode]) return nil;
	// Get initial state in source network
	MANode *sourceInitialState = [sourceNodes objectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) { return [obj isInitialState]; }];
	// If the source network doesn't contain an intial state, no conflict
	if (!sourceInitialState) return nil;
	// Get nodes connected to target (before this arrow was there)
	NSArray *targetNodes = [arrow.targetNode findConnectedNodesIgnoringArrows:@[ arrow ]];
	// Get initial state in target network
	MANode *targetInitialState = [targetNodes objectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) { return [obj isInitialState]; }];
	// We'll unset the initial state from the target's network
	return targetInitialState;
}

- (MANode *)getInitialStateConnectedToNode:(MANode *)node
{
	NSArray *connectedNodes = [node findConnectedNodes];
	for (MANode *connectedNode in connectedNodes) {
		if (connectedNode.isInitialState) return connectedNode;
	}
	return nil;
}

- (void)updateNodeColors
{
	for (MANode *node in self.nodes) {
		// Determine color
		NSColor *backColor = [NSColor whiteColor];
		NSColor *borderColor = [NSColor blackColor];
		if (node == self.activeNode) {
			backColor = self.activeObjectFillColor;
			borderColor = self.activeObjectStrokeColor;
		} else if ([self.activatedNodesMutable containsObject:node]) {
			backColor = self.activeObjectFillColor; //[self mixColor:self.activeObjectFillColor withColor:backColor position:.75];
			borderColor = [self mixColor:self.activeObjectStrokeColor withColor:borderColor position:.5];
		} else if ([self.selection containsObject:node]) {
			backColor = self.selectedObjectFillColor;
			borderColor = self.selectedObjectStrokeColor;
		}
		// Set color
		[self doWithoutAnimation:^{
			node.layer.backgroundColor = [backColor CGColor];
			node.layer.borderColor = node.secondBorderLayer.borderColor = [borderColor CGColor];
		}];
	}
}

- (NSColor *)mixColor:(NSColor *)color1 withColor:(NSColor *)color2 position:(CGFloat)p
{
	// Fix inputs
	p = clamp(p, 0, 1);
	color1 = [color1 colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	color2 = [color2 colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	// Get components
	CGFloat red = [color1 redComponent] * (1-p) + [color2 redComponent] * p;
	CGFloat green = [color1 greenComponent] * (1-p) + [color2 greenComponent] * p;
	CGFloat blue = [color1 blueComponent] * (1-p) + [color2 blueComponent] * p;
	CGFloat alpha = [color1 alphaComponent] * (1-p) + [color2 alphaComponent] * p;
	// Create new color
	return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

#pragma mark - Hit Testing

- (id)performHitTests:(MAHitTests)tests onPoint:(CGPoint)p passedTest:(MAHitTests *)passedTestOut
{
	// Arrows
	if ((tests & MAHitTestAllArrow) != 0) {
		for (MAArrow *arrow in [self.arrows reverseObjectEnumerator]) { // Later objects are on top
			if (arrow == self.draggedArrow) continue;
			MAHitTests passedTest = [self performHitTests:tests onPoint:p forArrow:arrow];
			if (passedTest != MAHitTestNone) {
				*passedTestOut = passedTest;
				return arrow;
			}
		}
	}
	// Nodes
	if ((tests & MAHitTestAllNode) != 0) {
		for (MANode *node in [self.nodes reverseObjectEnumerator]) { // Later objects are on top
			MAHitTests passedTest = [self performHitTests:tests onPoint:p forNode:node];
			if (passedTest != MAHitTestNone) {
				*passedTestOut = passedTest;
				return node;
			}
		}
	}
	// Return failed
	*passedTestOut = MAHitTestNone;
	return nil;
}

- (MAHitTests)performHitTests:(MAHitTests)tests onPoint:(CGPoint)p forArrow:(MAArrow *)arrow
{
	if ((tests & MAHitTestArrowTail) == MAHitTestArrowTail) {
		float distanceToTail = CGPointDistanceToPoint(p, arrow.sourcePoint);
		if (distanceToTail < kArrowEndHitDistance) return MAHitTestArrowTail;
	}
	if ((tests & MAHitTestArrowHead) == MAHitTestArrowHead) {
		float distanceToHead = CGPointDistanceToPoint(p, arrow.targetPoint);
		if (distanceToHead < kArrowEndHitDistance) return MAHitTestArrowHead;
	}
	if ((tests & MAHitTestArrowCondition) == MAHitTestArrowCondition) {
		CGRect conditionBounds = [self.layer convertRect:arrow.conditionLayer.bounds fromLayer:arrow.conditionLayer];
		if (CGRectContainsPoint(conditionBounds, p)) return MAHitTestArrowCondition;
	}
	if ((tests & MAHitTestArrowActions) == MAHitTestArrowActions) {
		CGRect actionBounds = [self.layer convertRect:arrow.actionsLayer.bounds fromLayer:arrow.actionsLayer];
		if (CGRectContainsPoint(actionBounds, p)) return MAHitTestArrowActions;
	}
	if ((tests & MAHitTestArrowText) == MAHitTestArrowText) {
		CGRect conditionBounds = [self.layer convertRect:arrow.conditionLayer.bounds fromLayer:arrow.conditionLayer];
		CGRect actionBounds = [self.layer convertRect:arrow.actionsLayer.bounds fromLayer:arrow.actionsLayer];
		CGRect textBounds = CGRectUnion(conditionBounds, actionBounds);
		CGFloat distanceToText = CGPointDistanceToRect(p, textBounds);
		if (distanceToText < kArrowTextHitDistance) return MAHitTestArrowText;
	}
	return MAHitTestNone;
}

- (MAHitTests)performHitTests:(MAHitTests)tests onPoint:(CGPoint)p forNode:(MANode *)node
{
	float distanceToCenter = CGPointDistanceToPoint(p, node.position);
	float distanceToEdge = ABS(distanceToCenter-kNodeRadius);
	if ((tests & MAHitTestNodeEdge) == MAHitTestNodeEdge) {
		if (distanceToEdge <= kNodeEdgeHitDistance) return MAHitTestNodeEdge;
	}
	if ((tests & MAHitTestNode) == MAHitTestNode) {
		if (distanceToCenter <= kNodeRadius) return MAHitTestNode;
	}
	return MAHitTestNone;
}

- (NSUInteger)actionIndexAtPoint:(CGPoint)p forArrow:(MAArrow *)arrow
{
	// Get string
	NSAttributedString *attributedString = arrow.actionsLayer.string;
	NSAssert([attributedString isKindOfClass:[NSAttributedString class]], @"Actions string is not attributed.");
	NSString *string = [attributedString string];
	// Split into actions
	NSArray *actionStrings = [string componentsSeparatedByString:kActionSeparatorDisplayString];
	// Go through all actions
	NSRange range = NSMakeRange(0, 0);
	for (int i=0; i<[actionStrings count]; i++) {
		// Adjust range
		range.length = [actionStrings[i] length];
		if (i > 0) range.location += [actionStrings[i-1] length] + [kActionSeparatorDisplayString length];
		// Get bounds
		CGRect rect = [self boundsForRange:range inAttributedString:attributedString];
		CGPoint layerOrigin = [arrow.actionsLayer convertPoint:CGPointZero toLayer:[self layer]];
		rect.origin = CGPointAddPoint(rect.origin, layerOrigin);
		// Check
		if (CGRectContainsPoint(rect, p)) return i;
	}
	return NSNotFound;
}

- (CGRect)boundsForRange:(NSRange)range inAttributedString:(NSAttributedString *)string
{
	// Get size of range
	NSAttributedString *substring = [string attributedSubstringFromRange:range];
	NSSize size = [substring size];
	// Get size of text before range
	NSRange rangeBefore = NSMakeRange(0, range.location);
	NSAttributedString *substringBefore = [string attributedSubstringFromRange:rangeBefore];
	NSSize sizeBefore = [substringBefore size];
	// Return rect
	return CGRectMake(sizeBefore.width, 0, size.width, size.height);
}

#pragma mark - Actions

#pragma mark Add Nodes

- (void)performActionAddNodes:(NSArray *)nodes arrows:(NSArray *)arrows setSelection:(BOOL)setSelection
{
	// Register undo
	[[self prepareUndoOnSelf] performActionDeleteNodes:[nodes copy] clearSelection:setSelection];
	NSString *actionName = ([nodes count] == 1) ? @"Add State" : @"Add States";
	[self setActionNameForUndo:actionName];
	// Execute
	for (MANode *node in nodes) [self addNode:node];
	for (MAArrow *arrow in arrows) [self addArrow:arrow];
	if (setSelection) [self.selection setArray:nodes];
	// Notify delegate
	[self notifyDelegateOfChange];
}

- (MANode *)performActionAddNewNodeAtPoint:(CGPoint)p
{
	MANode *node = [self createNode];
	[self setPosition:p forNode:node];
	[self performActionAddNodes:@[ node ] arrows:nil setSelection:NO];
	if ([self.nodes count] == 1) [self setIsInitialState:YES forNode:node];
	return node;
}

#pragma mark Delete Nodes

- (void)performActionDeleteNodes:(NSArray *)nodes clearSelection:(BOOL)clearSelection
{
	// Register undo
	NSArray *arrows = [self arrowsForNodes:nodes];
	[[self prepareUndoOnSelf] performActionAddNodes:[nodes copy] arrows:arrows setSelection:clearSelection];
	[self setActionNameForUndo:@"Delete Selection"];
	// Execute
	for (MANode *node in [nodes copy]) [self deleteNode:node]; // Also deletes attached arrows
	if (clearSelection) [self.selection removeAllObjects];
	// Notify delegate 
	[self notifyDelegateOfChange];
}

#pragma mark Move Nodes

- (void)registerUndoActionMoveNodes:(NSArray *)nodes withOldPositions:(NSDictionary *)oldPositions
{
	// Register undo
	[[self prepareUndoOnSelf] performActionMoveNodes:[nodes copy] toPositions:[oldPositions copy]];
	[self setActionNameForUndo:@"Drag States"];
}

- (void)registerActionMoveNodes:(NSArray *)nodes withOldPositions:(NSDictionary *)oldPositions
{
	[self registerUndoActionMoveNodes:nodes withOldPositions:oldPositions];
	// Currently nothing else
}

- (void)performActionMoveNodes:(NSArray *)nodes toPositions:(NSDictionary *)positions
{
	// Register undo
	NSDictionary *currentPositions = [self dictionaryWithPositionsOfNodes:nodes];
	[self registerUndoActionMoveNodes:nodes withOldPositions:currentPositions];
	// Execute
	[self setNodePositionsFromDictionary:positions];
}

#pragma mark Set Name

- (void)performActionSetName:(NSString *)name forNode:(MANode *)node
{
	if ([node.name isEqualTo:name]) return;
	// Register undo
	NSString *oldName = [node.name copy];
	[[self prepareUndoOnSelf] performActionSetName:oldName forNode:node];
	[self setActionNameForUndo:@"Rename State"];
	// Execute
	[self setName:name forNode:node];
	// Notify delegate
	[self notifyDelegateOfChange];
}

#pragma mark Set Initial State

- (void)performActionSetIsInitialState:(BOOL)isInitialState forNode:(MANode *)node
{
	// Register undo
	MANode *currentInitialState = [self getInitialStateConnectedToNode:node];
	if (currentInitialState) {
		[[self prepareUndoOnSelf] performActionSetIsInitialState:YES forNode:currentInitialState];
	} else {
		[[self prepareUndoOnSelf] performActionSetIsInitialState:NO forNode:node];
	}
	[self setActionNameForUndo:@"Set Initial State"];
	// Execute
	[self setIsInitialState:isInitialState forNode:node];
	// Notify delegate
	[self notifyDelegateOfChange];
}

#pragma mark Add arrow

- (void)registerUndoActionAddArrow:(MAArrow *)arrow unsetInitialState:(MANode *)unsetInitialState
{
	// Register undo
	if (unsetInitialState) [[self prepareUndoOnSelf] setIsInitialState:YES forNode:unsetInitialState];
	[[self prepareUndoOnSelf] performActionDeleteArrow:arrow];
	[self setActionNameForUndo:@"Add Transition"];
}

- (void)finalizeActionAddArrow:(MAArrow *)arrow
{
	MANode *unsetInitialState = [self unsetInitialStateForAddingArrow:arrow];
	[self registerUndoActionAddArrow:arrow unsetInitialState:unsetInitialState];
	// Execute
	if (unsetInitialState) [self setIsInitialState:NO forNode:unsetInitialState];
	// Notify delegate
	[self notifyDelegateOfChange];
}

- (void)performActionAddArrow:(MAArrow *)arrow
{
	// Register undo
	MANode *unsetInitialState = [self unsetInitialStateForAddingArrow:arrow];
	[self registerUndoActionAddArrow:arrow unsetInitialState:unsetInitialState];
	// Execute
	[self addArrow:arrow];
	if (unsetInitialState) [self setIsInitialState:NO forNode:unsetInitialState];
	// Notify delegate
	[self notifyDelegateOfChange];
}

#pragma mark Delete Arrow

- (void)performActionDeleteArrow:(MAArrow *)arrow
{
	// Register undo
	[[self prepareUndoOnSelf] performActionAddArrow:arrow];
	[self setActionNameForUndo:@"Delete Transition"];
	// Execute
	[self deleteArrow:arrow];
	// Notify delegate
	[self notifyDelegateOfChange];
}

#pragma mark Move Arrow End

- (void)registerUndoActionMoveArrowEnd:(MAArrowEnd)arrowEnd forArrow:(MAArrow *)arrow oldNode:(MANode *)oldNode oldAngle:(CGFloat)oldAngle
{
	// Register undo
	[[self prepareUndoOnSelf] performActionMoveArrowEnd:arrowEnd forArrow:arrow toNode:oldNode atAngle:oldAngle];
	[self setActionNameForUndo:@"Drag Transition"];
}

- (void)registerActionMoveArrowEnd:(MAArrowEnd)arrowEnd forArrow:(MAArrow *)arrow oldNode:(MANode *)oldNode oldAngle:(CGFloat)oldAngle
{
	[self registerUndoActionMoveArrowEnd:arrowEnd forArrow:arrow oldNode:oldNode oldAngle:oldAngle];
	// Notify delegate
	if ([arrow nodeForEnd:arrowEnd] != oldNode) {
		[self notifyDelegateOfChange];
	}
}

- (void)performActionMoveArrowEnd:(MAArrowEnd)arrowEnd forArrow:(MAArrow *)arrow toNode:(MANode *)node atAngle:(CGFloat)angle
{
	// Register undo
	MANode *oldNode = [arrow nodeForEnd:arrowEnd];
	CGFloat oldAngle = [arrow angleForEnd:arrowEnd];
	[self registerUndoActionMoveArrowEnd:arrowEnd forArrow:arrow oldNode:oldNode oldAngle:oldAngle];
	// Execute
	[arrow setNode:node forEnd:arrowEnd];
	[arrow setAngle:angle forEnd:arrowEnd];
	[self updateArrow:arrow];
	// Notify delegate
	if ([arrow nodeForEnd:arrowEnd] != oldNode) {
		[self notifyDelegateOfChange];
	}
}

#pragma mark Set Condition

- (void)performActionSetCondition:(MACondition *)condition forArrow:(MAArrow *)arrow
{
	// Register undo
	MACondition *oldCondition = arrow.condition;
	[[self prepareUndoOnSelf] performActionSetCondition:oldCondition forArrow:arrow];
	[self setActionNameForUndo:@"Edit Condition"];
	// Execute
	[self setCondition:condition forArrow:arrow];
	// Notify delegate
	[self notifyDelegateOfChange];
}

#pragma mark Set Actions

- (void)performActionSetActions:(NSArray *)actions forArrow:(MAArrow *)arrow
{
	// Register undo
	NSArray *oldActions = [arrow.actions copy];
	[[self prepareUndoOnSelf] performActionSetActions:oldActions forArrow:arrow];
	[self setActionNameForUndo:@"Edit Actions"];
	// Execute
	[self setActions:actions forArrow:arrow];
	// Notify delegate
	[self notifyDelegateOfChange];
}

#pragma mark - Utility

//- (void)resizeView
//{
//	CGSize superviewSize = [[self superview] bounds].size;
//	CGRect contentBounds = CGRectNull;
//	for (MANode *node in self.nodes) {
//		CGRect rect = CGRectAroundPoint(node.position, CGSizeMakeUniform(kNodeRadius*2));
//		contentBounds = CGRectUnion(contentBounds, rect);
//	}
//	if (CGRectIsNull(contentBounds)) return;
//	contentBounds = CGRectAddSizeWithAnchorPoint(contentBounds, CGSizeAdd(superviewSize, -10), CGPointMake(.5, .5));
//	// Resize
//	[self updateAllArrows];
//}

- (void)notifyDelegateOfChange
{
	if ([self.delegate respondsToSelector:@selector(graphDidChangeForGraphView:)]) {
		[self.delegate graphDidChangeForGraphView:self];
	}
}

- (void)doWithoutAnimation:(void(^)())block
{
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	block();
	[CATransaction commit];
}

- (id)prepareUndoOnSelf
{
	NSUndoManager *undo = [self undoManager];
	return [undo prepareWithInvocationTarget:self];
}

- (void)setActionNameForUndo:(NSString *)actionName
{
	NSUndoManager *undo = [self undoManager];
	if (![undo isUndoing]) [undo setActionName:actionName];
}

@end