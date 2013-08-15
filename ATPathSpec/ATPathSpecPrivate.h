
#import "ATPathSpec.h"



@interface ATPathSpec (ATPathSpecParsing)

typedef enum {
    ATPathSpecTokenTypeNone,
    ATPathSpecTokenTypeMask,
    ATPathSpecTokenTypeNegation,
    ATPathSpecTokenTypeNewline,
    ATPathSpecTokenTypeComma,
    ATPathSpecTokenTypeWhitespace,
    ATPathSpecTokenTypeUnion,
    ATPathSpecTokenTypeIntersection,
    ATPathSpecTokenTypeOpenParen,
    ATPathSpecTokenTypeCloseParen,
} ATPathSpecTokenType;

typedef void (^ATPathSpecTokenBlock)(ATPathSpecTokenType type, NSRange range, NSString *decoded);

// spec     -> subspec (operator subspec)*
// operator -> "\n" | "," | "|" | "&"
// subspec  -> mask | "(" spec ")"
+ (void)enumerateTokensInString:(NSString *)string withSyntaxOptions:(ATPathSpecSyntaxOptions)options usingBlock:(ATPathSpecTokenBlock)block decodeTokens:(BOOL)decodeTokens;

+ (NSString *)describeTokensInString:(NSString *)string withSyntaxOptions:(ATPathSpecSyntaxOptions)options;  // for tests and debugging

+ (NSString *)decodeEscapesInString:(NSString *)string;

@end


@interface ATSuffixPathSpec : ATPathSpec

- (id)initWithSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type;

@property(nonatomic, readonly) NSString *suffix;
@property(nonatomic, readonly) ATPathSpecEntryType type;

@end


@interface ATUnionPathSpec : ATPathSpec

- (id)initWithSpecs:(NSArray *)specs;

@property(nonatomic, readonly) NSArray *specs;

@end


@interface ATIntersectionPathSpec : ATPathSpec

- (id)initWithSpecs:(NSArray *)specs;

@property(nonatomic, readonly) NSArray *specs;

@end
