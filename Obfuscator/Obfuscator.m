//
//  Obfuscator.m
//
//  Created by PJ on 11/07/2015.
//  Copyright (c) 2015 PJ Engineering and Business Solutions Pty Ltd. All rights reserved.
//

#import "Obfuscator.h"

#include <CommonCrypto/CommonCrypto.h>

@interface Obfuscator ()
    @property (nonatomic, strong) NSString *salt;

    + (NSString *)hashSaltUsingSHA1:(NSString *)salt;
    + (NSString *)printHex:(NSString *)string;
    + (NSString *)printHex:(NSString *)string WithKey:(NSString *)key;
    - (NSString *)hexByObfuscatingString:(NSString *)string silence:(BOOL)silence;
    + (BOOL)generateCodeWithSaltUnsafe:(NSString *)salt WithStrings:(NSArray *)strings silence:(BOOL)silence successfulP:(NSMutableArray **)successfulP unsuccessfulP:(NSMutableArray **)unsuccessfulP;
    + (NSArray *) allPermutationsOfArray:(NSArray*)array;
    + (NSString *) stringFromClasses:(NSArray *)classes;
    + (NSDictionary *) logCodeWithSuccessful:(NSArray *)successful unsuccessful:(NSArray *)unsuccessful;
@end

@implementation Obfuscator

// Keeps a database of salts in unhashed format.
// Essential when bridging Obfuscator to Swift since
// + (instancetype)newWithSalt:(Class)class, ...
// does not bridge over.
static NSMutableDictionary *saltDatabase;

+ (void)initialize {
    saltDatabase = @{}.mutableCopy;
}

+ (void)storeKey:(NSString *)key classes:(NSArray<Class> *)classes {
    NSMutableString *salt = @"".mutableCopy;
    for (id class in classes) {
        [salt appendString:NSStringFromClass(class)];
    }
    @synchronized (saltDatabase) {
        saltDatabase[key] = salt.copy;
    }
}

+ (void)storeKey:(NSString *)key forSalt:(Class)class, ... {
    NSMutableArray *classes = @[].mutableCopy;
    if (class) { // The first argument isn't part of the varargs list,
        id eachClass;
        va_list argumentList;
        [classes addObject:class];
        va_start(argumentList, class); // Start scanning for arguments after class.
        while ((eachClass = va_arg(argumentList, id))) // As many times as we can get an argument of type "id"
            [classes addObject:eachClass];
        va_end(argumentList);
    }
    [self storeKey:key classes:classes.copy];
}

+ (instancetype)newWithSalt:(Class)class, ...
{
    NSMutableString *classes;
    
    id eachClass;
    va_list argumentList;
    if (class) // The first argument isn't part of the varargs list,
    {
        classes = [[NSMutableString alloc] initWithString:NSStringFromClass(class)];
        va_start(argumentList, class); // Start scanning for arguments after class.
        while ((eachClass = va_arg(argumentList, id))) // As many times as we can get an argument of type "id"
            [classes appendString:NSStringFromClass(eachClass)];
        va_end(argumentList);
    }
    
    return [self newWithSaltUnsafe:[classes copy]];
}

+ (instancetype)newUsingStoredSalt:(NSString *)key
{
    NSString *storedSalt = nil;
    @synchronized (saltDatabase) {
        storedSalt = [saltDatabase valueForKey:key];
    }
    if (storedSalt == nil)
        return nil;
    
    Obfuscator *o = [Obfuscator newWithSaltUnsafe:storedSalt];
    
    return o;
}

+ (instancetype)newWithSaltUnsafe:(NSString *)string
{
    Obfuscator *o = [[Obfuscator alloc] init];
    
    o.salt = [self hashSaltUsingSHA1:string];
    
    return o;
}

- (NSString *)hexByObfuscatingString:(NSString *)string
{
    return [self hexByObfuscatingString:string silence:NO];
}

- (NSString *)hexByObfuscatingString:(NSString *)string silence:(BOOL)silence
{
#if defined (DEBUG) || defined (CLI_ENABLED)
    if (string) {
        //Obfuscate the string
        NSString *obfuscatedString = [self reveal:string.UTF8String];

        //Test if Obfuscator worked
        NSString *backToOriginal = [self reveal:obfuscatedString.UTF8String];

        if ([string isEqualToString:backToOriginal]) {
            NSString *hexCode = [Obfuscator printHex:obfuscatedString];
            if (silence == NO) {
                NSLog(@"Objective-C Code:\nextern const char *key;\n//Original: \"%@\"\n%@\nconst char *key = &_key[0];\n*********REMOVE THIS BEFORE DEPLOYMENT*********\n", string, hexCode);
            }
            return obfuscatedString;
        }
        if (silence == NO) {
            NSLog(@"Could not obfuscate: %@ - Use different salt", string);
        }
    }
#endif
    return nil;
}

+ (NSString *)reveal:(const char *)string UsingStoredSalt:(NSString *)key
{
    NSString *storedSalt = nil;
    @synchronized (saltDatabase) {
        storedSalt = [saltDatabase valueForKey:key];
    }
    if (storedSalt == nil)
        return nil;
    
    Obfuscator *o = [Obfuscator newWithSaltUnsafe:storedSalt];
    return [o reveal:string];
}


// This was a possible bug... NSData is immutable. It was casting the const away and stomping the internal data.
// Changed to NSMutableData and (char *)[data mutableBytes]
- (NSString *)reveal:(const char *)string {
    if (!string) {
        return nil;
    }
    // Create data object from the C-String
    NSMutableData *data = [@(string) dataUsingEncoding:NSUTF8StringEncoding].mutableCopy;
    
    // Get pointer to data to obfuscate
    char *dataPtr = (char *)data.mutableBytes;
    const char *dataEnd = dataPtr + data.length;
    
    // Get pointer to key data
    NSData *k = [_salt dataUsingEncoding:NSUTF8StringEncoding];
    const char *keyData = k.bytes;
    
    // Points to each char in sequence in the key
    const char *keyPtr = keyData;
    const char *keyEnd = keyData + k.length;

    // For each character in data, xor with current value in key
    while (dataPtr < dataEnd) {
        // Replace current character in data with
        // current character xor'd with current key value.
        // Bump each pointer to the next character
        *dataPtr = *dataPtr ^ *keyPtr;
        dataPtr++;
        keyPtr++;
        
        // If at end of key data, reset count and
        // set key pointer back to start of key value
        if (keyPtr >= keyEnd) {
            keyPtr = keyData;
        }
    }
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

#pragma mark - Generating Valid Objective-C Code

+ (BOOL)generateCodeWithSaltUnsafe:(NSString *)salt WithStrings:(NSArray *)strings
{
#if defined (DEBUG) || defined (CLI_ENABLED)
    return [self generateCodeWithSaltUnsafe:salt WithStrings:strings silence:NO successfulP:nil unsuccessfulP:nil];
#else
    return NO;
#endif
}

+ (NSDictionary *)generateCodeWithSalt:(NSArray *)classes WithStrings:(NSArray *)strings
{
#if defined (DEBUG) || defined (CLI_ENABLED)
    NSArray *successful = nil;
    NSArray *unsuccessful = nil;
    NSArray *selectedClasses = nil;
    
    //Get permutations of salt
    NSArray *permutations = [self allPermutationsOfArray:classes];
    
    //Loop through all permutations
    for (NSArray *permutation in permutations) {
        NSString *salt = [self stringFromClasses:permutation];
//        NSLog(@"*+*+*+*+*+**+*+*+*+*+*+*+*+*+*+*+*");
        
        //Create MutableArrays to temporarily store successful and unsuccessful obfuscated strings
        NSMutableArray *s = [[NSMutableArray alloc] init];
        NSMutableArray *u = [[NSMutableArray alloc] init]; //Stores any unsuccessful strings
        
        [self generateCodeWithSaltUnsafe:salt WithStrings:strings silence:YES successfulP:&s unsuccessfulP:&u];
        
        if (successful == nil)
        {
            successful = [s copy];
            unsuccessful = [u copy];
            selectedClasses = permutation;
        }
        else
        {
            if ([successful count] < [s count])
            {
                //This combination is better
                successful = [s copy];
                unsuccessful = [u copy];
                selectedClasses = permutation;
            }
            
            if ([u count] == 0) //Perfect combination. All strings were obfuscated.
            {
                break;
            }
        }
        
//        NSLog(@"*+*+*+*+*+**+*+*+*+*+*+*+*+*+*+*+*");
    }

    //Print out best salt.
    NSMutableArray *assault = @[].mutableCopy;
    for (Class class in selectedClasses) {
        [assault addObject:[NSString stringWithFormat:@"%@.class", NSStringFromClass(class)]];
    }
    NSString *salt = [assault componentsJoinedByString:@", "];

    NSLog(@"🧂 Salt used (in this order): %@\n", salt);
    
    NSDictionary *code = [self logCodeWithSuccessful:successful unsuccessful:unsuccessful];
    return @{@"successful": successful, @"unsuccessful": unsuccessful, @"salt": salt?:@"", @"code": code?:@{} };
#else
    return nil;
#endif
}

+ (BOOL)generateCodeWithSaltUnsafe:(NSString *)salt WithStrings:(NSArray *)strings silence:(BOOL)silence successfulP:(NSMutableArray **)successfulP unsuccessfulP:(NSMutableArray **)unsuccessfulP;
{
#if defined (DEBUG) || defined (CLI_ENABLED)
    // Function will return YES if process was successful in obfuscating ALL provided strings.
    // If even 1 string was not possible to obfuscate, then function will return NO.
    BOOL allSuccess = YES;
    
    //Store Successful and Unsuccessful Obfuscations
    NSMutableArray *successful = (successfulP == nil) ? [[NSMutableArray alloc] init] : *successfulP;
    NSMutableArray *unsuccessful = (unsuccessfulP == nil) ? [[NSMutableArray alloc] init] : *unsuccessfulP;
    
    Obfuscator *o = [Obfuscator newWithSaltUnsafe:salt];
    
    //Loop through list of strings
    for (id obj in strings) {
        
        if ([obj isKindOfClass:[NSString class]])
        {
            NSString *string = obj;
            NSString *result = [o hexByObfuscatingString:string silence:YES];
            if (result) {
                [successful addObject:@{@"original": string, @"obfuscated": result}];
            } else {
                [unsuccessful addObject:string];
                allSuccess = NO;
            }
        }
        else if ([obj isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dict = obj;
            for (NSString *key in [dict.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
                NSString *value = dict[key];
                NSString *result = [o hexByObfuscatingString:value silence:YES];
                if (result) {
                    [successful addObject:@{@"original": value, @"key": key, @"obfuscated": result}];
                } else {
                    [unsuccessful addObject:value];
                    allSuccess = NO;
                }
            }
        }
    }
    
    if (silence == NO)
    {
        [self logCodeWithSuccessful:successful unsuccessful:unsuccessful];
    }
    return allSuccess;
#else
    return NO;
#endif
}

#pragma mark - Helper Functions

/*!
 * @brief Hashes salt using SHA1 algorithm.
 * @param salt Salt used for Obfuscation technique
 * @return NSString containing SHA1 hash of salt
 */
+ (NSString *)hashSaltUsingSHA1:(NSString *)salt
{
    NSData *d = [salt dataUsingEncoding:NSUTF8StringEncoding];
    
    // Get the SHA1 of a class name, to form the obfuscator.
    unsigned char obfuscator[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(d.bytes, (CC_LONG)d.length, obfuscator);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
    {
        [output appendFormat:@"%02x", obfuscator[i]];
    }
    
    return [output copy];
}

+ (NSString *)printHex:(NSString *)string
{
    return [self printHex:string WithKey:nil];
}

/*!
 * @brief Generates the Objective-C Code to define and initialize a global C-String (initialized in hexadecimal).
 * @discussion Hard-coded NSString objects are easily discoverable when using a jail-broken iPhone.
 * It is better to obfuscate the desired strings as C-Strings initialized with hashed data.
 * @param string A string that you wish to hardcode in your app as a C-String.
 * @param key The name of the generated C-Array that refers to the C-String.
 * @return C code to embed in your app to define and initialize a global C-String.
 */
+ (NSString *)printHex:(NSString *)string WithKey:(NSString *)key {

    NSMutableString *temp = [NSMutableString stringWithFormat:@"const char _%@[] = { ", key ?: @"key"];
    for (int i = 0; i < [string length]; i++) {
        [temp appendFormat:@"0x%X, ", [string characterAtIndex:i]];
    }
    [temp appendString:@"0x0 };"];
    return [temp copy];
}

+ (NSDictionary *) logCodeWithSuccessful:(NSArray *)successful unsuccessful:(NSArray *)unsuccessful
{
    // Print out unsuccessful strings
    if ([unsuccessful count] != 0)
    {
        NSMutableString *final = [[NSMutableString alloc] initWithString:@"Could not obfuscate these strings:\n"];
        for (NSString *u in unsuccessful) {
            [final appendFormat:@"%@\n", u];
        }
        NSLog(@"%@-------------------------------", final);
    }
    
    
    //Print out Objective-C code for successful strings
    if ([successful count] != 0)
    {
        NSMutableString *header = @"".mutableCopy;
        NSMutableString *implementation = @"".mutableCopy;
        
        for (NSDictionary *s in successful) {
            NSString *key = [s objectForKey:@"key"];
            if (key == nil)
            {
                [header appendFormat:@"extern const char *key;\n"];
                [implementation appendFormat:@"//Original: \"%@\"\n%@\nconst char *key = &_%@[0];\n\n", s[@"original"], [self printHex:s[@"obfuscated"]], @"key"];
            }
            else{
                [header appendFormat:@"extern const char *%@;\n", key];
                [implementation appendFormat:@"//Original: \"%@\"\n%@\nconst char *%@ = &_%@[0];\n\n",s[@"original"],[self printHex:s[@"obfuscated"] WithKey:s[@"key"]],key,key];
            }
        }
        
        //Header and Implentation file
        NSLog(@"Objective-C Code:\n\n// **********Globals.h**********\n%@\n// **********Globals.m**********\n%@", header, implementation);
        return @{@"header": header, @"implementation": implementation};
    }
    return nil;
}


/*!
 * @brief Concats a list of class names into a string.
 * @param classes An NSArray which contains a list of Classes of type Class.
 * e.g. [NSString class]
 */
+ (NSString *) stringFromClasses:(NSArray *)classes
{
    NSMutableString *finalString = [[NSMutableString alloc] initWithString:@""];
    
    for (id class in classes) {
        [finalString appendString:NSStringFromClass(class)];
    }
    
    return [finalString copy];
}


/*!
 * @brief Generates all permutations of contents of array.
 */
+ (NSArray *) allPermutationsOfArray:(NSArray*)array
{
    NSMutableArray *permutations = [NSMutableArray new];
    
    for (int i = 0; i < array.count; i++) { // for each item in the array
        if (permutations.count == 0) { // first time only
            
            for (id item in array) { // create a 2d array starting with each of the individual items
                NSMutableArray* partialList = [NSMutableArray arrayWithObject:item];
                [permutations addObject:partialList]; // where array = [1,2,3] permutations = [ [1] [2] [3] ] as a starting point for all options
            }
            
        } else { // second and remainder of the loops
            
            NSMutableArray *permutationsCopy = [permutations mutableCopy]; // copy the original array of permutations
            [permutations removeAllObjects]; // remove all from original array
            
            for (id item in array) { // for each item in the original list
                
                for (NSMutableArray *partialList in permutationsCopy) { // loop through the arrays in the copy
                    
                    if ([partialList containsObject:item] == false) { // add an item to the partial list if its not already
                        
                        // update a copy of the array
                        NSMutableArray *newArray = [NSMutableArray arrayWithArray:partialList];
                        [newArray addObject:item];
                        
                        // add to the final list of permutations
                        [permutations addObject:newArray];
                    }
                }
            }
        }
    }
    
    return [permutations copy];
}
@end
