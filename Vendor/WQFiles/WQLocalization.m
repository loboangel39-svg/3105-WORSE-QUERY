//
//  WQLocalization.m
//  WQ Files
//

#import "WQLocalization.h"

// An immutable string that the lookup helpers recognize and pass through.
@interface WQVerbatimString : NSString
@end

@implementation WQVerbatimString {
    NSString *_text;
}

- (instancetype)initWithText:(NSString *)text
{
    if ((self = [super init])) _text = [text copy];
    return self;
}

- (NSUInteger)length { return _text.length; }
- (unichar)characterAtIndex:(NSUInteger)index { return [_text characterAtIndex:index]; }
- (void)getCharacters:(unichar *)buffer range:(NSRange)range { [_text getCharacters:buffer range:range]; }
- (id)copyWithZone:(NSZone *)__unused zone { return self; }

@end

NSString *WQVerbatim(NSString *text)
{
    if (!text || [text isKindOfClass:WQVerbatimString.class]) return text;
    return [[WQVerbatimString alloc] initWithText:text];
}

BOOL WQIsVerbatim(NSString *text)
{
    return [text isKindOfClass:WQVerbatimString.class];
}

NSString *WQLocalized(NSString *key)
{
    if (!key.length || WQIsVerbatim(key)) return key;
    NSBundle *bundle = [NSBundle bundleWithPath:[NSBundle.mainBundle pathForResource:@"WQFilesResources" ofType:@"bundle"]];
    if (!bundle) return NSLocalizedString(key, nil); // standalone regression/runtime bundle
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *code = [defaults stringForKey:@"WQLanguage"] ?: [defaults stringForKey:@"appLanguage"] ?: @"es";
    NSString *path = [bundle pathForResource:code ofType:@"lproj"];
    if (!path) path = [bundle pathForResource:[code componentsSeparatedByString:@"-"].firstObject ofType:@"lproj"];
    if (!path) path = [bundle pathForResource:@"en" ofType:@"lproj"]; // preserve original fallback for unsupported explicit languages
    NSBundle *localized = path ? [NSBundle bundleWithPath:path] : bundle;
    return [localized localizedStringForKey:key value:key table:nil];
}

NSString *WQLocalizedNullable(NSString *text)
{
    return text ? WQLocalized(text) : nil;
}

NSString *WQLocalizedFormat(NSString *key, ...)
{
    va_list args;
    va_start(args, key);
    NSString *format = WQLocalized(key);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    return text;
}
