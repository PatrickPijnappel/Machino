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

@class MANodeGroup;
@class CATextLayer;

@interface MANode : NSObject <NSCoding>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong, readonly) NSArray *arrows; // Automatically managed when setting arrow's source/target
@property (nonatomic) CGPoint position;
@property (nonatomic) BOOL isInitialState;
@property (nonatomic, strong) CALayer *layer;
@property (nonatomic, strong) CALayer *secondBorderLayer;
@property (nonatomic, strong) CATextLayer *textLayer;

- (NSArray *)findConnectedNodes;
- (NSArray *)findConnectedNodesIgnoringArrows:(NSArray *)ignoredArrows;

@end
