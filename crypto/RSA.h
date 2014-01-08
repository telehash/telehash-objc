//
//  RSA.h
//  telehash
//
//  Created by Thomas Muldowney on 9/30/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSA : NSObject

@property (readonly) unsigned long signatureLength;
@property (readonly) NSData* DERPublicKey;
@property (readonly) NSData* DERPrivateKey;

+(id)generateRSAKeysOfLength:(unsigned int)length;
+(id)RSAFromPublicKeyPath:(NSString*)publicKeyPath privateKeyPath:(NSString*)privateKeyPath;
// privateKey may be nil
+(id)RSAWithPublicKey:(NSData*)publicKey privateKey:(NSData*)privateKey;

-(NSData*)sign:(NSData*)data;

-(unsigned long) encryptedLength:(unsigned long)plaintext;
-(NSData*) encrypt:(NSData*)plaintext;

-(NSData*) decrypt:(NSData*)cipherText;

-(BOOL) verify:(NSData*)message withSignature:(NSData*)signature;

// XXX:  This is just for current testing
-(void)savePublicKey:(NSString*)publicPath privateKey:(NSString*)privatePath;
@end
