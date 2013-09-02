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

#import <Foundation/Foundation.h>

@class MANode;

@interface MACodeTemplate : NSObject <NSCoding>

@property (nonatomic, copy) NSString *indentString;
@property (nonatomic, readonly) NSUInteger indentLevel;

// General
- (NSString *)code;
- (NSString *)codeInRange:(NSRange)range;
// Editable ranges
- (NSDictionary *)editableRanges;
- (NSDictionary *)codeForEditableRanges;
- (NSArray *)editableRangesInOrder;
- (NSArray *)keysForEditableRangesInOrder;
- (NSRange)editableRangeForKey:(id)key;
- (NSString *)codeForEditableRangeWithKey:(id)key;
- (BOOL)setCode:(NSString *)code forEditableRangeWithKey:(id)key;
// Key substitution/merger
- (BOOL)canSubstituteOldRangeWithKey:(id)key forNewRangeWithKey:(id)otherKey; // Should be overriden
- (BOOL)canMergeRangeWithKey:(id)key withOtherRangeWithKey:(id)otherKey; // Should be overriden
// Extra range
- (NSDictionary *)extraRanges;
- (NSRange)extraRangeForKey:(id)key;
- (void)addExtraRange:(NSRange)range forKey:(id)key;
// Writing
- (void)doIndented:(void(^)())block;
- (void)write:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)writeLine:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2); // Writes on a new line (so new is before string)
- (void)editableRange:(void(^)())block withKey:(id<NSCopying>)key;
- (void)indentedEditableRange:(void(^)())block withKey:(id<NSCopying>)key;
- (void)writeEditable:(NSString *)string withKey:(id<NSCopying>)key;
- (void)writeEditableLine:(NSString *)string withKey:(id<NSCopying>)key;

@end
