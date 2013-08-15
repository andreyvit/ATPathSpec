
#import <XCTest/XCTest.h>
#import "ATPathSpec.h"


@interface ATPathSpecTests : XCTestCase
@end

@implementation ATPathSpecTests

- (void)testExample {
    ATPathSpec *spec = [ATPathSpec pathSpecMatchingNameSuffix:@".txt" type:ATPathSpecEntryTypeFile];
    XCTAssertTrue( [spec matchesPath:@"README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"README.html" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue( [spec matchesPath:@"docs/README.txt" type:ATPathSpecEntryTypeFile], "");
    XCTAssertTrue(![spec matchesPath:@"docs/README.html" type:ATPathSpecEntryTypeFile], "");
}

@end
