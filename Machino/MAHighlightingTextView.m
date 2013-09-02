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

#import "MAHighlightingTextView.h"
#import "Utility.h"

@implementation MAHighlight

@end

@interface MAHighlightingTextView ()

@property (nonatomic, strong) NSTrackingArea *trackingArea;

@end

@implementation MAHighlightingTextView

- (void)awakeFromNib
{
	[NSEvent setMouseCoalescingEnabled:YES];
	[self updateTrackingAreas];
}

- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag
{
	[super setSelectedRange:charRange affinity:affinity stillSelecting:stillSelectingFlag];
	[[self highlightingDelegate] selectionChangedToRange:charRange stillSelecting:stillSelectingFlag forTextView:self];
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

- (void)mouseMoved:(NSEvent *)event
{
	if ([self.highlightingDelegate respondsToSelector:@selector(hoverLocationChangedToCharacterIndex:forTextView:)]) {
		[self.highlightingDelegate hoverLocationChangedToCharacterIndex:[self hoveredCharacterIndex] forTextView:self];
	}
}

- (NSUInteger)hoveredCharacterIndex
{
	return [self characterIndexForPoint:[NSEvent mouseLocation]];
}

- (void)drawViewBackgroundInRect:(NSRect)rect
{
	[super drawViewBackgroundInRect:rect];
	// Draw all hightlight
	NSArray *highlights = [self.highlightingDelegate highlightsForTextView:self];
	for (MAHighlight *highlight in highlights) {
		// Ensure the range is within the full text
		NSRange fullRange = NSMakeRange(0, [[self textStorage] length]);
		NSRange range = NSRangeIntersection(fullRange, highlight.range);
		// Get rect for range, set color & draw
		NSRect rect = [self highlightRectForRange:range];
		[highlight.color set];
		[NSBezierPath fillRect:rect];
	}
}

- (NSRect)highlightRectForRange:(NSRange)range
{
	NSRange glyphRange = [[self layoutManager] glyphRangeForCharacterRange:range actualCharacterRange:NULL];
	NSRect glyphBounds = [[self layoutManager] boundingRectForGlyphRange:glyphRange inTextContainer:[self textContainer]];
	CGFloat width = NSWidth([self bounds]);
	NSPoint containerOrigin = [self textContainerOrigin];
	return NSMakeRect(0, glyphBounds.origin.y+containerOrigin.y, width, glyphBounds.size.height);
}
@end
