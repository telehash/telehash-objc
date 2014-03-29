//
//  GCMAES256.h
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GCMAES256Encryptor : NSObject
@property (readonly) NSMutableData* cipherText;
@property (readonly) NSMutableData* mac;
+(GCMAES256Encryptor*)encryptPlaintext:(NSData*)data key:(NSData*)key iv:(NSData*)iv;
+(GCMAES256Encryptor*)encryptPlaintext:(NSData*)data key:(NSData*)key iv:(NSData*)iv macLength:(unsigned int)macLength;
-(id)initWithKey:(NSData*)key iv:(NSData*)iv;
@end

@interface GCMAES256Decryptor : NSObject
@property (readonly) NSMutableData* plainText;
+(GCMAES256Decryptor*)decryptPlaintext:(NSData*)data mac:(NSData*)mac key:(NSData*)key iv:(NSData*)iv;
-(id)initWithKey:(NSData*)key iv:(NSData*)iv;
@end