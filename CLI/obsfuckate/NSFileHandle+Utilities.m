//
//  NSFileHandle+Utilities.m
//  Created by Hamilton Feltman on 2020/9/15.
//

#import <Foundation/Foundation.h>
#import "NSFileHandle+Utilities.h"

@implementation NSFileHandle (Utilities)

- (BOOL)writeString:(NSString *)str error:(out NSError **)error {
	if (@available(iOS 13.0, macOS 10.15, *)) {
		return [self writeData:[str dataUsingEncoding:NSUTF8StringEncoding] error:error];
	} else {
		@try {
			[self writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
		} @catch (NSException *exception) {
			if (error) {
				*error = [NSError.alloc initWithDomain:NSCocoaErrorDomain code:0 userInfo:@{
					NSLocalizedDescriptionKey: exception.description,
				}];
			}
			return NO;
		}
		return YES;
	}
}

- (BOOL)writeString:(NSString *)str {
	return [self writeString:str error:nil];
}

@end
