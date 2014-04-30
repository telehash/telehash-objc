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

#import <Foundation/Foundation.h>
#import "CLCLog.h"

#include <asl.h>
#include <stdarg.h>

@interface CLCLogger (privateFunctions)
-(id)initDefaultCenter;
-(void)threadStateChange:(NSNotification *)notification;
-(aslclient)logClient;
@end

@interface CLCLogger (Private)
-(void)threadDidExit:(NSNotification *)notification;
@end

static NSLock *lock = nil;
static CLCLogger *defaultLog = nil;
static aslclient default_client = NULL;

// to support multi-threaded environments
static BOOL isMultithreaded = NO;
static NSMutableSet *threads = nil;
static NSMutableSet *loggers = nil;

static NSString *CLC_DEF_CLI_KEY = @"org.telehash.objc";

#define CLC_LEVEL_DEFAULT	CLC_LEVEL_DEBUG

static int CLCLogv_priv(CLCLogger *, int, NSString *, va_list);

#if defined(CLCDEBUG)
#define CLC_OPT_DEBUG	ASL_OPT_STDERR
#else
#define CLC_OPT_DEBUG	0
#endif

int CLCLog(int level, NSString *format, ...)
{
	va_list args;
	
	va_start(args, format);
	int status = CLCLogv(level, format, args);
	va_end(args);
	return status;
}

int CLCLogv(int level, NSString *format, va_list arglist)
{
	if( defaultLog == nil ) defaultLog = [CLCLogger defaultLogger];
	return CLCLogv_priv(defaultLog, level, format, arglist);
}

static int CLCLogv_priv(CLCLogger *caller, int level, NSString *format, va_list arglist)
{
	NSString *stringToLog = [[NSString alloc] initWithFormat:format arguments:arglist];
	aslclient client;
	
	if( !(ASL_FILTER_MASK(level) & [caller filter]) ) {
		return 0;
	}
	
	if( caller != defaultLog || isMultithreaded )
		client = [caller logClient];
	else
		client = default_client;
	if( isMultithreaded && client == NULL ) {
		NSMutableDictionary *threadLocal = [[NSThread currentThread] threadDictionary];
		NSValue *defaultClientValue = [threadLocal valueForKey:CLC_DEF_CLI_KEY];
		if( defaultClientValue == NULL ) {
			aslclient cli = asl_open(NULL, "com.apple.console", ASL_OPT_STDERR);
			defaultClientValue = [NSValue valueWithPointer:cli];
			[threadLocal setObject:defaultClientValue forKey:CLC_DEF_CLI_KEY];
		}
		client = (aslclient)[defaultClientValue pointerValue];
	}
	return asl_log(client, NULL, level, [stringToLog UTF8String]);
}

@implementation CLCLogger
+(void)initialize
{
	lock = [[NSLock alloc] init];
#if defined(CLCDEBUG)
	asl_add_log_file(NULL, STDERR_FILENO);
#endif
}

+(CLCLogger *)defaultLogger
{
	[lock lock];
	if( !defaultLog ) defaultLog = [[CLCLogger alloc] initDefaultCenter];
	[lock unlock];
	
	return defaultLog;
}

-(CLCLogger*)init
{
	return [self initWithFacility:@"com.apple.console" andAttributes:nil];
}

-(CLCLogger*)initWithFacility:(NSString*)facility
{
	return [self initWithFacility:facility andAttributes:nil];
}

-(CLCLogger*)initWithAttributes:(NSDictionary*)attributes
{
	return [self initWithFacility:@"com.apple.console" andAttributes:attributes];
}

-(CLCLogger*)initWithFacility:(NSString*)facility andAttributes:(NSDictionary*)attributes
{
	if( (self = [super init]) ) {
		log_client = asl_open(NULL, [facility UTF8String], CLC_OPT_DEBUG);
		facility_str = [facility copy];
		threadKey = [[NSString alloc] initWithFormat:@"%@.%p", CLC_DEF_CLI_KEY, self];
		filter_level = ASL_FILTER_MASK_UPTO(CLC_LEVEL_DEFAULT);
		if( [NSThread isMultiThreaded] ) {
			isMultithreaded = YES;
			NSMutableDictionary *dict = [[NSThread mainThread] threadDictionary];
			[dict setObject:[NSValue valueWithPointer:log_client] forKey:threadKey];
			[[NSNotificationCenter defaultCenter] addObserver:self
				selector:@selector(threadDidExit:)
				name:NSThreadWillExitNotification object:nil];
			if( threads == nil ) {
				threads = [[NSMutableSet alloc] initWithCapacity:2];
				loggers = [[NSMutableSet alloc] initWithCapacity:1];
			}
			[threads addObject:[NSThread currentThread]];
			[loggers addObject:self];
		} 
	}
	return self;
}

-(void)dealloc
{
	if( self != defaultLog )
		CLCLogDebug(@"CLCLogger-->dealloc-->self=%@", self);
	if( !isMultithreaded ) {
		[[NSNotificationCenter defaultCenter] removeObserver:self
			name:NSWillBecomeMultiThreadedNotification object:nil];
		asl_close(log_client);
	} else {
		[[NSNotificationCenter defaultCenter] removeObserver:self
			name:NSThreadWillExitNotification object:nil];
		for( NSThread *t in threads ) {
			NSMutableDictionary *d = [t threadDictionary];
			NSValue *v = [d objectForKey:threadKey];
			if( v == nil ) continue;
			aslclient cli = [v pointerValue];
			asl_close(cli);
			[d removeObjectForKey:threadKey];
		}
	}
}

-(void)setAttribute:(NSString*)attribute forKey:(NSString*)key
{
	
}

-(void)removeAttributeForKey:(NSString*)key
{
	
}

-(NSString*)attributeForKey:(NSString*)key
{
	return nil;
}

-(void)setFilter:(NSInteger)filter
{
	filter_level = ASL_FILTER_MASK_UPTO(filter);
}

-(NSInteger)filter
{
	return filter_level;
}

+(void)setRemoteFilter:(NSInteger)filter
{
	// do nothing for now
}

-(NSInteger)logMessage:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = [self logUsingLevel:CLC_LEVEL_INFO withMessage:format arguments:args];
	va_end(args);
	
	return status;
}

-(NSInteger)logUsingLevel:(NSInteger)level withMessage:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = [self logUsingLevel:level withMessage:format arguments:args];
	va_end(args);
	
	return status;
}

-(NSInteger)logUsingLevel:(NSInteger)level withMessage:(NSString *)format arguments:(va_list)args
{
	return CLCLogv_priv(self, level, format, args);
}

-(NSInteger)debug:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = CLCLogv_priv(self, CLC_LEVEL_DEBUG, format, args);
	va_end(args);
	
	return status;
}

-(NSInteger)info:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = CLCLogv_priv(self, CLC_LEVEL_INFO, format, args);
	va_end(args);
	
	return status;
}

-(NSInteger)notice:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = CLCLogv_priv(self, CLC_LEVEL_NOTICE, format, args);
	va_end(args);
	
	return status;
}

-(NSInteger)warning:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = CLCLogv_priv(self, CLC_LEVEL_WARNING, format, args);
	va_end(args);
	
	return status;
}

-(NSInteger)critical:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = CLCLogv_priv(self, CLC_LEVEL_CRIT, format, args);
	va_end(args);
	
	return status;
}

-(NSInteger)error:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = CLCLogv_priv(self, CLC_LEVEL_ERR, format, args);
	va_end(args);
	
	return status;
}

-(NSInteger)alert:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = CLCLogv_priv(self, CLC_LEVEL_ALERT, format, args);
	va_end(args);
	
	return status;
}

-(NSInteger)emergency:(NSString *)format, ...
{
	va_list args;
	
	va_start(args, format);
	NSInteger status = CLCLogv_priv(self, CLC_LEVEL_EMERG, format, args);
	va_end(args);
	
	return status;
}

@end

@implementation CLCLogger (Private)

-(id)initDefaultCenter
{
	if( (self = [super init]) ) {
		log_client = default_client = NULL;
		facility_str = @"com.apple.console";
		threadKey = [[NSString alloc] initWithFormat:@"%@.default", CLC_DEF_CLI_KEY];
		filter_level = ASL_FILTER_MASK_UPTO(CLC_LEVEL_DEFAULT);
		if ( ![NSThread isMultiThreaded] ) {
			[[NSNotificationCenter defaultCenter] addObserver:self
				selector:@selector(threadStateChange:)
				name:NSWillBecomeMultiThreadedNotification object:nil];
		} else {
			isMultithreaded = YES;
			[[NSNotificationCenter defaultCenter] addObserver:self
				selector:@selector(threadDidExit:)
				name:NSThreadWillExitNotification object:nil];
			if( threads == nil ) {
				threads = [[NSMutableSet alloc] initWithCapacity:2];
				loggers = [[NSMutableSet alloc] initWithCapacity:1];
			}
			[threads addObject:[NSThread currentThread]];
			[loggers addObject:self];
			aslclient cli = asl_open(NULL, "com.apple.console", CLC_OPT_DEBUG);
			NSMutableDictionary *dict = [[NSThread mainThread] threadDictionary];
			[dict setObject:[NSValue valueWithPointer:cli] forKey:threadKey];
		}
	}
	return self;
}

-(void)threadDidExit:(NSNotification *)notification
{
	[threads removeObject:[NSThread currentThread]];
	NSMutableDictionary *dict = [[NSThread currentThread] threadDictionary];
	NSValue *v = [dict objectForKey:threadKey];
	if( v == nil ) return;
	aslclient cli = [v pointerValue];
	asl_close(cli);
	[dict removeObjectForKey:threadKey];
}

-(void)threadStateChange:(NSNotification *)notification
{
	// initialize the multi-threaded environment
	while( ![lock tryLock] );
	if( threads == nil ) {
		threads = [[NSMutableSet alloc] initWithCapacity:2];
		loggers = [[NSMutableSet alloc] initWithCapacity:1];
	}
	[lock unlock];
	isMultithreaded = YES;
	CLCLogDebug(@"In threadStateChange[%@]: %@", self, notification);
	[[NSNotificationCenter defaultCenter] removeObserver:self
		name:NSWillBecomeMultiThreadedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(threadDidExit:)
		name:NSThreadWillExitNotification object:nil];
	[threads addObject:[NSThread mainThread]];
	[threads addObject:[NSThread currentThread]];
	[loggers addObject:self];
}

-(aslclient)logClient
{
	if( !isMultithreaded ) return log_client;
	NSMutableDictionary *dict = [[NSThread currentThread] threadDictionary];
	NSValue *v = [dict objectForKey:threadKey];
	if( v == nil ) {
		v = [NSValue valueWithPointer:asl_open(NULL, [facility_str UTF8String], CLC_OPT_DEBUG)];
		[dict setObject:v forKey:threadKey];
	}
	return [v pointerValue];
}

@end