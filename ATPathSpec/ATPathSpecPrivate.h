
#import "ATPathSpec.h"


@interface ATSuffixPathSpec : ATPathSpec

- (id)initWithSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type;

@property(nonatomic, readonly) NSString *suffix;
@property(nonatomic, readonly) ATPathSpecEntryType type;

@end
