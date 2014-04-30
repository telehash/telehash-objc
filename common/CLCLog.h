/*
 * Copyright 2008 Jason Coco (CoLa Code)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <asl.h>

#define CLC_LEVEL_EMERG		ASL_LEVEL_EMERG
#define CLC_LEVEL_ALERT		ASL_LEVEL_ALERT
#define CLC_LEVEL_CRIT		ASL_LEVEL_CRIT
#define CLC_LEVEL_ERR		ASL_LEVEL_ERR
#define CLC_LEVEL_WARNING	ASL_LEVEL_WARNING
#define CLC_LEVEL_NOTICE	ASL_LEVEL_NOTICE
#define CLC_LEVEL_INFO		ASL_LEVEL_INFO
#define CLC_LEVEL_DEBUG		ASL_LEVEL_DEBUG

int CLCLog(int level, NSString *format, ...);
int CLCLogv(int level, NSString *format, va_list arglist);

#define CLCLogEmerg(...)		CLCLog(CLC_LEVEL_EMERG,   __VA_ARGS__)
#define CLCLogAlert(...)		CLCLog(CLC_LEVEL_ALERT,   __VA_ARGS__)
#define CLCLogCritical(...)		CLCLog(CLC_LEVEL_CRIT,    __VA_ARGS__)
#define CLCLogError(...)		CLCLog(CLC_LEVEL_ERR,     __VA_ARGS__)
#define CLCLogWarning(...)		CLCLog(CLC_LEVEL_WARNING, __VA_ARGS__)
#define CLCLogNotice(...)		CLCLog(CLC_LEVEL_NOTICE,  __VA_ARGS__)
#define CLCLogInfo(...)			CLCLog(CLC_LEVEL_INFO,    __VA_ARGS__)
#define CLCLogDebug(...)		CLCLog(CLC_LEVEL_DEBUG,   __VA_ARGS__)

@interface CLCLogger : NSObject
{
	aslclient log_client;
	const NSString *threadKey;
	NSString *facility_str;
	NSInteger filter_level;
}

+(CLCLogger *)defaultLogger;
-(CLCLogger *)init;
-(CLCLogger *)initWithFacility:(NSString*)facility;
-(CLCLogger *)initWithAttributes:(NSDictionary*)attributes;
-(CLCLogger *)initWithFacility:(NSString*)facility andAttributes:(NSDictionary*)attributes;
-(void)dealloc;

-(void)setAttribute:(NSString*)attribute forKey:(NSString*)key;
-(void)removeAttributeForKey:(NSString*)key;
-(NSString*)attributeForKey:(NSString*)key;
-(void)setFilter:(NSInteger)level;
-(NSInteger)filter;
+(void)setRemoteFilter:(NSInteger)level;

-(NSInteger)logMessage:(NSString*)format, ...;
-(NSInteger)logUsingLevel:(NSInteger)level withMessage:(NSString*)format, ...;
-(NSInteger)logUsingLevel:(NSInteger)level withMessage:(NSString*)format arguments:(va_list)args;

-(NSInteger)debug:(NSString*)format, ...;
-(NSInteger)info:(NSString*)format, ...;
-(NSInteger)notice:(NSString*)format, ...;
-(NSInteger)warning:(NSString*)format, ...;
-(NSInteger)error:(NSString*)format, ...;
-(NSInteger)critical:(NSString*)format, ...;
-(NSInteger)alert:(NSString*)format, ...;
-(NSInteger)emergency:(NSString*)format, ...;

@end