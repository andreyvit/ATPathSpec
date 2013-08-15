
#import "ATPathSpec.h"


@interface ATSuffixPathSpec : ATPathSpec

- (id)initWithSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type;

@property(nonatomic, readonly) NSString *suffix;
@property(nonatomic, readonly) ATPathSpecEntryType type;

@end


@interface ATUnionPathSpec : ATPathSpec

- (id)initWithSpecs:(NSArray *)specs;

@property(nonatomic, readonly) NSArray *specs;

@end
