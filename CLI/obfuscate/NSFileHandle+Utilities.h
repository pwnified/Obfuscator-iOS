//
//  NSFileHandle+Utilities.h
//  Created by Hamilton Feltman on 2020/9/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSFileHandle (Utilities)
- (BOOL)writeString:(NSString *)str error:(out NSError **)error;
- (BOOL)writeString:(NSString *)str;
@end

NS_ASSUME_NONNULL_END
