
#import "ATPathSpec.h"
#import "ATPathSpecPrivate.h"
#import "RegexKitLite.h"


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


NSString *ATPathSpec_Unescape(NSString *string) {
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

NSString *ATPathSpec_Escape(NSString *string, NSCharacterSet *characterSet) {
    NSRange range = [string rangeOfCharacterFromSet:characterSet];
    if (range.location == NSNotFound)
        return string;

    NSUInteger srclen = string.length;
    unichar source[srclen];
    [string getCharacters:source range:NSMakeRange(0, srclen)];

    unichar result[srclen * 2];
    NSUInteger reslen = 0;

    for (unichar *srcend = source + srclen, *psrc = source; psrc < srcend; ++psrc) {
        unichar ch = *psrc;
        if ([characterSet characterIsMember:ch]) {
            result[reslen++] = '\\';
        }
        result[reslen++] = ch;
    }

    return [NSString stringWithCharacters:result length:reslen];
}

NSString *ATPathSpec_StringByEscapingRegex(NSString *regex) {
    return [regex stringByReplacingOccurrencesOfRegex:@"([\\\\.^$\\[|*+?\\{])" withString:@"\\\\$1"];
}

NSString *ATPathSpec_RegexFromPatternString(NSString *pattern) {
    pattern = [pattern stringByReplacingOccurrencesOfString:@"*" withString:@"_@,STAR,@_"];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"?" withString:@"_@,DOT,@_"];
    NSString *regex = ATPathSpec_StringByEscapingRegex(pattern);
    regex = [regex stringByReplacingOccurrencesOfString:@"_@,DOT,@_" withString:@"."];
    regex = [regex stringByReplacingOccurrencesOfString:@"_@,STAR,@_" withString:@".*"];
    return [NSString stringWithFormat:@"^%@$", regex];
}

NSString *ATPathSpecEntryType_AdjustTrailingSlashInPathString(ATPathSpecEntryType type, NSString *path) {
    BOOL needsSlash = (type == ATPathSpecEntryTypeFolder);
    BOOL hasSlash = [path hasSuffix:@"/"];
    if (needsSlash && !hasSlash)
        return [path stringByAppendingString:@"/"];
    else if (!needsSlash && hasSlash)
        return [path substringToIndex:path.length - 1];
    else
        return path;
}

NSString *ATPathSpecSyntaxOptions_QuoteIfNeeded(NSString *string, ATPathSpecSyntaxOptions options) {
    if (!(options & ATPathSpecSyntaxOptionsAllowBackslashEscape))
        return string;

    NSMutableCharacterSet *specialCharacters = [NSMutableCharacterSet new];
    [specialCharacters addCharactersInString:@"\\"];
    if (options & ATPathSpecSyntaxOptionsAllowNewlineSeparator)
        [specialCharacters formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
    if (options & ATPathSpecSyntaxOptionsAllowCommaSeparator)
        [specialCharacters addCharactersInString:@","];
    if (options & ATPathSpecSyntaxOptionsAllowWhitespaceSeparator)
        [specialCharacters formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    if (options & ATPathSpecSyntaxOptionsAllowPipeUnion)
        [specialCharacters addCharactersInString:@"|"];
    if (options & ATPathSpecSyntaxOptionsAllowAmpersandIntersection)
        [specialCharacters addCharactersInString:@"&"];
    if (options & ATPathSpecSyntaxOptionsAllowParen)
        [specialCharacters addCharactersInString:@"()"];
    if (options & ATPathSpecSyntaxOptionsAllowHashComment)
        [specialCharacters addCharactersInString:@"#"];
    if (options & ATPathSpecSyntaxOptionsAllowBangNegation)
        [specialCharacters addCharactersInString:@"!"];
    return ATPathSpec_Escape(string, specialCharacters);
}

NSString *ATPathSpecSyntaxOptions_UnquoteIfNeeded(NSString *string, ATPathSpecSyntaxOptions options) {
    if (!(options & ATPathSpecSyntaxOptionsAllowBackslashEscape))
        return string;
    return ATPathSpec_Unescape(string);
}



@implementation ATPathSpec (ATPathSpecPrivate)

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
                textTokenString = ATPathSpec_Unescape([[string substringWithRange:textTokenRange] stringByTrimmingCharactersInSet:whitespaceCharacters]);
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

- (BOOL)isComplexExpression {
    return NO;
}

- (NSString *)parenthesizedStringRepresentationWithSyntaxOptions:(ATPathSpecSyntaxOptions)options {
    NSString *repr = [self stringRepresentationWithSyntaxOptions:options];
    if ([self isComplexExpression])
        return [NSString stringWithFormat:@"(%@)", repr];
    else
        return repr;
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
    NSMutableArray *contexts = [NSMutableArray new];
    __block NSMutableArray *specs = [NSMutableArray new];
    __block ATPathSpecTokenType op = ATPathSpecTokenTypeNone;
    __block BOOL nextNegated = NO;
    __block BOOL lastNegated = NO;

    __block BOOL failed = NO;

    void (^addSpec)(ATPathSpec *spec) = ^(ATPathSpec *spec){
        lastNegated = nextNegated;
        if (nextNegated) {
            // TODO: negate
        }
        [specs addObject:spec];
        nextNegated = NO;
    };

    void (^initContext)() = ^{
        specs = [NSMutableArray new];
        op = ATPathSpecTokenTypeNone;
        lastNegated = nextNegated = NO;
    };

    ATPathSpec *(^flushContext)() = ^ATPathSpec *{
        if (specs.count == 0) {
            if (outError)
                *outError = nil;
            return nil;
        }
        if (specs.count == 1) {
            return [specs firstObject];
        }
        switch (op) {
            case ATPathSpecTokenTypeNone:
                NSAssert(specs.count <= 1, @"Multiple specs cannot be added without an operator");
                abort();
            case ATPathSpecTokenTypeUnion:
                return [ATPathSpec pathSpecMatchingUnionOf:specs];
            case ATPathSpecTokenTypeIntersection:
                return [ATPathSpec pathSpecMatchingIntersectionOf:specs];
            case ATPathSpecTokenTypeComma:
                if (lastNegated)
                    return [ATPathSpec pathSpecMatchingIntersectionOf:specs];
                else
                    return [ATPathSpec pathSpecMatchingUnionOf:specs];
            default:
                abort();
        }
    };

    void (^pushContext)() = ^{
        [contexts addObject:@{@"specs": specs, @"op": @(op), @"nextNegated": @(nextNegated), @"lastNegated": @(lastNegated)}];
        initContext();
    };

    void (^popContext)() = ^{
        ATPathSpec *spec = flushContext();

        NSDictionary *c = [contexts lastObject];
        [contexts removeLastObject];

        specs = c[@"specs"];
        op = [c[@"op"] unsignedIntValue];
        nextNegated = [c[@"nextNegated"] boolValue];
        lastNegated = [c[@"lastNegated"] boolValue];

        addSpec(spec);
    };

    [ATPathSpec enumerateTokensInString:string withSyntaxOptions:options usingBlock:^(ATPathSpecTokenType type, NSRange range, NSString *decoded) {
        if (failed)
            return;
        if (type == ATPathSpecTokenTypeMask) {
            ATPathSpec *spec = [self pathSpecWithSingleMaskString:decoded error:outError];
            if (!spec) {
                failed = YES;
                return;
            }
            addSpec(spec);
        } else if (type == ATPathSpecTokenTypeWhitespace || type == ATPathSpecTokenTypeComma || type == ATPathSpecTokenTypeNewline) {
            if (op != ATPathSpecTokenTypeNone && op != ATPathSpecTokenTypeComma) {
                if (outError)
                    *outError = [NSError errorWithDomain:ATPathSpecErrorDomain code:ATPathSpecErrorCodeInvalidSpecString userInfo:@{ATPathSpecErrorSpecStringKey: string, NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Cannot mix different operators without parens: '%@'", string]}];
                failed = YES;
                return;
            }
            op = ATPathSpecTokenTypeComma;
        } else if (type == ATPathSpecTokenTypeNegation) {
            nextNegated = !nextNegated;
        } else if (type == ATPathSpecTokenTypeUnion) {
            if (op != ATPathSpecTokenTypeNone && op != ATPathSpecTokenTypeUnion) {
                if (outError)
                    *outError = [NSError errorWithDomain:ATPathSpecErrorDomain code:ATPathSpecErrorCodeInvalidSpecString userInfo:@{ATPathSpecErrorSpecStringKey: string, NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Cannot mix different operators without parens: '%@'", string]}];
                failed = YES;
                return;
            }
            op = ATPathSpecTokenTypeUnion;
        } else if (type == ATPathSpecTokenTypeIntersection) {
            if (op != ATPathSpecTokenTypeNone && op != ATPathSpecTokenTypeIntersection) {
                if (outError)
                    *outError = [NSError errorWithDomain:ATPathSpecErrorDomain code:ATPathSpecErrorCodeInvalidSpecString userInfo:@{ATPathSpecErrorSpecStringKey: string, NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Cannot mix different operators without parens: '%@'", string]}];
                failed = YES;
                return;
            }
            op = ATPathSpecTokenTypeIntersection;
        } else if (type == ATPathSpecTokenTypeOpenParen) {
            pushContext();
        } else if (type == ATPathSpecTokenTypeCloseParen) {
            if (contexts.count == 0) {
                if (outError)
                    *outError = [NSError errorWithDomain:ATPathSpecErrorDomain code:ATPathSpecErrorCodeInvalidSpecString userInfo:@{ATPathSpecErrorSpecStringKey: string, NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Unmatched close paren: '%@'", string]}];
                failed = YES;
                return;
            }
            popContext();
        } else {
            abort();
        }
    } decodeTokens:YES];

    if (contexts.count > 0) {
        if (outError)
            *outError = [NSError errorWithDomain:ATPathSpecErrorDomain code:ATPathSpecErrorCodeInvalidSpecString userInfo:@{ATPathSpecErrorSpecStringKey: string, NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Unmatched open paren: '%@'", string]}];
        failed = YES;
    }

    if (failed)
        return nil;

    return flushContext();
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
        return [self pathSpecMatchingName:string type:type];
    } else {
        if (wildcardPos == 0) {
            NSString *suffix = [string substringFromIndex:wildcardPos + 1];
            NSUInteger secondWildcardPos = [suffix rangeOfCharacterFromSet:wildcards].location;
            if (secondWildcardPos == NSNotFound) {
                return [self pathSpecMatchingNameSuffix:[string substringFromIndex:1] type:type];
            }
        }
        return [self pathSpecMatchingNamePattern:string type:type];
    }

    return_error(nil, outError, ([NSError errorWithDomain:ATPathSpecErrorDomain code:ATPathSpecErrorCodeInvalidSpecString userInfo:@{ATPathSpecErrorSpecStringKey: originalString, NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid path spec syntax: %@", originalString]}]));
}

+ (ATPathSpec *)pathSpecMatchingName:(NSString *)name type:(ATPathSpecEntryType)type {
    return [[ATLiteralPathSpec alloc] initWithName:name type:type];
}
+ (ATPathSpec *)pathSpecMatchingNameSuffix:(NSString *)suffix type:(ATPathSpecEntryType)type {
    return [[ATSuffixPathSpec alloc] initWithSuffix:suffix type:type];
}
+ (ATPathSpec *)pathSpecMatchingNamePattern:(NSString *)pattern type:(ATPathSpecEntryType)type {
    return [[ATPatternPathSpec alloc] initWithPattern:pattern type:type];
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

+ (ATPathSpec *)pathSpecMatchingIntersectionOf:(NSArray *)specs {
    return [[ATIntersectionPathSpec alloc] initWithSpecs:specs];
}

//- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path {
//    abort();
//}

- (NSString *)stringRepresentationWithSyntaxOptions:(ATPathSpecSyntaxOptions)options {
    abort();
}

- (NSString *)description {
    return [self stringRepresentationWithSyntaxOptions:ATPathSpecSyntaxOptionsExtended];
}

@end


#pragma mark -


@implementation ATLiteralPathSpec

@synthesize name = _name;
@synthesize type = _type;

- (id)initWithName:(NSString *)name type:(ATPathSpecEntryType)type {
    self = [super init];
    if (self) {
        _name = [name copy];
        _type = type;
    }
    return self;
}

- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path type:(ATPathSpecEntryType)type {
    if (type != _type)
        return ATPathSpecMatchResultUnknown;

    NSString *name = [path lastPathComponent];
    return [_name isEqualToString:name];
}

- (NSString *)stringRepresentationWithSyntaxOptions:(ATPathSpecSyntaxOptions)options {
    return ATPathSpecSyntaxOptions_QuoteIfNeeded(ATPathSpecEntryType_AdjustTrailingSlashInPathString(_type, _name), options);
}

- (BOOL)isComplexExpression {
    return NO;
}

@end


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

- (NSString *)stringRepresentationWithSyntaxOptions:(ATPathSpecSyntaxOptions)options {
    return ATPathSpecSyntaxOptions_QuoteIfNeeded(ATPathSpecEntryType_AdjustTrailingSlashInPathString(_type, [NSString stringWithFormat:@"*%@", _suffix]), options);
}

- (BOOL)isComplexExpression {
    return NO;
}

@end


@implementation ATPatternPathSpec {
    NSString *_regex;
}

@synthesize pattern = _pattern;
@synthesize type = _type;

- (id)initWithPattern:(NSString *)pattern type:(ATPathSpecEntryType)type {
    self = [super init];
    if (self) {
        _pattern = [pattern copy];
        _type = type;
        _regex = ATPathSpec_RegexFromPatternString(_pattern);
    }
    return self;
}

- (ATPathSpecMatchResult)matchResultForPath:(NSString *)path type:(ATPathSpecEntryType)type {
    if (type != _type)
        return ATPathSpecMatchResultUnknown;

    NSString *name = [path lastPathComponent];
    return [name isMatchedByRegex:_regex];
}

- (NSString *)stringRepresentationWithSyntaxOptions:(ATPathSpecSyntaxOptions)options {
    return ATPathSpecSyntaxOptions_QuoteIfNeeded(ATPathSpecEntryType_AdjustTrailingSlashInPathString(_type, _pattern), options);
}

- (BOOL)isComplexExpression {
    return NO;
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

- (BOOL)isComplexExpression {
    return YES;
}

- (NSString *)stringRepresentationWithSyntaxOptions:(ATPathSpecSyntaxOptions)options {
    NSMutableArray *strings = [NSMutableArray new];
    for (ATPathSpec *spec in _specs) {
        [strings addObject:[spec parenthesizedStringRepresentationWithSyntaxOptions:options]];
    }
    return [strings componentsJoinedByString:@" | "];
}

@end


#pragma mark -

@implementation ATIntersectionPathSpec

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
        if (result != ATPathSpecMatchResultMatched)
            return ATPathSpecMatchResultUnknown;
    }
    return ATPathSpecMatchResultMatched;
}

- (BOOL)isComplexExpression {
    return YES;
}

- (NSString *)stringRepresentationWithSyntaxOptions:(ATPathSpecSyntaxOptions)options {
    NSMutableArray *strings = [NSMutableArray new];
    for (ATPathSpec *spec in _specs) {
        [strings addObject:[spec parenthesizedStringRepresentationWithSyntaxOptions:options]];
    }
    return [strings componentsJoinedByString:@" & "];
}

@end






