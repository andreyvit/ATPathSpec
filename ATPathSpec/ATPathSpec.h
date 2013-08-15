
#import <Foundation/Foundation.h>


typedef enum {
    ATPathSpecMatchResultUnknown = 0,
    ATPathSpecMatchResultMatched = 1,
    ATPathSpecMatchResultExcluded = -1,
} ATPathSpecMatchResult;

typedef enum {
    ATPathSpecEntryTypeFile,
    ATPathSpecEntryTypeFolder,
} ATPathSpecEntryType;


@interface ATPathSpec : NSObject

+ (ATPathSpec *)pathSpecMatchingNameSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type;
//+ (ATPathSpec *)pathSpecMatchingUnionOf:(NSArray *)specs;

- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path type:(ATPathSpecEntryType)type;
- (BOOL)matchesPath:(NSString *)path type:(ATPathSpecEntryType)type;

@end
