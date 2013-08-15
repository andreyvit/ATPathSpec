
#import <XCTest/XCTest.h>
#import "ATPathSpec.h"


@interface ATPathSpecTests : XCTestCase
@end

@implementation ATPathSpecTests

- (void)testSingleMask {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"*.txt"];
    XCTAssertTrue( [spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
}

- (void)testUnion {
    ATPathSpec *spec = [ATPathSpec pathSpecWithString:@"*.txt, *.html"];
    XCTAssertTrue( [spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.doc" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.doc" type:ATPathSpecEntryTypeFile], "");
}

@end
