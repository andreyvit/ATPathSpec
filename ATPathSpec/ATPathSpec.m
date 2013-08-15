
#import "ATPathSpec.h"
#import "ATPathSpecPrivate.h"


NSString *const ATPathSpecErrorDomain = @"ATPathSpecErrorDomain";
NSString *const ATPathSpecErrorSpecStringKey = @"ATPathSpecErrorSpecString";


static NSString *ATPathSpecTokenTypeNames[] = {
    @"NONE",
    @"Mask",
    @"!",
    @";",
    @",",
    @"_",
    @"|",
    @"&",
    @"(",
    @")",
};


#define return_error(returnValue, outError, error)  do { \
        if (outError) *outError = error; \
        return nil; \
    } while(0)



@implementation ATPathSpec (ATPathSpecParsing)

+ (void)enumerateTokensInString:(NSString *)string withSyntaxOptions:(ATPathSpecSyntaxOptions)options usingBlock:(ATPathSpecTokenBlock)block decodeTokens:(BOOL)decodeTokens {
    BOOL escapeEnabled = !!(options & ATPathSpecSyntaxOptionsAllowBackslashEscape);
    BOOL negationEnabled = !!(options & ATPathSpecSyntaxOptionsAllowBangNegation);

    NSCharacterSet *escapeCharacters = escapeEnabled ? [NSCharacterSet characterSetWithCharactersInString:@"\\"] : [NSCharacterSet new];
    NSCharacterSet *whitespaceCharacters = [NSCharacterSet whitespaceCharacterSet];
    NSCharacterSet *newlineCharacters = [NSCharacterSet newlineCharacterSet];

    NSMutableCharacterSet *specialCharacters = [NSMutableCharacterSet new];
    [specialCharacters formUnionWithCharacterSet:escapeCharacters];
    if (options & ATPathSpecSyntaxOptionsAllowNewlineSeparator)
        [specialCharacters addCharactersInString:@"\n"];
    if (options & ATPathSpecSyntaxOptionsAllowCommaSeparator)
        [specialCharacters addCharactersInString:@","];
    if (options & ATPathSpecSyntaxOptionsAllowWhitespaceSeparator)
        [specialCharacters formUnionWithCharacterSet:whitespaceCharacters];
    if (options & ATPathSpecSyntaxOptionsAllowPipeUnion)
        [specialCharacters addCharactersInString:@"|"];
    if (options & ATPathSpecSyntaxOptionsAllowAmpersandIntersection)
        [specialCharacters addCharactersInString:@"&"];
    if (options & ATPathSpecSyntaxOptionsAllowParen)
        [specialCharacters addCharactersInString:@"()"];
    if (options & ATPathSpecSyntaxOptionsAllowHashComment)
        [specialCharacters addCharactersInString:@"#"];

    // don't include unary operators ("!") into the specialCharacters because they have no special meaning unless they start the mask

    NSUInteger len = string.length;
    unichar buffer[len];
    [string getCharacters:buffer range:NSMakeRange(0, len)];

    ATPathSpecTokenType lastTokenType = ATPathSpecTokenTypeNone;
    ATPathSpecTokenType queuedTokenType = ATPathSpecTokenTypeNone;
    NSRange queuedTokenRange;
    NSUInteger textTokenStart = 0;
    NSUInteger searchStart = textTokenStart;
    while (textTokenStart < len) {
        NSUInteger specialPos = (searchStart >= len ? NSNotFound : [string rangeOfCharacterFromSet:specialCharacters options:0 range:NSMakeRange(searchStart, len - searchStart)].location);

        // skip the escape sequence
        if (escapeEnabled && specialPos != NSNotFound && [escapeCharacters characterIsMember:buffer[specialPos]]) {
            searchStart = specialPos + 2;  // don't interpret the next character as a special operator
            continue;
        }

        NSUInteger textTokenEnd = (specialPos == NSNotFound ? len : specialPos);

        // handle unary operators (and leading whitespace)
        while (textTokenStart < textTokenEnd) {
            // skip leading whitespace
            while (textTokenStart < textTokenEnd && [whitespaceCharacters characterIsMember:buffer[textTokenStart]])
                ++textTokenStart;

            // unary operators
            if (negationEnabled && buffer[textTokenStart] == '!') {
                if (queuedTokenType != ATPathSpecTokenTypeNone) {
                    block(queuedTokenType, queuedTokenRange, nil);
                    queuedTokenType = ATPathSpecTokenTypeNone;
                }
                block(ATPathSpecTokenTypeNegation, NSMakeRange(textTokenStart, 1), nil);
                lastTokenType = ATPathSpecTokenTypeNegation;
                ++textTokenStart;
            } else {
                break;
            }
        }

        // skip trailing whitespace
        while (textTokenStart < textTokenEnd && [whitespaceCharacters characterIsMember:buffer[textTokenEnd - 1]])
            --textTokenEnd;

        // handle regular text
        if (textTokenStart < textTokenEnd) {
            NSRange textTokenRange = NSMakeRange(textTokenStart, textTokenEnd - textTokenStart);
            NSString *textTokenString = nil;
            if (decodeTokens) {
                textTokenString = [self decodeEscapesInString:[[string substringWithRange:textTokenRange] stringByTrimmingCharactersInSet:whitespaceCharacters]];
            }
            if (queuedTokenType != ATPathSpecTokenTypeNone) {
                block(queuedTokenType, queuedTokenRange, nil);
                queuedTokenType = ATPathSpecTokenTypeNone;
            }
            block(ATPathSpecTokenTypeMask, textTokenRange, textTokenString);
            lastTokenType = ATPathSpecTokenTypeMask;
        }

        if (specialPos == NSNotFound)
            return;

        unichar special = buffer[specialPos];
        if (special == '#') {
            // skip comment
            NSUInteger eol = [string rangeOfCharacterFromSet:newlineCharacters options:0 range:NSMakeRange(specialPos+1, len - (specialPos+1))].location;
            if (eol == NSNotFound) {
                eol = len;
            } else {
                if (lastTokenType != ATPathSpecTokenTypeNone && queuedTokenType != ATPathSpecTokenTypeNewline) {
                    queuedTokenType = ATPathSpecTokenTypeNewline;
                    queuedTokenRange = NSMakeRange(eol, 1);
                }
            }
            textTokenStart = searchStart = eol + 1;
        } else if ([whitespaceCharacters characterIsMember:special]) {
            if (queuedTokenType != ATPathSpecTokenTypeNewline && queuedTokenType != ATPathSpecTokenTypeComma && queuedTokenType != ATPathSpecTokenTypeWhitespace && (lastTokenType == ATPathSpecTokenTypeMask || lastTokenType == ATPathSpecTokenTypeCloseParen) ) {
                queuedTokenType = ATPathSpecTokenTypeWhitespace;
                queuedTokenRange = NSMakeRange(specialPos, 1);
            }

            // skip remaining whitespace
            searchStart = specialPos + 1;
            while (searchStart < len && [whitespaceCharacters characterIsMember:buffer[searchStart]])
                ++searchStart;
            textTokenStart = searchStart;
        } else {
            textTokenStart = searchStart = specialPos + 1;

            ATPathSpecTokenType type = ATPathSpecTokenTypeNone;
            switch (special) {
                case '\n':
                    if (lastTokenType != ATPathSpecTokenTypeNone && queuedTokenType != ATPathSpecTokenTypeNewline) {
                        queuedTokenType = ATPathSpecTokenTypeNewline;
                        queuedTokenRange = NSMakeRange(specialPos, 1);
                    }
                    break;
                case ',':
                    if (queuedTokenType != ATPathSpecTokenTypeNewline && queuedTokenType != ATPathSpecTokenTypeComma) {
                        queuedTokenType = ATPathSpecTokenTypeComma;
                        queuedTokenRange = NSMakeRange(specialPos, 1);
                    }
                    break;
                case '|':
                    queuedTokenType = ATPathSpecTokenTypeNone;
                    type = ATPathSpecTokenTypeUnion;
                    break;
                case '&':
                    queuedTokenType = ATPathSpecTokenTypeNone;
                    type = ATPathSpecTokenTypeIntersection;
                    break;
                case '(':
                    type = ATPathSpecTokenTypeOpenParen;
                    break;
                case ')':
                    queuedTokenType = ATPathSpecTokenTypeNone;
                    type = ATPathSpecTokenTypeCloseParen;
                    break;
                default:
                    abort();
            }
            if (type != ATPathSpecTokenTypeNone) {
                if (queuedTokenType != ATPathSpecTokenTypeNone) {
                    block(queuedTokenType, queuedTokenRange, nil);
                    queuedTokenType = ATPathSpecTokenTypeNone;
                }
                block(type, NSMakeRange(specialPos, 1), nil);
                lastTokenType = type;
            }
        }
    }
}

+ (NSString *)describeTokensInString:(NSString *)string withSyntaxOptions:(ATPathSpecSyntaxOptions)options {
    NSMutableArray *description = [NSMutableArray new];
    [self enumerateTokensInString:string withSyntaxOptions:options usingBlock:^(ATPathSpecTokenType type, NSRange range, NSString *decoded) {
        if (type == ATPathSpecTokenTypeMask)
            [description addObject:[NSString stringWithFormat:@"Mask(%@)", decoded]];
        else
            [description addObject:ATPathSpecTokenTypeNames[type]];
    } decodeTokens:YES];
    return [description componentsJoinedByString:@" "];
}

+ (NSString *)decodeEscapesInString:(NSString *)string {
    static NSCharacterSet *escapes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        escapes = [NSCharacterSet characterSetWithCharactersInString:@"\\"];
    });
    
    NSRange range = [string rangeOfCharacterFromSet:escapes];
    if (range.location == NSNotFound)
        return string;

    NSUInteger srclen = string.length;
    unichar source[srclen];
    [string getCharacters:source range:NSMakeRange(0, srclen)];

    unichar result[srclen];
    NSUInteger reslen = 0;

    for (unichar *srcend = source + srclen, *psrc = source; psrc < srcend; ++psrc) {
        unichar ch = *psrc;
        if (ch == '\\') {
            ++psrc;
            if (psrc < srcend)
                result[reslen++] = *psrc;
        } else {
            result[reslen++] = ch;
        }
    }

    return [NSString stringWithCharacters:result length:reslen];
}

@end


@implementation ATPathSpec

+ (ATPathSpec *)pathSpecWithString:(NSString *)string syntaxOptions:(ATPathSpecSyntaxOptions)options {
    NSError *error;
    ATPathSpec *result = [self pathSpecWithString:string syntaxOptions:options error:&error];
    if (!result) {
        NSAssert(NO, @"Error in [ATPathSpec pathSpecWithString:\"%@\"]: %@", string, error.localizedDescription);
        abort();
    }
    return result;
}

+ (ATPathSpec *)pathSpecWithString:(NSString *)string syntaxOptions:(ATPathSpecSyntaxOptions)options error:(NSError **)outError {
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






