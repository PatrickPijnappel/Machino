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

@class MANode;
@class MACondition;
@class MAAction;
@class MAStateMachineCodeTemplate;
@class MAHighlightingTextView;
@protocol MACodeControllerDelegate;

@interface MACodeController : NSObject

@property (nonatomic, weak) IBOutlet id<MACodeControllerDelegate> delegate;
@property (nonatomic, assign) IBOutlet NSScrollView *codeScrollView;
@property (nonatomic, assign) IBOutlet MAHighlightingTextView *codeTextView;
@property (nonatomic, strong, readonly) MAStateMachineCodeTemplate *codeTemplate;
@property (nonatomic, strong) id executionItem;

- (void)updateCodeForStates:(NSArray *)states transitions:(NSArray *)transitions;
- (NSString *)code;
- (NSString *)codeWithLogging;
- (id)objectForSymbolWithID:(UInt64)symbolID;
- (void)setCodeTemplate:(MAStateMachineCodeTemplate *)codeTemplate mergeOldCode:(BOOL)mergeOldCode;
// Highlighting & click
- (void)setHoveredItemsToItems:(NSArray *)item;
- (void)scrollToItem:(id)item;

@end

@protocol MACodeControllerDelegate <NSObject>

- (void)codeWasEditedForCodeController:(MACodeController *)codeController;
- (void)codeController:(MACodeController *)codeController didSetHoveredItems:(NSArray *)hoveredItems;

@end