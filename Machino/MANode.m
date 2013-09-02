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

#import "Graph.h"
#import "MANodeInternal.h"

static NSString * const kCoderNameKey = @"name";
static NSString * const kCoderArrowsKey = @"arrows";
static NSString * const kCoderPositionKey = @"position";
static NSString * const kCoderIsInitialStateKey = @"isInitialStateKey";

@implementation MANode

- (NSString *)description
{
	return self.name;
}

- (NSArray *)arrows
{
	return [self.arrowsMutable copy];
}

#pragma mark - Initialization

- (id)init
{
    self = [super init];
    if (self) {
        _arrowsMutable = [NSMutableArray array];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
		_name = [coder decodeObjectForKey:kCoderNameKey];
		_arrowsMutable = [coder decodeObjectForKey:kCoderArrowsKey];
		_position = [coder decodePointForKey:kCoderPositionKey];
		_isInitialState = [coder decodeBoolForKey:kCoderIsInitialStateKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.name forKey:kCoderNameKey];
	[coder encodeObject:self.arrowsMutable forKey:kCoderArrowsKey];
	[coder encodePoint:self.position forKey:kCoderPositionKey];
	[coder encodeBool:self.isInitialState forKey:kCoderIsInitialStateKey];
}

#pragma mark - General

- (NSArray *)findConnectedNodes
{
	return [self findConnectedNodesIgnoringArrows:nil];
}

- (NSArray *)findConnectedNodesIgnoringArrows:(NSArray *)ignoredArrows
{
	NSMutableArray *nodes = [NSMutableArray arrayWithObject:self];
	[self addConnectedNodesToArray:nodes ignoringArrows:ignoredArrows];
	return nodes;
}

- (void)addConnectedNodesToArray:(NSMutableArray *)array ignoringArrows:(NSArray *)ignoredArrows
{
	for (MAArrow *arrow in self.arrows) {
		if ([ignoredArrows containsObject:arrow]) continue;
		// Get node on arrow that isn't self
		MANode *otherNode = nil;
		if (arrow.targetNode == self && arrow.sourceNode != self) otherNode = arrow.sourceNode;
		if (arrow.sourceNode == self && arrow.targetNode != self) otherNode = arrow.targetNode;
		// Add that node and it's connected nodes
		if (otherNode && ![array containsObject:otherNode]) {
			[array addObject:otherNode];
			[otherNode addConnectedNodesToArray:array ignoringArrows:ignoredArrows];
		}
	}
}

@end
