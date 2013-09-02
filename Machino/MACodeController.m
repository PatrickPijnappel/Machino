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

#import "MACodeController.h"
#import "MAStateMachineCodeTemplate.h"
#import "MAHighlightingTextView.h"
#import "MASymbolManager.h"
#import "Graph.h"
#import "Utility.h"

static NSString * const kIndentString = @"  ";

#pragma mark - Private Interface

@interface MACodeController () <NSTextViewDelegate, NSTextStorageDelegate, MAHighlightingTextViewDelegate>

@property (nonatomic, strong, readwrite) MAStateMachineCodeTemplate *codeTemplate;
@property (nonatomic, strong) NSDictionary *uneditableTextAttributes;
@property (nonatomic, strong) NSDictionary *editableTextAttributes;
@property (nonatomic) BOOL suppressTextStorageEditEvents;
@property (nonatomic) BOOL isDelegateEditingTextView;
@property (nonatomic) NSValue *intendedSelectedRange;
@property (nonatomic, strong, readonly) NSMutableArray *hoveredItems;

@end

#pragma mark - Implementation

@implementation MACodeController

- (void)awakeFromNib
{
	self->_hoveredItems = [NSMutableArray array];
	// Listen to scroll view notification
	[self.codeScrollView setPostsBoundsChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scrollViewContentViewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:[self.codeScrollView contentView]];
	// Text view properties
	[self.codeTextView setTextContainerInset:NSMakeSize(6, 10)];
	[self.codeTextView setEnabledTextCheckingTypes:0];
	// To make it not wrap horizontally
	[[self.codeTextView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
	[[self.codeTextView textContainer] setWidthTracksTextView:NO];
	// Initialize attributes
	NSFont *font = [NSFont fontWithName:@"Monaco" size:10];
	self.uneditableTextAttributes = @{ NSFontAttributeName : font, NSForegroundColorAttributeName : [NSColor colorWithCalibratedWhite:0 alpha:.5] };
	self.editableTextAttributes = @{ NSFontAttributeName : font, NSForegroundColorAttributeName : [NSColor blackColor] };
	[self.codeTextView setTypingAttributes:self.editableTextAttributes];
	// Set delegate
	[self.codeTextView setDelegate:self];
	[[self.codeTextView textStorage] setDelegate:self];
	// Add inital code
	[self updateCodeForStates:nil transitions:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Highlighting

- (void)setExecutionItem:(id)executionItem
{
	if (_executionItem == executionItem) return;
	_executionItem = executionItem;
	[self.codeTextView setNeedsDisplay:YES];
}

- (void)setHoveredItemsToItems:(NSArray *)items
{
	if ([items isEqual:self.hoveredItems]) return;
	if ([items count] == 0 && [self.hoveredItems count] == 0) return;
	[self.hoveredItems removeAllObjects];
	if (items) [self.hoveredItems setArray:items];
	[self.codeTextView setNeedsDisplay:YES];
}

- (void)setHoveredItemsBasedOnRange:(NSRange)range
{
	// Get new hovered items
	NSMutableArray *newHoveredItems = [NSMutableArray array];
	NSArray *allSymbolObjects = [self.codeTemplate.symbols allObjects];
	for (id object in allSymbolObjects) {
		NSRange itemRange = [self getRangeForItem:object];
		if (range.location != NSNotFound && NSRangeIntersectsRange(range, itemRange)) {
			[newHoveredItems addObject:object];
		}
	}
	// If changed, set & update
	if (![self.hoveredItems isEqual:newHoveredItems]) {
		[self.hoveredItems setArray:newHoveredItems];
		[self.codeTextView setNeedsDisplay:YES];
		[self.delegate codeController:self didSetHoveredItems:[self.hoveredItems copy]];
	}
}

- (void)selectionChangedToRange:(NSRange)range stillSelecting:(BOOL)stillSelecting forTextView:(MAHighlightingTextView *)textView
{
	[self setHoveredItemsBasedOnRange:range];
}

- (NSArray *)highlightsForTextView:(MAHighlightingTextView *)textView
{
	NSMutableArray *highlights = [NSMutableArray array];
	// Hovered items
	for (id item in self.hoveredItems) {
		NSRange range = [self getRangeForItem:item];
		if (range.location != NSNotFound) {
			MAHighlight *highlight = [[MAHighlight alloc] init];
			highlight.range = range;
			highlight.color = [NSColor colorWithCalibratedRed:0 green:.5 blue:1 alpha:.05];
			[highlights addObject:highlight];
		}
	}
	// Execution item
	if (self.executionItem) {
		NSRange range = [self getRangeForItem:self.executionItem];
		if (range.location != NSNotFound) {
			MAHighlight *highlight = [[MAHighlight alloc] init];
			highlight.range = range;
			highlight.color = [[NSColor yellowColor] colorWithAlphaComponent:.5];
			[highlights addObject:highlight];
		}
	}
	// Return
	return highlights;
}

- (void)hoverLocationChangedToCharacterIndex:(NSUInteger)characterIndex forTextView:(MAHighlightingTextView *)textView
{
	NSRange range = NSMakeRange(characterIndex, 0);
	[self setHoveredItemsBasedOnRange:range];
}

- (void)scrollViewContentViewBoundsDidChange:(NSNotification *)notification
{
	NSPoint mousePosition = [[self.codeScrollView window] convertScreenToBase:[NSEvent mouseLocation]];
	NSRect scrollViewRect = [self.codeScrollView convertRect:[self.codeScrollView bounds] toView:nil];
	if (NSPointInRect(mousePosition, scrollViewRect)) {
		NSRange range = NSMakeRange([self.codeTextView hoveredCharacterIndex], 0);
		[self setHoveredItemsBasedOnRange:range];
	}
}

- (NSRange)getRangeForItem:(id)item
{
	if ([item isKindOfClass:[MACondition class]]) return [self.codeTemplate rangeForCondition:item];
	if ([item isKindOfClass:[MAAction class]]) return [self.codeTemplate rangeForAction:item];
	return NSMakeRange(NSNotFound, 0);
}

- (void)scrollToItem:(id)item
{
	NSRange range = [self getRangeForItem:item];
	if (range.location != NSNotFound) {
		// Find rect for item
		NSLayoutManager *layoutManager = [self.codeTextView layoutManager];
		NSTextContainer *textContainer = [self.codeTextView textContainer];
		NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
		NSRect rect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
		CGPoint origin = [self.codeTextView textContainerOrigin];
		rect = NSOffsetRect(rect, origin.x, origin.y);
		// Scroll to rect
		NSPoint rectCenter = NSMakePoint(NSMidX(rect), NSMidY(rect));
		[DuxScrollViewAnimation animatedScrollPointToCenter:rectCenter inScrollView:self.codeScrollView];
	}
}

#pragma mark - Template

- (void)setCodeTemplate:(MAStateMachineCodeTemplate *)codeTemplate mergeOldCode:(BOOL)mergeOldCode
{
	if (self.codeTemplate == codeTemplate) return;
	// Prepare
	if (mergeOldCode) {
		[self mergeCodeFromOldTemplate:self.codeTemplate intoNewTemplate:codeTemplate];
	}
	// Set
	self.codeTemplate = codeTemplate;
}

- (void)updateCodeForStates:(NSArray *)states transitions:(NSArray *)transitions
{
	self.codeTemplate = [self codeTemplateForStates:states transitions:transitions insertLoggingCode:NO];
	// Apply attributes
	NSString *code = [self.codeTemplate code];
	NSMutableAttributedString *codeAttributed = [[NSMutableAttributedString alloc] initWithString:code attributes:self.uneditableTextAttributes];
	NSArray *editableRanges = [[self.codeTemplate editableRanges] allValues];
	for (NSValue *rangeObject in editableRanges) {
		NSRange range = [rangeObject rangeValue];
		[codeAttributed setAttributes:self.editableTextAttributes range:range];
	}
	// Set code
	self.suppressTextStorageEditEvents = YES;
	CGPoint scrollOffset = [self.codeScrollView documentVisibleRect].origin;
	[[self.codeTextView textStorage] setAttributedString:codeAttributed];
	[[self.codeScrollView documentView] scrollPoint:scrollOffset];
	self.suppressTextStorageEditEvents = NO;
}

- (MAStateMachineCodeTemplate *)codeTemplateForStates:(NSArray *)states transitions:(NSArray *)transitions insertLoggingCode:(BOOL)insertLoggingCode
{
	MAStateMachineCodeTemplate *oldTemplate = self.codeTemplate;
	MAStateMachineCodeTemplate *template = [[MAStateMachineCodeTemplate alloc] init];;
	template.states = states;
	template.transitions = transitions;
	template.options = insertLoggingCode ? MAInsertLoggingCode : 0;
	template.indentString = kIndentString;
	template.symbols = oldTemplate.symbols; // Reuse symbols to persist id's
	[template generate];
	[self mergeCodeFromOldTemplate:oldTemplate intoNewTemplate:template];
	return template;
}

- (void)mergeCodeFromOldTemplate:(MACodeTemplate *)oldTemplate intoNewTemplate:(MACodeTemplate *)newTemplate
{
	if (!oldTemplate) return;
	// Prepare
	NSArray *sortedOldKeys = [oldTemplate keysForEditableRangesInOrder];
	NSArray *sortedNewKeys = [newTemplate keysForEditableRangesInOrder];
	NSDictionary *oldCode = [oldTemplate codeForEditableRanges];
	// For all editable pieces of code
	id previousKey = nil;
	id orphanedCodeKey = nil;
	for (id key in sortedOldKeys) {
		// Get code, and prepend any orphaned code
		NSString *code = oldCode[key];
		if (orphanedCodeKey) {
			BOOL canMerge = [newTemplate canMergeRangeWithKey:orphanedCodeKey withOtherRangeWithKey:key];
			if (canMerge) code = [oldCode[orphanedCodeKey] stringByAppendingString:code];
			orphanedCodeKey = nil;
		}
		// Try inserting the old code in the spot with the same key
		BOOL simpleInsert = [newTemplate setCode:code forEditableRangeWithKey:key];
		if (!simpleInsert) { // The range with that key does not exist anymore in the template
			// See if it's worth keeping
			NSString *trimmedCode = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if ([trimmedCode length] == 0) continue;
			// See if there is an unused key after the previously used one
			NSInteger indexAfterPrevious = previousKey ? [sortedNewKeys indexOfObject:previousKey]+1 : 0;
			if (indexAfterPrevious < [sortedNewKeys count]) {
				id nextKey = sortedNewKeys[indexAfterPrevious];
				BOOL canSubstitute = [newTemplate canSubstituteOldRangeWithKey:key forNewRangeWithKey:nextKey];
				if (![sortedOldKeys containsObject:nextKey] && canSubstitute) { // If it's not used we put the code there
					[newTemplate setCode:code forEditableRangeWithKey:nextKey];
					previousKey = nextKey;
					continue;
				}
			}
			// If not, append the code to the previously added part
			if (previousKey && [newTemplate canMergeRangeWithKey:previousKey withOtherRangeWithKey:key]) {
				NSString *previousCode = [newTemplate codeForEditableRangeWithKey:previousKey];
				code = [previousCode stringByAppendingString:code];
				// Set
				[newTemplate setCode:code forEditableRangeWithKey:previousKey];
			} else {
				orphanedCodeKey = key; // No previously added code, mark as orphaned and let the next piece try toj prepend it
			}
		} else {
			previousKey = key;
		}
	}
}

- (NSString *)code
{
	return [self.codeTextView string];
}

- (NSString *)codeWithLogging
{
	NSArray *states = [self.codeTemplate states];
	NSArray *transitions = [self.codeTemplate transitions];
	MAStateMachineCodeTemplate *codeTemplate = [self codeTemplateForStates:states transitions:transitions insertLoggingCode:YES];
	return [codeTemplate code];
}

- (id)objectForSymbolWithID:(UInt64)symbolID
{
	return [self.codeTemplate objectForSymbolWithID:symbolID];
}

#pragma - Immutable Parts

- (void)textDidChange:(NSNotification *)notification
{
	[self.delegate codeWasEditedForCodeController:self];
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRanges:(NSArray *)affectedRanges replacementStrings:(NSArray *)replacementStrings
{
	if (self.isDelegateEditingTextView) return YES;
	// Let undo/redo work unmodified
	if ([[textView undoManager] isUndoing] || [[textView undoManager] isRedoing]) {
		[self replaceTemplateCodeInRanges:affectedRanges withStrings:replacementStrings];
		return YES;
	}
	// Screen edits
	[self screenTextChangeInRanges:&affectedRanges replacementStrings:&replacementStrings];
	affectedRanges = [affectedRanges copy];
	replacementStrings = [replacementStrings copy];
	// Place edited change
	if ([affectedRanges count] > 0) {
		self.isDelegateEditingTextView = YES;
		if ([textView shouldChangeTextInRanges:affectedRanges replacementStrings:replacementStrings]) {
			// Replace text in template (do before changing text view because the latter might call all kinds of delegates and such)
			[self replaceTemplateCodeInRanges:affectedRanges withStrings:replacementStrings];
			// Replace text in text view
			NSInteger count = [affectedRanges count];
			NSInteger lengthDelta = 0;
			for (int i=0; i<count; i++) {
				NSRange range = [affectedRanges[i] rangeValue];
				range.location -= lengthDelta;
				NSString *string = replacementStrings[i];
				NSAttributedString *stringAttributed = [[NSAttributedString alloc] initWithString:string attributes:self.editableTextAttributes];
				[[self.codeTextView textStorage] replaceCharactersInRange:range withAttributedString:stringAttributed];
				lengthDelta += range.length;
			}
			// Notify of text change
			[textView didChangeText];
		}
		self.isDelegateEditingTextView = NO;
	}
	// Discard original change
	return NO;
}

// Note: Will discard any change that is not completely contained within one editable range
- (void)replaceTemplateCodeInRanges:(NSArray *)ranges withStrings:(NSArray *)strings
{
	// Get the new code parts for each editable ranges
	// We need to do this beforehand, because replacing a range will shift the others making them invalid.
	NSMutableDictionary *newCodeParts = [NSMutableDictionary dictionary];
	NSDictionary *editableRanges = [self.codeTemplate editableRanges];
	NSUInteger count = [ranges count];
	for (int i=0; i<count; i++) {
		NSRange range = [ranges[i] rangeValue];
		NSString *string = strings[i];
		// Find editable range
		for (id key in [editableRanges keyEnumerator]) {
			NSRange editableRange = [editableRanges[key] rangeValue];
			if (NSRangeContainsRange(editableRange, range)) {
				// Modify code and store for key
				NSString *code = [self.codeTemplate codeForEditableRangeWithKey:key];
				range.location -= editableRange.location;
				code = [code stringByReplacingCharactersInRange:range withString:string];
				newCodeParts[key] = code;
				break;
			}
		}
	}
	// Replace code parts in template
	for (id key in [newCodeParts keyEnumerator]) {
		[self.codeTemplate setCode:newCodeParts[key] forEditableRangeWithKey:key];
	}
}


// Screening rules:
// Any edit completely within an editable range is accepted
// Any edit completely within an immutable range is rejected
// Other edits with mixed ranges (pastes/drops) will be rejected
- (void)screenTextChangeInRanges:(NSArray **)affectedRanges replacementStrings:(NSArray **)replacementStrings
{
	NSMutableArray *rangesOut = [NSMutableArray array];
	NSMutableArray *stringsOut = [NSMutableArray array];
	// Go through all ranges/strings
	NSUInteger count = [*affectedRanges count];
	for (NSInteger i=0; i<count; i++) {
		NSRange range = [(*affectedRanges)[i] rangeValue];
		NSString *replacementString = (*replacementStrings)[i];
		// Handle the exception that you should be able to copy over a trailing immutable newline
		NSString *oldString = [[self code] substringWithRange:range];
		NSString *newline = @"\n";
		if ([oldString endsWith:newline]) {
			range.length -= [newline length];
			if ([replacementString endsWith:newline]) {
				NSUInteger endIndex = [replacementString length]-[newline length];
				replacementString = [replacementString substringToIndex:endIndex];
			}
		}
		// Get intersected editableRanges
		NSArray *editableRanges = [self editableRangesIntersectingWithRange:range];
		// If only in immutabe range, reject change
		if ([editableRanges count] == 0) continue;
		// If only in editable range, accept change
		if ([editableRanges count] == 1) {
			NSRange editableRange = [editableRanges[0] rangeValue];
			// Check range
			if (NSRangeContainsRange(editableRange, range)) {
				[rangesOut addObject:[NSValue valueWithRange:range]];
				[stringsOut addObject:replacementString];
				continue;
			}
		}
	}
	// Set out
	*affectedRanges = rangesOut;
	*replacementStrings = stringsOut;
}

- (NSArray *)editableRangesIntersectingWithRange:(NSRange)range
{
	NSMutableArray *result = [NSMutableArray array];
	NSArray *editableRanges = [self.codeTemplate editableRangesInOrder];
	for (NSValue *editableRangeObject in editableRanges) {
		NSRange editableRange = [editableRangeObject rangeValue];
		BOOL intersectsRange = NSRangeIntersectsRange(range, editableRange) || (range.length == 0 && NSRangeContainsValue(editableRange, range.location));
		if (intersectsRange) {
			[result addObject:editableRangeObject];
		}
	}
	return result;
}

#pragma - Editor Action Overrides

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
	if (commandSelector == @selector(insertTab:)) {
		[textView insertText:kIndentString];
		return YES;
	}
	if (commandSelector == @selector(insertNewline:)) {
		[self insertNewLineWithProperIndentForTextView:textView];
		return YES;
	}
	return NO;
}

- (void)insertNewLineWithProperIndentForTextView:(NSTextView *)textView
{
	NSRange selection = [textView selectedRange];
	if (selection.location != NSNotFound) {
		// Get stuff
		NSString *text = [textView string];
		NSRange lineRange = [text lineRangeForRange:selection];
		lineRange.length = selection.location-lineRange.location;
		NSString *lines = [text substringWithRange:lineRange];
		// Determine proper indent
		int indent = [self indentOfText:lines];
		if (selection.length == 0) {
			NSString *trimmedLine = [lines stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if ([trimmedLine length] > 0) {
				unichar lastChar = [trimmedLine characterAtIndex:[trimmedLine length]-1];
				if (lastChar == '{') indent += 2;
			}
		}
		// Construct and insert newline + indent
		NSMutableString *str = [NSMutableString stringWithString:@"\n"];
		for (int i=0; i<indent; i++) [str appendString:@" "];
		[textView insertText:str];
	}
}

- (int)indentOfText:(NSString *)text
{
	int indent = 0;
	for (int i = 0; i < [text length]; i++) {
		unichar c = [text characterAtIndex:i];
		if (c == ' ') indent++;
		else if (c == '\t') indent += [kIndentString length];
		else break;
	}
	return indent;
}

@end
