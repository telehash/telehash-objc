//
//  ECDH.h
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ECDH : NSObject
{
@private
    NSMutableData* _publicKey;
    NSMutableData* _privateKey;
}

@property (readonly) unsigned long publicKeyLength;
@property (readonly) unsigned long privateKeyLength;
@property (readonly) unsigned long agreedValueLength;
@property (atomic) NSMutableData* publicKey;

-(id)init;
-(void)dealloc;

-(NSData*)agreeWithRemotePublicKey:(NSData*)remotePublicKey;

@end
