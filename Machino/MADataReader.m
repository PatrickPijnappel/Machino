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

#import "MADataReader.h"

@implementation MADataReader

- (void)setIndex:(NSUInteger)index
{
	if (index > [self.data length]) return;
	_index = index;
}

- (NSUInteger)bytesLeft
{
	return ([self.data length] - self.index);
}

+ (id)readerWithData:(NSData *)data
{
	return [[self alloc] initWithData:data];
}

- (id)initWithData:(NSData *)data
{
	self = [super init];
	if (self) {
		_data = [data copy];
	}
	return self;
}

- (id)init
{
	return [self initWithData:[NSData data]];
}

- (UInt8)readUInt8
{
	if (self.bytesLeft <= 0) return 0;
	const Byte *bytes = [self.data bytes];
	UInt8 value = bytes[self.index];
	self.index++;
	return value;
}

- (UInt16)readUInt16
{
	UInt8 b1 = [self readUInt8];
	UInt8 b2 = [self readUInt8];
	return (b1 << 8) | b2 ; // Read as big-endian
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
	if (length > self.bytesLeft) return nil;
	NSData *subdata = [self.data subdataWithRange:NSMakeRange(self.index, length)];
	self.index += length;
	return subdata;
}

@end
