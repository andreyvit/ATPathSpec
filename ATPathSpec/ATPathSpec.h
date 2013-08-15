
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

typedef enum {
    ATPathSpecSyntaxOptionsAllowBackslashEscape = 0x01,
    ATPathSpecSyntaxOptionsAllowNewlineList = 0x02,
    ATPathSpecSyntaxOptionsAllowCommaList = 0x04,
    ATPathSpecSyntaxOptionsAllowWhitespaceList = 0x200,
    ATPathSpecSyntaxOptionsAllowPipeUnion = 0x08,
    ATPathSpecSyntaxOptionsAllowAmpersandIntersection = 0x10,
    ATPathSpecSyntaxOptionsAllowParen = 0x20,
    ATPathSpecSyntaxOptionsAllowBangNegation = 0x40,
    ATPathSpecSyntaxOptionsAllowHashComment = 0x80,
    ATPathSpecSyntaxOptionsRequireTrailingSlashForFolders = 0x100,

    ATPathSpecSyntaxOptionsPlainMask = 0,
    ATPathSpecSyntaxOptionsPlainList = ATPathSpecSyntaxOptionsAllowNewlineList,
    ATPathSpecSyntaxOptionsGitignore = ATPathSpecSyntaxOptionsAllowBackslashEscape | ATPathSpecSyntaxOptionsAllowNewlineList | ATPathSpecSyntaxOptionsAllowBangNegation | ATPathSpecSyntaxOptionsAllowHashComment,
    ATPathSpecSyntaxOptionsExtended = ATPathSpecSyntaxOptionsAllowBackslashEscape | ATPathSpecSyntaxOptionsAllowNewlineList | ATPathSpecSyntaxOptionsAllowCommaList | ATPathSpecSyntaxOptionsAllowWhitespaceList | ATPathSpecSyntaxOptionsAllowPipeUnion | ATPathSpecSyntaxOptionsAllowAmpersandIntersection | ATPathSpecSyntaxOptionsAllowParen | ATPathSpecSyntaxOptionsAllowBangNegation | ATPathSpecSyntaxOptionsAllowHashComment | ATPathSpecSyntaxOptionsRequireTrailingSlashForFolders,
} ATPathSpecSyntaxOptions;


NSString *const ATPathSpecErrorDomain;
NSString *const ATPathSpecErrorSpecStringKey;

typedef enum {
    ATPathSpecErrorCodeInvalidSpecString = 1,
} ATPathSpecErrorCode;


@interface ATPathSpec : NSObject

+ (ATPathSpec *)pathSpecWithString:(NSString *)string syntaxOptions:(ATPathSpecSyntaxOptions)options;
+ (ATPathSpec *)pathSpecWithString:(NSString *)string syntaxOptions:(ATPathSpecSyntaxOptions)options error:(NSError **)error;

+ (ATPathSpec *)pathSpecMatchingNameSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type;
+ (ATPathSpec *)pathSpecMatchingUnionOf:(NSArray *)specs;

- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path type:(ATPathSpecEntryType)type;
- (BOOL)matchesPath:(NSString *)path type:(ATPathSpecEntryType)type;

@end
