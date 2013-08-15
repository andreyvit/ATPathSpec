
#import "ATPathSpec.h"
#import "ATPathSpecPrivate.h"


@interface ATPathSpec ()

//- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path;

@end


@implementation ATPathSpec

+ (ATPathSpec *)pathSpecMatchingNameSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type {
    return [[ATSuffixPathSpec alloc] initWithSuffix:suffix type:type];
}

- (BOOL)matchesPath:(NSString *)path type:(ATPathSpecEntryType)type {
    return [self matchResultForPath:path type:type] == ATPathSpecMatchResultMatched;
}

- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path type:(ATPathSpecEntryType)type {
    abort();
}

//+ (ATPathSpec *)pathSpecMatchingUnionOf:(NSArray *)specs {
//    abort();
//}
//
//- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path {
//    abort();
//}

@end


#pragma mark -


@implementation ATSuffixPathSpec

@synthesize suffix=_suffix;

- (id)initWithSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type {
    self = [super init];
    if (self) {
        _suffix = [suffix copy];
    }
    return self;
}

- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path type:(ATPathSpecEntryType)type {
    if (type != _type)
        return ATPathSpecMatchResultUnknown;

    NSString *name = [path lastPathComponent];
    NSUInteger nameLen = name.length, suffixLen = _suffix.length;
    if (nameLen < _suffix.length || NSOrderedSame != [name compare:_suffix options:NSLiteralSearch range:NSMakeRange(nameLen - suffixLen, suffixLen)])
        return ATPathSpecMatchResultUnknown;

    return ATPathSpecMatchResultMatched;
}

@end







