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

#import "MADocument.h"
#import "MAAppDelegate.h"
#import "MAController.h"
#import "Graph.h"
#import "MACodeController.h"
#import "MAStateMachineCodeTemplate.h"
#import "MASymbolManager.h"

static NSString * const kCoderNodesKey = @"nodes";
static NSString * const kCoderArrowsKey = @"arrows";
static NSString * const kCoderCodeTemplateKey = @"codeTemplate";

@interface MADocument ()

@property (nonatomic, strong, readonly) NSMutableArray *nodes;
@property (nonatomic, strong, readonly) NSMutableArray *arrows;
@property (nonatomic, strong, readonly) MAStateMachineCodeTemplate *codeTemplate;


@end

@implementation MADocument

- (id)init
{
    self = [super init];
    if (self) {
		_nodes = [NSMutableArray array];
		_arrows = [NSMutableArray array];
    }
    return self;
}

- (IBAction)runProgram:(id)sender
{
	[self.controller run:sender];
}

- (IBAction)stopProgram:(id)sender
{
	[self.controller stop:sender];
}

- (NSString *)windowNibName
{
	return @"MADocument";
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (void)awakeFromNib
{
	[self setDataOnUI];
}

- (void)setDataOnUI
{
	[self.controller.graphView setNodes:self.nodes arrows:self.arrows];
	[self.controller.codeController setCodeTemplate:self.codeTemplate mergeOldCode:NO];
	[self.controller.codeController updateCodeForStates:self.nodes transitions:self.arrows];
}

- (void)encodeDataWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.nodes forKey:kCoderNodesKey];
	[coder encodeObject:self.arrows forKey:kCoderArrowsKey];
	[coder encodeObject:self.controller.codeController.codeTemplate forKey:kCoderCodeTemplateKey];
}

- (void)setDataWithCoder:(NSCoder *)coder
{
	_nodes = [coder decodeObjectForKey:kCoderNodesKey];
	_arrows = [coder decodeObjectForKey:kCoderArrowsKey];
	_codeTemplate = [coder decodeObjectForKey:kCoderCodeTemplateKey];
	[_codeTemplate.symbols regenerateSymbolIDs];
	[self setDataOnUI];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSMutableData *data = [NSMutableData data];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	[self encodeDataWithCoder:archiver];
	[archiver finishEncoding];
	return data;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
	[self setDataWithCoder:unarchiver];
	return true;
}

@end
