
#import <XCTest/XCTest.h>
#import "ATPathSpec.h"


@interface ATPathSpecMultiComponentTests : XCTestCase
@end

@implementation ATPathSpecMultiComponentTests

- (void)testRootedFile {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"/README.txt" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"/README.txt", "");
    XCTAssertTrue( [spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
}

- (void)testSubfolder {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"docs/*.txt" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"docs/*.txt", "");
    XCTAssertTrue(![spec matchesPath:@"hellow.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/hellow.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
}

- (void)testSubfolderMask {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"d*/*.txt" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"d*/*.txt", "");
    XCTAssertTrue(![spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"moredocs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"moredocs/README.html" type:ATPathSpecEntryTypeFile], "");
}

@end
