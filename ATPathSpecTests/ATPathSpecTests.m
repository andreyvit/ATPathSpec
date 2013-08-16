
#import <XCTest/XCTest.h>
#import "ATPathSpec.h"


@interface ATPathSpecTests : XCTestCase
@end

@implementation ATPathSpecTests

- (void)testLiteralName {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"README.txt" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"README.txt", "");
    XCTAssertTrue( [spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"readme.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
}

- (void)testSingleMask {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"*.txt" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"*.txt", "");
    XCTAssertTrue( [spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
}

- (void)testSingleNegatedMask {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"!*.txt" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"!*.txt", "");
    XCTAssertTrue(![spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
}

- (void)testPipeUnion {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"*.txt | *.html" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertTrue( [spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.doc" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.doc" type:ATPathSpecEntryTypeFile], "");
}

- (void)testNegatedUnion {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"!(*.txt | *.html)" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertTrue(![spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"README.doc" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.doc" type:ATPathSpecEntryTypeFile], "");
}

- (void)testCommaUnion {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"*.txt, *.html" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"*.txt | *.html", "");
}

- (void)testWhitespaceUnion {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"*.txt *.html" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"*.txt | *.html", "");
}

- (void)testNegatedWhitespaceUnion {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"!(*.txt *.html)" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertEqualObjects([spec description], @"!(*.txt | *.html)", "");
}

- (void)testIntersection {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"*.txt & README.*" syntaxOptions:ATPathSpecSyntaxOptionsExtended];
    XCTAssertTrue( [spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.doc" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"hellow.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.doc" type:ATPathSpecEntryTypeFile], "");
}

@end
