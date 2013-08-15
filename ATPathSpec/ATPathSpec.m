
#import "ATPathSpec.h"
#import "ATPathSpecPrivate.h"


NSString *const ATPathSpecErrorDomain = @"ATPathSpecErrorDomain";
NSString *const ATPathSpecErrorSpecStringKey = @"ATPathSpecErrorSpecString";


#define return_error(returnValue, outError, error)  do { \
        if (outError) *outError = error; \
        return nil; \
    } while(0)


@implementation ATPathSpec

+ (ATPathSpec *)pathSpecWithString:(NSString *)string {
    NSError *error;
    ATPathSpec *result = [self pathSpecWithString:string error:&error];
    if (!result) {
        NSAssert(NO, @"Error in [ATPathSpec pathSpecWithString:\"%@\"]: %@", string, error.localizedDescription);
        abort();
    }
    return result;
}

+ (ATPathSpec *)pathSpecWithString:(NSString *)string error:(NSError **)outError {
    static NSCharacterSet *special;
    static dispatch_once_t specialToken;
    dispatch_once(&specialToken, ^{
        special = [NSCharacterSet characterSetWithCharactersInString:@",\n"];
    });

    NSRange range = [string rangeOfCharacterFromSet:special];
    if (range.location == NSNotFound) {
        return [self pathSpecWithSingleMaskString:string error:outError];
    } else {
        NSMutableArray *specs = [NSMutableArray new];
        for (NSString *component in [string componentsSeparatedByCharactersInSet:special]) {
            NSString *trimmed = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length == 0)
                continue;

            ATPathSpec *spec = [self pathSpecWithSingleMaskString:trimmed error:outError];
            if (!spec)
                return nil;
            [specs addObject:spec];
        }

        return [self pathSpecMatchingUnionOf:specs];
    }
}

+ (ATPathSpec *)pathSpecWithSingleMaskString:(NSString *)originalString error:(NSError **)outError {
    NSString *string = [originalString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSUInteger len = string.length;
    if (len == 0)
        return_error(nil, outError, ([NSError errorWithDomain:ATPathSpecErrorDomain code:ATPathSpecErrorCodeInvalidSpecString userInfo:@{ATPathSpecErrorSpecStringKey: originalString, NSLocalizedDescriptionKey:@"Empty path spec"}]));

    ATPathSpecEntryType type = ATPathSpecEntryTypeFile;
    if ([string characterAtIndex:len - 1] == '/') {
        type = ATPathSpecEntryTypeFolder;
        string = [string substringToIndex:len - 1];
        --len;
    }

    static NSCharacterSet *wildcards;
    static dispatch_once_t wildcardsToken;
    dispatch_once(&wildcardsToken, ^{
        wildcards = [NSCharacterSet characterSetWithCharactersInString:@"*"];
    });

    NSUInteger wildcardPos = [string rangeOfCharacterFromSet:wildcards].location;
    if (wildcardPos == NSNotFound) {
        // TODO: plain string
    } else {
        if (wildcardPos == 0) {
            NSString *suffix = [string substringFromIndex:wildcardPos + 1];
            NSUInteger secondWildcardPos = [suffix rangeOfCharacterFromSet:wildcards].location;
            if (secondWildcardPos == NSNotFound) {
                return [self pathSpecMatchingNameSuffix:[string substringFromIndex:1] type:type];
            }
        }
        // TODO: complicated wildcard
    }

    return_error(nil, outError, ([NSError errorWithDomain:ATPathSpecErrorDomain code:ATPathSpecErrorCodeInvalidSpecString userInfo:@{ATPathSpecErrorSpecStringKey: originalString, NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid path spec syntax: %@", originalString]}]));
}

+ (ATPathSpec *)pathSpecMatchingNameSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type {
    return [[ATSuffixPathSpec alloc] initWithSuffix:suffix type:type];
}

- (BOOL)matchesPath:(NSString *)path type:(ATPathSpecEntryType)type {
    return [self matchResultForPath:path type:type] == ATPathSpecMatchResultMatched;
}

- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path type:(ATPathSpecEntryType)type {
    abort();
}

+ (ATPathSpec *)pathSpecMatchingUnionOf:(NSArray *)specs {
    return [[ATUnionPathSpec alloc] initWithSpecs:specs];
}

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


#pragma mark -

@implementation ATUnionPathSpec

@synthesize specs = _specs;

- (id)initWithSpecs:(NSArray *)specs {
    self = [super init];
    if (self) {
        _specs = [specs copy];
    }
    return self;
}

- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path type:(ATPathSpecEntryType)type {
    for (ATPathSpec *spec in _specs) {
        ATPathSpecMatchResult result = [spec matchResultForPath:path type:type];
        if (result == ATPathSpecMatchResultMatched)
            return ATPathSpecMatchResultMatched;
    }

    return ATPathSpecMatchResultUnknown;
}

@end






