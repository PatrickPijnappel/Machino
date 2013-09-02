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

#import "MACodeTemplate.h"

static NSString * const kCoderCodeMutableKey = @"codeMutable";
static NSString * const kCoderEditableRangesMutableKey = @"editableRangesMutable";
static NSString * const kCoderExtraRangesMutableKey = @"extraRangesMutable";
static NSString * const kCoderPendingKeyKey = @"pendingKey";
static NSString * const kCoderHasWrittenToLineKey = @"hasWrittenToLine";
static NSString * const kCoderIndentStringKey = @"indentString";
static NSString * const kCoderIndentLevelKey = @"indentLevel";

#pragma mark - Private Interface

@interface MACodeTemplate ()

@property (nonatomic, strong, readonly) NSMutableString *codeMutable;
@property (nonatomic, strong, readonly) NSMutableDictionary *editableRangesMutable;
@property (nonatomic, strong, readonly) NSMutableDictionary *extraRangesMutable;
@property (nonatomic, readwrite) NSUInteger indentLevel;
@property (nonatomic, copy) id<NSCopying> pendingKey;
@property (nonatomic) BOOL hasWrittenToLine;

@end

#pragma mark - Implementation

@implementation MACodeTemplate

#pragma mark - Initialization

- (id)init
{
    self = [super init];
    if (self) {
		_codeMutable = [NSMutableString string];
		_editableRangesMutable = [NSMutableDictionary dictionary];
		_extraRangesMutable = [NSMutableDictionary dictionary];
        _indentString = @"\t";
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _codeMutable = [coder decodeObjectForKey:kCoderCodeMutableKey];
		_editableRangesMutable = [coder decodeObjectForKey:kCoderEditableRangesMutableKey];
		_extraRangesMutable = [coder decodeObjectForKey:kCoderExtraRangesMutableKey];
		_indentString = [coder decodeObjectForKey:kCoderIndentStringKey];
		_indentLevel = [coder decodeIntegerForKey:kCoderIndentLevelKey];
		_pendingKey = [coder decodeObjectForKey:kCoderPendingKeyKey];
		_hasWrittenToLine = [coder decodeBoolForKey:kCoderHasWrittenToLineKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.codeMutable forKey:kCoderCodeMutableKey];
	[coder encodeObject:self.editableRangesMutable forKey:kCoderEditableRangesMutableKey];
	[coder encodeObject:self.extraRangesMutable forKey:kCoderExtraRangesMutableKey];
	[coder encodeObject:self.indentString forKey:kCoderIndentStringKey];
	[coder encodeInteger:self.indentLevel forKey:kCoderIndentLevelKey];
	[coder encodeObject:[self.pendingKey copyWithZone:nil] forKey:kCoderPendingKeyKey];
	[coder encodeBool:self.hasWrittenToLine forKey:kCoderHasWrittenToLineKey];
}

#pragma mark - General

- (NSString *)code
{
	return [self.codeMutable copy];
}

- (NSString *)codeInRange:(NSRange)range
{
	return [self.codeMutable substringWithRange:range];
}

#pragma mark - Editable ranges

- (NSDictionary *)editableRanges
{
	return [self.editableRangesMutable copy];
}

- (NSDictionary *)codeForEditableRanges
{
	NSMutableDictionary *codeDictionary = [NSMutableDictionary dictionary];
	for (id key in [self.editableRangesMutable keyEnumerator]) {
		NSRange range = [self.editableRangesMutable[key] rangeValue];
		codeDictionary[key] = [self.codeMutable substringWithRange:range];
	}
	return codeDictionary;
}

- (NSArray *)editableRangesInOrder
{
	NSArray *ranges = [self.editableRangesMutable allValues];
	NSArray *sortedRanges = [ranges sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		return [self compareRange:[obj1 rangeValue] toRange:[obj2 rangeValue]];
	}];
	return sortedRanges;
}

- (NSArray *)keysForEditableRangesInOrder
{
	NSArray *keys = [self.editableRangesMutable allKeys];
	NSArray *sortedKeys = [keys sortedArrayUsingComparator:^NSComparisonResult(id key1, id key2) {
		NSRange range1 = [self.editableRangesMutable[key1] rangeValue];
		NSRange range2 = [self.editableRangesMutable[key2] rangeValue];
		return [self compareRange:range1 toRange:range2];
	}];
	return sortedKeys;
}

- (NSComparisonResult)compareRange:(NSRange)range1 toRange:(NSRange)range2
{
	if (range1.location < range2.location) return NSOrderedAscending;
	if (range1.location > range2.location) return NSOrderedDescending;
	return NSOrderedSame;
}

- (NSRange)editableRangeForKey:(id)key
{
	NSValue *rangeObject = self.editableRangesMutable[key];
	if (!rangeObject) return NSMakeRange(NSNotFound, 0);
	return [rangeObject rangeValue];
}

- (NSString *)codeForEditableRangeWithKey:(id)key
{
	// Get range
	NSValue *rangeObject = self.editableRangesMutable[key];
	if (!rangeObject) return nil;
	NSRange range = [rangeObject rangeValue];
	// Return code
	return [self.codeMutable substringWithRange:range];
}

- (BOOL)setCode:(NSString *)newCodeForRange forEditableRangeWithKey:(id)key
{
	// Get range
	NSValue *rangeObject = self.editableRangesMutable[key];
	if (!rangeObject) return false;
	NSRange range = [rangeObject rangeValue];
	// Replace code
	[self.codeMutable replaceCharactersInRange:range withString:newCodeForRange];
	// Update range
	NSRange oldRange = range;
	range = NSMakeRange(oldRange.location, [newCodeForRange length]);
	self.editableRangesMutable[key] = [NSValue valueWithRange:range];
	// Update other ranges
	NSInteger lengthChange = range.length - oldRange.length;
	[self updateRanges:self.editableRangesMutable forLengthChange:lengthChange ofRange:oldRange withKey:key];
	[self updateRanges:self.extraRangesMutable forLengthChange:lengthChange ofRange:oldRange withKey:key];
	// Return
	return true;
}

- (void)updateRanges:(NSMutableDictionary *)ranges forLengthChange:(NSInteger)lengthChange ofRange:(NSRange)oldRange withKey:(id)changedRangeKey
{
	for (id key in [[ranges copy] keyEnumerator]) { // Use copy to allow modification
		if ([key isEqual:changedRangeKey]) continue;
		NSRange range = [ranges[key] rangeValue];
		if (NSMaxRange(oldRange) <= range.location) { // Range is after changed range
			range.location += lengthChange;
		} else if (oldRange.location < NSMaxRange(range)) { // Range intersects with changed range
			if (NSMaxRange(oldRange) <= NSMaxRange(range)) {
				range.length += lengthChange;
			} else {
				NSAssert(false, @"Invalidly intersecting ranges in code, unable to properly adjust range.");
			}
		}
		ranges[key] = [NSValue valueWithRange:range];
	}
}

- (BOOL)canSubstituteOldRangeWithKey:(id)key forNewRangeWithKey:(id)otherKey
{
	return NO;
}

- (BOOL)canMergeRangeWithKey:(id)key withOtherRangeWithKey:(id)otherKey
{
	return NO;
}

#pragma mark - Extra ranges

- (NSDictionary *)extraRanges
{
	return [self.extraRangesMutable copy];
}

- (NSRange)extraRangeForKey:(id)key
{
	return [self.extraRangesMutable[key] rangeValue];
}

- (void)addExtraRange:(NSRange)range forKey:(id)key
{
	self.extraRangesMutable[key] = [NSValue valueWithRange:range];
}

#pragma mark - Writing functions

- (void)doIndented:(void(^)())block
{
	self.indentLevel++;
	block();
	self.indentLevel--;
}

- (void)write:(NSString *)format, ...
{
	// Get string
	va_list args;
	va_start(args, format);
	NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	// Append
	[self.codeMutable appendString:string];
	self.hasWrittenToLine = YES;
}

- (void)writeLine:(NSString *)format, ...
{
	// Get string
	va_list args;
	va_start(args, format);
	NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	// Write new line
	if (self.hasWrittenToLine) {
		[self.codeMutable appendString:@"\n"];
	}
	// Write indent
	for (int i=0; i<self.indentLevel; i++) {
		[self.codeMutable appendString:self.indentString];
	}
	// Write code
	[self.codeMutable appendString:string];
	self.hasWrittenToLine = YES;
}

- (void)editableRange:(void(^)())block withKey:(id<NSCopying>)key
{
	[self beginEditableRangeWithKey:key];
	block();
	[self endEditableRange];
}

- (void)indentedEditableRange:(void(^)())block withKey:(id<NSCopying>)key
{
	self.indentLevel++;
	[self editableRange:block withKey:key];
	self.indentLevel--;
}

- (void)writeEditable:(NSString *)string withKey:(id<NSCopying>)key
{
	[self beginEditableRangeWithKey:key];
	[self write:@"%@", string];
	[self endEditableRange];
}

- (void)writeEditableLine:(NSString *)string withKey:(id<NSCopying>)key
{
	[self beginEditableRangeWithKey:key];
	[self writeLine:@"%@", string];
	[self endEditableRange];
}

#pragma mark - Utility

- (void)beginEditableRangeWithKey:(id<NSCopying>)key
{
	if (self.pendingKey) [self endEditableRange];
	NSRange range = NSMakeRange([self.codeMutable length], 0);
	self.editableRangesMutable[key] = [NSValue valueWithRange:range];
	self.pendingKey = key;
}

- (void)endEditableRange
{
	if (!self.pendingKey) return;
	NSRange range = [self.editableRangesMutable[self.pendingKey] rangeValue];
	range.length = [self.codeMutable length] - range.location;
	self.editableRangesMutable[self.pendingKey] = [NSValue valueWithRange:range];
	self.pendingKey = nil;
}

@end
