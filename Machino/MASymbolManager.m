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

#import "MASymbolManager.h"

static NSString * const kValidSymbolCharactersString = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";
// Coder keys
static NSString * const kCoderSymbolIDKey = @"symbolID";
static NSString * const kCoderObjectKey = @"object";
static NSString * const kCoderObjectNameKey = @"objectName";
static NSString * const kCoderNameFormatKey = @"nameFormat";
static NSString * const kCoderSymbolNameKey = @"symbolName";
static NSString * const kCoderMaximumSymbolIDKey = @"maximumSymbolID";
static NSString * const kCoderSymbolsKey = @"symbols";
static NSString * const kCoderReservedNamesKey = @"reservedNames";

#pragma mark - Private Class - MASymbol

@interface MASymbol : NSObject <NSCoding>

@property (nonatomic) UInt64 symbolID;
@property (nonatomic, weak) id object;
@property (nonatomic, copy) NSString *objectName;
@property (nonatomic, copy) NSString *nameFormat; // Format to apply on the object name before generating its symbol names
@property (nonatomic, copy) NSString *symbolName;

@end

@implementation MASymbol

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _symbolID = [coder decodeInt64ForKey:kCoderSymbolIDKey];
		_object = [coder decodeObjectForKey:kCoderObjectKey];
		_objectName = [coder decodeObjectForKey:kCoderObjectNameKey];
		_nameFormat = [coder decodeObjectForKey:kCoderNameFormatKey];
		_symbolName = [coder decodeObjectForKey:kCoderSymbolNameKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt64:self.symbolID forKey:kCoderSymbolIDKey];
	[coder encodeConditionalObject:self.object forKey:kCoderObjectKey];
	[coder encodeObject:self.objectName forKey:kCoderObjectNameKey];
	[coder encodeObject:self.nameFormat forKey:kCoderNameFormatKey];
	[coder encodeObject:self.symbolName forKey:kCoderSymbolNameKey];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"[%lli] %@", self.symbolID, self.symbolName];
}

@end

#pragma mark - Private Interface

@interface MASymbolManager ()

@property (nonatomic, strong, readonly) NSMutableArray *symbols;
@property (nonatomic, strong, readonly) NSMutableArray *reservedNames;

@end

@implementation MASymbolManager

- (NSCharacterSet *)validSymbolCharacters
{
	return [NSCharacterSet characterSetWithCharactersInString:kValidSymbolCharactersString];
}

- (void)setMaximumSymbolID:(UInt64)maximumSymbolID
{
	if (_maximumSymbolID == maximumSymbolID) return;
	_maximumSymbolID = maximumSymbolID;
	// Update
	[self regenerateSymbolIDs];
}

#pragma mark - Initialization

- (id)init
{
    self = [super init];
    if (self) {
		_maximumSymbolID = UINT64_MAX;
		_symbols = [NSMutableArray array];
		_reservedNames = [NSMutableArray array];
		srandom((int)time(NULL));
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
		_maximumSymbolID = [coder decodeInt64ForKey:kCoderMaximumSymbolIDKey];
        _symbols = [coder decodeObjectForKey:kCoderSymbolsKey];
		_reservedNames = [coder decodeObjectForKey:kCoderReservedNamesKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt64:self.maximumSymbolID forKey:kCoderMaximumSymbolIDKey];
	[coder encodeObject:self.symbols forKey:kCoderSymbolsKey];
	[coder encodeObject:self.reservedNames forKey:kCoderReservedNamesKey];
}

#pragma mark - Core

- (void)generateSymbolNames
{
	NSMutableSet *names = [NSMutableSet setWithArray:self.reservedNames];
	for (MASymbol *symbol in self.symbols) {
		if (!symbol.objectName) continue;
		NSString *name = symbol.nameFormat ? [NSString stringWithFormat:symbol.nameFormat, symbol.objectName] : symbol.objectName;
		name = [self validSymbolNameFromName:name];
		name = [self makeName:name differentFromNamesInSet:names];
		[names addObject:name];
		symbol.symbolName = name;
	}
}

- (void)regenerateSymbolIDs
{
	for (MASymbol *symbol in self.symbols) {
		symbol.symbolID = [self generateUniqueSymbolID];
	}
}

- (NSString *)validSymbolNameFromName:(NSString *)name
{
	NSMutableString *str = [name mutableCopy];
	// Replace special characters outside ascii (with substitution, e.g. é becomes e).
	NSData *tmp = [str dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	str = [[NSMutableString alloc] initWithData:tmp encoding:NSASCIIStringEncoding];
	// Remove remaining illegal characters expect whitespace
	NSCharacterSet *validSymbolCharacters = [self validSymbolCharacters];
	NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
	for (int i=0; i<[str length]; i++) {
		unichar c = [str characterAtIndex:i];
		if (![validSymbolCharacters characterIsMember:c] && ![whitespaceCharacterSet characterIsMember:c]) {
			[str replaceCharactersInRange:NSMakeRange(i, 1) withString:@" "];
		}
	}
	// Remove whitespace and apply camelCase.
	NSArray *parts = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	str = [NSMutableString string];
	for (NSString *part in parts) {
		if ([part length] == 0) continue;
		if ([str length] > 0) {
			[str appendString:[[part substringToIndex:1] uppercaseString]];
			[str appendString:[part substringFromIndex:1]];
		} else {
			[str appendString:part]; // First part is not capitalized
		}
	}
	// Ensure it's not empty
	if ([str length] == 0) [str appendString:@"_"];
	// Ensure it doesn't start with a digit
	NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
	if ([digits characterIsMember:[str characterAtIndex:0]]) {
		[str insertString:@"_" atIndex:0];
	}
	// Return
	return [str copy];
}

- (NSString *)makeName:(NSString *)name differentFromNamesInSet:(NSSet *)set
{
	if (![set containsObject:name]) return name;
	// Find a suffix digit that's unique
	int suffixDigit = 2;
	NSString *newName = name;
	do {
		newName = [NSString stringWithFormat:@"%@%d", name, suffixDigit];
		suffixDigit++;
	} while ([set containsObject:newName]);
	return newName;
}

#pragma mark - Querying

- (NSString *)symbolNameForObject:(id)object
{
	return [self symbolForObject:object].symbolName;
}

- (UInt64)symbolIDForObject:(id)object
{
	return [self symbolForObject:object].symbolID;
}

- (id)objectForSymbolName:(NSString *)symbolName
{
	for (MASymbol *symbol in self.symbols) {
		if ([symbol.symbolName isEqual:symbolName]) return symbol.object;
	}
	return nil;
}

- (id)objectForSymbolID:(UInt64)symbolID
{
	for (MASymbol *symbol in self.symbols) {
		if (symbol.symbolID == symbolID) return symbol.object;
	}
	return nil;
}

- (BOOL)containsObject:(id)object
{
	return ([self symbolForObject:object] != nil);
}

- (MASymbol *)symbolForObject:(id)object
{
	for (MASymbol *symbol in self.symbols) {
		if ([symbol.object isEqual:object]) return symbol;
	}
	return nil;
}

#pragma mark - Editing Objects

- (void)addObject:(id)object withName:(NSString *)name
{
	[self addObject:object withName:name symbolNameFormat:nil];
}

- (void)addObject:(id)object withName:(NSString *)name symbolNameFormat:(NSString *)symbolNameFormat
{
	if (!object) return;
	MASymbol *symbol = [[MASymbol alloc] init];
	symbol.symbolID = [self generateUniqueSymbolID];
	symbol.object = object;
	symbol.objectName = name;
	symbol.nameFormat = symbolNameFormat;
	[self.symbols addObject:symbol];
}

- (void)removeObject:(id)object
{
	MASymbol *symbol = [self symbolForObject:object];
	[self.symbols removeObject:symbol];
}

- (void)setName:(NSString *)name forObject:(id)object
{
	[self symbolForObject:object].objectName = name;
}

#pragma mark - Editing Reserved Names

- (void)addReservedNames:(NSArray *)names
{
	[self.reservedNames addObjectsFromArray:names];
}

- (void)removeReservedNames:(NSArray *)names
{
	[self.reservedNames removeObjectsInArray:names];
}

#pragma mark - Enumerators

- (NSArray *)allObjects
{
	NSMutableArray *array = [NSMutableArray array];
	for (MASymbol *symbol in self.symbols) {
		[array addObject:symbol.object];
	}
	return array;
}

- (NSEnumerator *)reservedNamesEnumerator
{
	return [self.reservedNames objectEnumerator];
}

#pragma mark - Utility

- (UInt64)generateUniqueSymbolID
{
	if ([self.symbols count] >= self.maximumSymbolID+1) return UINT64_MAX;
	UInt64 symbolID;
	do {
		symbolID = (random() % self.maximumSymbolID);
	} while ([self objectForSymbolID:symbolID]);
	return symbolID;
}

- (NSString *)description
{
	return [self.symbols description];
}

@end





