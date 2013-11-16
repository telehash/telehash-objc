//
//  CTRAES256.h
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CTRAES256Encryptor : NSObject
+(NSData*)encryptPlaintext:(NSData*)data key:(NSData*)key iv:(NSData*)iv;
-(id)initWithKey:(NSData*)key iv:(NSData*)iv;
-(NSData*)encryptPlaintext:(NSData*)plaintext;
@end

@interface CTRAES256Decryptor : NSObject
+(NSData*)decryptPlaintext:(NSData*)data key:(NSData*)key iv:(NSData*)iv;
-(id)initWithKey:(NSData*)key iv:(NSData*)iv;
-(NSData*)decryptCiphertext:(NSData*)ciphertext;
@end