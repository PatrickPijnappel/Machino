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

#import "MAPatternLibraryLoader.h"
#import "MAPattern.h"
#import "MAPatternGroup.h"

static NSString * const MALibraryElementName = @"library";
static NSString * const MAGroupElementName = @"group";
static NSString * const MAGroupNameAttributeName = @"name";
static NSString * const MAPatternElementName = @"pattern";
static NSString * const MAPatternNameAttributeName = @"name";
static NSString * const MAPatternTeaserAttributeName = @"teaser";
static NSString * const MAPatternKeywordsAttributeName = @"keywords";
static NSString * const MAPatternResourceAttributeName = @"resource";

@implementation MAPatternLibraryLoader

- (NSArray *)loadLibrary
{
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"PatternLibrary" withExtension:@"xml"];
	NSXMLDocument *document = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:nil];
	return [self objectsForChildrenOfElement:[document rootElement]];
}

- (NSArray *)objectsForChildrenOfElement:(NSXMLElement *)element
{
	NSMutableArray *objects = [NSMutableArray array];
	for (NSXMLNode *child in [element children]) {
		if ([child kind] == NSXMLElementKind) {
			id object = [self objectForElement:(NSXMLElement *)child];
			[objects addObject:object];
		}
	}
	return objects;
}

- (id)objectForElement:(NSXMLElement *)element
{
	NSString *elementName = [element name];
	if ([elementName isEqual:MAGroupElementName]) {
		MAPatternGroup *group = [[MAPatternGroup alloc] init];
		group.name = [[element attributeForName:MAGroupNameAttributeName] stringValue];
		group.children = [self objectsForChildrenOfElement:element];
		return group;
	}
	if ([elementName isEqual:MAPatternElementName]) {
		MAPattern *pattern = [[MAPattern alloc] init];
		pattern.name = [[element attributeForName:MAPatternNameAttributeName] stringValue];
		pattern.teaser = [[element attributeForName:MAPatternTeaserAttributeName] stringValue];
		pattern.keywords = [[element attributeForName:MAPatternKeywordsAttributeName] stringValue];
		NSString *resourceName = [[element attributeForName:MAPatternResourceAttributeName] stringValue];
		pattern.text = [self loadPatternText:resourceName];
		return pattern;
	}
	return nil;
}

- (NSAttributedString *)loadPatternText:(NSString *)resourceName
{
	if ([resourceName length] == 0) return nil;
	NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"rtfd"];
	if ([path length] != 0) {
		NSFileWrapper *fileWrapper = [[NSFileWrapper alloc] initWithPath:path];
		if (!fileWrapper) return nil;
		return [[NSAttributedString alloc] initWithRTFDFileWrapper:fileWrapper documentAttributes:NULL];
	} else {
		path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"rtf"];
		if ([path length] == 0) return nil;
		NSData *data = [NSData dataWithContentsOfFile:path];
		if (!data) return nil;
		return [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];
	}
}

@end
