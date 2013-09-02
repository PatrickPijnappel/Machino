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

#import <Cocoa/Cocoa.h>

@protocol MAHighlightingTextViewDelegate;

@interface MAHighlight : NSObject

@property (nonatomic) NSRange range;
@property (nonatomic, strong) NSColor *color;

@end

@interface MAHighlightingTextView : NSTextView

@property (nonatomic, weak) IBOutlet id<MAHighlightingTextViewDelegate> highlightingDelegate;

- (NSUInteger)hoveredCharacterIndex;

@end

@protocol MAHighlightingTextViewDelegate <NSObject>

- (NSArray *)highlightsForTextView:(MAHighlightingTextView *)textView;
- (void)selectionChangedToRange:(NSRange)range stillSelecting:(BOOL)stillSelecting forTextView:(MAHighlightingTextView *)textView;
- (void)hoverLocationChangedToCharacterIndex:(NSUInteger)characterIndex forTextView:(MAHighlightingTextView *)textView;

@end