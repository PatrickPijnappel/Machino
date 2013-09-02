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

#import "MAArduinoIDE.h"
#import "MABoard.h"
#import "MABoardArchitecture.h"
#import "MABoardPackage.h"

NSString * const kErrorArduinoAppName = @"Arduino";
static NSString * const kArduinoAppName = @"Arduino";
static NSArray *boards;

@implementation MABoard

- (NSString *)description
{
	return self.name;
}

- (NSString *)fullIdentifier
{
	return [NSString stringWithFormat:@"%@:%@:%@", self.package.identifier, self.architecture.identifier, self.identifier];
}

#pragma mark - Initialization

+ (id)boardWithName:(NSString *)name identifier:(NSString *)identifier architecture:(MABoardArchitecture *)architecture package:(MABoardPackage *)package
{
	MABoard *board = [[self alloc] init];
	board->_name = [name copy];
	board->_identifier = [identifier copy];
	board->_architecture = architecture;
	board->_package = package;
	return board;
}

#pragma mark - General

+ (NSArray *)allBoards
{
	return boards;
}

+ (NSArray *)boardsForArchitecture:(MABoardArchitecture *)architecture
{
	NSMutableArray *matchingBoards = [NSMutableArray array];
	for (MABoard *board in boards) {
		if (board.architecture == architecture) {
			[matchingBoards addObject:board];
		}
	}
	return matchingBoards;
}

+ (NSArray *)allArchitectures
{
	NSMutableArray *architectures = [NSMutableArray array];
	for (MABoard *board in boards) {
		MABoardArchitecture *architecture = board.architecture;
		if (![architectures containsObject:architecture]) {
			[architectures addObject:architecture];
		}
	}
	return architectures;
}

+ (NSArray *)allPackages
{
	NSMutableArray *packages = [NSMutableArray array];
	for (MABoard *board in boards) {
		MABoardPackage *package = board.package;
		if (![packages containsObject:package]) {
			[packages addObject:package];
		}
	}
	return packages;
}

#pragma mark - Find Available Boards

+ (void)findAvailableBoardsWithError:(NSError **)error
{
	NSMutableArray *boardsMutable = [NSMutableArray array];
	// Get hardware folder
	NSString *arduinoAppPath = [MAArduinoIDE pathWithError:error];
	if (*error) return;
	NSString *hardwareDirPath = [arduinoAppPath stringByAppendingPathComponent:@"Contents/Resources/Java/hardware"];
	// Go through all folders
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *itemNames = [fileManager contentsOfDirectoryAtPath:hardwareDirPath error:nil];
	for (NSString *itemName in itemNames) {
		NSString *itemPath = [hardwareDirPath stringByAppendingPathComponent:itemName];
		BOOL isDirectory;
		BOOL exists = [fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory];
		// Each subfolder (can) represent a package
		if (exists && isDirectory) {
			NSArray *boardsForPackage = [self findBoardsForPackageWithPath:itemPath];
			if (boardsForPackage) {
				[boardsMutable addObjectsFromArray:boardsForPackage];
			}
		}
	}
	// Set
	boards = [boardsMutable copy];
}

+ (NSArray *)findBoardsForPackageWithPath:(NSString *)path
{
	NSMutableArray *boardsMutable = [NSMutableArray array];
	// Create package
	NSString *identifier = [path lastPathComponent];
	MABoardPackage *package = [MABoardPackage packageWithIdentifier:identifier];
	// Go through all folders, representing architectures
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *itemNames = [fileManager contentsOfDirectoryAtPath:path error:nil];
	for (NSString *itemName in itemNames) {
		NSString *itemPath = [path stringByAppendingPathComponent:itemName];
		BOOL isDirectory;
		BOOL exists = [fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory];
		// Each subfolder (can) represent an architecture
		if (exists && isDirectory) {
			NSArray *boardsForArchitecture = [self findBoardsForAchitectureWithPath:itemPath package:package];
			if (boardsForArchitecture) {
				[boardsMutable addObjectsFromArray:boardsForArchitecture];
			}
		}
	}
	// Return
	return boardsMutable;
}

+ (NSArray *)findBoardsForAchitectureWithPath:(NSString *)path package:(MABoardPackage *)package
{
	NSMutableArray *boardsMutable = [NSMutableArray array];
	// Create architecture
	NSString *identifier = [path lastPathComponent];
	NSString *name = [self findNameForArchitectureWithPath:path];
	MABoardArchitecture *architecture = [MABoardArchitecture architectureWithName:name identifier:identifier package:package];
	// Read file
	NSString *boardsFile = [path stringByAppendingPathComponent:@"boards.txt"];
	NSString *contents = [NSString stringWithContentsOfFile:boardsFile encoding:NSUTF8StringEncoding error:nil];
	if (!contents) return nil;
	// Create regex
	NSRegularExpressionOptions regexOptions = NSRegularExpressionAnchorsMatchLines;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*(\\w+)\\.name\\s*=\\s*(.*?)\\s*(#.*?)?$" options:regexOptions  error:nil];
	// Match
	NSArray *matches = [regex matchesInString:contents options:0 range:NSMakeRange(0, [contents length])];
	for (NSTextCheckingResult *match in matches) {
		NSString *identifier = [contents substringWithRange:[match rangeAtIndex:1]];
		NSString *name = [contents substringWithRange:[match rangeAtIndex:2]];
		MABoard *board = [MABoard boardWithName:name identifier:identifier architecture:architecture package:package];
		[boardsMutable addObject:board];
	}
	// Return
	return boardsMutable;
}

+ (NSString *)findNameForArchitectureWithPath:(NSString *)path
{
	// Read file
	NSString *platformFile = [path stringByAppendingPathComponent:@"platform.txt"];
	NSString *contents = [NSString stringWithContentsOfFile:platformFile encoding:NSUTF8StringEncoding error:nil];
	if (!contents) return nil;
	// Create regex
	NSRegularExpressionOptions regexOptions = NSRegularExpressionAnchorsMatchLines;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*name\\s*=\\s*(.*?)\\s*(#.*?)?$" options:regexOptions  error:nil];
	// Match & return
	NSArray *matches = [regex matchesInString:contents options:0 range:NSMakeRange(0, [contents length])];
	if ([matches count] > 0) {
		NSRange range = [matches[0] rangeAtIndex:1];
		return [contents substringWithRange:range];
	}
	return nil;
}

@end
