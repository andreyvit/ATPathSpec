
#import "ATPathSpec.h"


NSString *ATPathSpec_StringByEscapingRegex(NSString *regex);
NSString *ATPathSpec_RegexFromPatternString(NSString *pattern);
NSString *ATPathSpecEntryType_AdjustTrailingSlashInPathString(ATPathSpecEntryType type, NSString *path);
NSString *ATPathSpecSyntaxOptions_QuoteIfNeeded(NSString *string, ATPathSpecSyntaxOptions options);
NSString *ATPathSpecSyntaxOptions_UnquoteIfNeeded(NSString *string, ATPathSpecSyntaxOptions options);


@interface ATPathSpec (ATPathSpecPrivate)

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

@property(nonatomic, readonly) BOOL complexExpression;

- (NSString *)parenthesizedStringRepresentationWithSyntaxOptions:(ATPathSpecSyntaxOptions)options;

@end


@interface ATLiteralPathSpec : ATPathSpec

- (id)initWithName:(NSString *)name type:(ATPathSpecEntryType)type;

@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) ATPathSpecEntryType type;

@end


@interface ATSuffixPathSpec : ATPathSpec

- (id)initWithSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type;

@property(nonatomic, readonly) NSString *suffix;
@property(nonatomic, readonly) ATPathSpecEntryType type;

@end


@interface ATPatternPathSpec : ATPathSpec

- (id)initWithPattern:(NSString *)pattern type:(ATPathSpecEntryType)type;

@property(nonatomic, readonly) NSString *pattern;
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
