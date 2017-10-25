//
//  ObjcUtils.m
//  Telegram-Mac
//
//  Created by keepcoder on 23/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

#import "ObjcUtils.h"
#import <CommonCrypto/CommonCrypto.h>
#import <AVFoundation/AVFoundation.h>


@implementation ObjcUtils
+ (NSArray *)textCheckingResultsForText:(NSString *)text highlightMentionsAndTags:(bool)highlightMentionsAndTags highlightCommands:(bool)highlightCommands
{
    bool containsSomething = false;
    
    int length = (int)text.length;
    
    int digitsInRow = 0;
    int schemeSequence = 0;
    int dotSequence = 0;
    
    unichar lastChar = 0;
    
    SEL sel = @selector(characterAtIndex:);
    unichar (*characterAtIndexImp)(id, SEL, NSUInteger) = (typeof(characterAtIndexImp))[text methodForSelector:sel];
    
    for (int i = 0; i < length; i++)
    {
        unichar c = characterAtIndexImp(text, sel, i);
        
        if (highlightMentionsAndTags && (c == '@' || c == '#'))
        {
            containsSomething = true;
            break;
        }
        
        if (c >= '0' && c <= '9')
        {
            digitsInRow++;
            if (digitsInRow >= 6)
            {
                containsSomething = true;
                break;
            }
            
            schemeSequence = 0;
            dotSequence = 0;
        }
        else if (!(c != ' ' && digitsInRow > 0))
            digitsInRow = 0;
        
        if (c == ':')
        {
            if (schemeSequence == 0)
                schemeSequence = 1;
            else
                schemeSequence = 0;
        }
        else if (c == '/')
        {
            if (highlightCommands)
            {
                containsSomething = true;
                break;
            }
            
            if (schemeSequence == 2)
            {
                containsSomething = true;
                break;
            }
            
            if (schemeSequence == 1)
                schemeSequence++;
            else
                schemeSequence = 0;
        }
        else if (c == '.')
        {
            if (dotSequence == 0 && lastChar != ' ')
                dotSequence++;
            else
                dotSequence = 0;
        }
        else if (c != ' ' && lastChar == '.' && dotSequence == 1)
        {
            containsSomething = true;
            break;
        }
        else
        {
            dotSequence = 0;
        }
        
        lastChar = c;
    }
    
    if (containsSomething)
    {
        NSError *error = nil;
        static NSDataDetector *dataDetector = nil;
        if (dataDetector == nil)
            dataDetector = [NSDataDetector dataDetectorWithTypes:(int)(NSTextCheckingTypeLink) error:&error];
        
        NSMutableArray *results = [[NSMutableArray alloc] init];
        @try {
            [dataDetector enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, __unused NSMatchingFlags flags, __unused BOOL *stop)
             {
                 @try {
                     NSTextCheckingType type = [match resultType];
                     if (type == NSTextCheckingTypeLink || type == NSTextCheckingTypePhoneNumber)
                     {
                         [results addObject:[NSValue valueWithRange:match.range]];
                     }
                 } @catch (NSException *exception) {
                     
                 }
                 
             }];
        } @catch (NSException *exception) {
            
        }
        
        
        static NSCharacterSet *characterSet = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
                      {
                          characterSet = [NSCharacterSet alphanumericCharacterSet];
                      });
        
        if (containsSomething && (highlightMentionsAndTags || highlightCommands))
        {
            int mentionStart = -1;
            int hashtagStart = -1;
            int commandStart = -1;
            
            unichar previous = 0;
            for (int i = 0; i < length; i++)
            {
                unichar c = characterAtIndexImp(text, sel, i);
                if (highlightMentionsAndTags && commandStart == -1)
                {
                    if (mentionStart != -1)
                    {
                        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'))
                        {
                            if (i > mentionStart + 1)
                            {
                                NSRange range = NSMakeRange(mentionStart + 1, i - mentionStart - 1);
                                NSRange mentionRange = NSMakeRange(range.location - 1, range.length + 1);
                                
                                unichar mentionStartChar = [text characterAtIndex:mentionRange.location + 1];
                                if (!(mentionRange.length <= 1 || (mentionStartChar >= '0' && mentionStartChar <= '9')))
                                {
                                    [results addObject:[NSValue valueWithRange:mentionRange]];
                                }
                            }
                            mentionStart = -1;
                        }
                    }
                    else if (hashtagStart != -1)
                    {
                        if (c == ' ' || (![characterSet characterIsMember:c] && c != '_'))
                        {
                            if (i > hashtagStart + 1)
                            {
                                NSRange range = NSMakeRange(hashtagStart + 1, i - hashtagStart - 1);
                                NSRange hashtagRange = NSMakeRange(range.location - 1, range.length + 1);
                                
                                [results addObject:[NSValue valueWithRange:hashtagRange]];
                            }
                            hashtagStart = -1;
                        }
                    }
                    
                    if (c == '@')
                    {
                        mentionStart = i;
                    }
                    else if (c == '#')
                    {
                        hashtagStart = i;
                    }
                }
                
                if (highlightCommands && mentionStart == -1 && hashtagStart == -1)
                {
                    if (commandStart != -1 && ![characterSet characterIsMember:c] && c != '@' && c != '_')
                    {
                        if (i - commandStart > 1)
                        {
                            NSRange range = NSMakeRange(commandStart, i - commandStart);
                            [results addObject:[NSValue valueWithRange:range]];
                        }
                        
                        commandStart = -1;
                    }
                    else if (c == '/' && (previous == 0 || previous == ' ' || previous == '\n' || previous == '\t'))
                    {
                        commandStart = i;
                    }
                }
                previous = c;
            }
            
            if (mentionStart != -1 && mentionStart + 1 < length - 1)
            {
                NSRange range = NSMakeRange(mentionStart + 1, length - mentionStart - 1);
                NSRange mentionRange = NSMakeRange(range.location - 1, range.length + 1);
                unichar mentionStartChar = [text characterAtIndex:mentionRange.location + 1];
                if (!(mentionRange.length <= 1 || (mentionStartChar >= '0' && mentionStartChar <= '9')))
                {
                    [results addObject:[NSValue valueWithRange:mentionRange]];
                }
            }
            
            if (hashtagStart != -1 && hashtagStart + 1 < length - 1)
            {
                NSRange range = NSMakeRange(hashtagStart + 1, length - hashtagStart - 1);
                NSRange hashtagRange = NSMakeRange(range.location - 1, range.length + 1);
                [results addObject:[NSValue valueWithRange:hashtagRange]];
            }
            
            if (commandStart != -1 && commandStart + 1 < length)
            {
                NSRange range = NSMakeRange(commandStart, length - commandStart);
                [results addObject:[NSValue valueWithRange:range]];
            }
        }
        
        return results;
    }
    
    return nil;
}

+ (NSArray<NSString *> *)getEmojiFromString:(NSString *)string {
    
    __block NSMutableDictionary *temp = [NSMutableDictionary dictionary];
    
    
    [string enumerateSubstringsInRange: NSMakeRange(0, [string length]) options:NSStringEnumerationByComposedCharacterSequences usingBlock:
     ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop){
         
         const unichar hs = [substring characterAtIndex: 0];
         
         
         // surrogate pair
         if (0xd800 <= hs && hs <= 0xdbff) {
             if (substring.length > 1) {
                 unichar ls = [substring characterAtIndex:1];
                 int uc = ((hs - 0xd800) * 0x400) + (ls - 0xdc00) + 0x10000;
                 if (0x1d000 <= uc && uc <= 129300) {
                     
                     [temp setObject:substring forKey:@(uc)];
                 }
             }
         } else if (substring.length > 1) {
             const unichar ls = [substring characterAtIndex:1];
             if (ls == 0x20e3 || ls == 65039) {
                 [temp setObject:substring forKey:@(ls)];
             }
             
         } else {
             // non surrogate
             if (0x2100 <= hs && hs <= 0x27ff) {
                 [temp setObject:substring forKey:@(hs)];
             } else if (0x2B05 <= hs && hs <= 0x2b07) {
                 [temp setObject:substring forKey:@(hs)];
             } else if (0x2934 <= hs && hs <= 0x2935) {
                 [temp setObject:substring forKey:@(hs)];
             } else if (0x3297 <= hs && hs <= 0x3299) {
                 [temp setObject:substring forKey:@(hs)];
             } else if (hs == 0xa9 || hs == 0xae || hs == 0x303d || hs == 0x3030 || hs == 0x2b55 || hs == 0x2b1c || hs == 0x2b1b || hs == 0x2b50) {
                 [temp setObject:substring forKey:@(hs)];
             }
         }
         
     }];
    
    return [temp allValues];
    
}

+(NSArray<NSNumber *> *)bufferList:(CMSampleBufferRef)sampleBuffer {
    
    
    CMBlockBufferRef blockBuffer = nil;
    AudioBufferList audioBufferList;
   
    uint32_t numSamplesInBuffer = (uint32_t)CMSampleBufferGetNumSamples(sampleBuffer);

    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, NULL );
    
    
    NSMutableArray<NSNumber *> *list = [[NSMutableArray alloc] init];
    
    for (uint32_t bufferCount = 0; bufferCount < audioBufferList.mNumberBuffers; bufferCount++)
    {
        int16_t *samples = (int16_t *)audioBufferList.mBuffers[bufferCount].mData;
        for (int i = 0; i < numSamplesInBuffer; i++) {
            int16_t sample = samples[i];
            if (sample < 0) {
                sample = -sample;
            }
            
            [list addObject:[[NSNumber alloc] initWithInt:sample]];

        }
        
    }
    if (blockBuffer)
        CFRelease(blockBuffer);
    
    return list;
}

+ (NSArray<NSView *> *)findElementsByClass:(NSString *)className inView:(NSView *)view {
    //    [self printViews:view];
    NSArray *array = [self findElementsByClass:className inView:view array:nil];
    return array;
}

+ (NSArray<NSView *> *)findElementsByClass:(NSString *)className inView:(NSView *)view array:(NSMutableArray *)array {
    if(!array)
        array = [[NSMutableArray alloc] init];
    
    for (NSView *viewC in view.subviews) {
        
        //        MTLog(@"viewC.className %@ %@", viewC.className, className);
        
        if([viewC.className isEqualToString:className]) {
            [array addObject:viewC];
        }
        
        if([viewC respondsToSelector:@selector(subviews)]) {
            [self findElementsByClass:className inView:viewC array:array];
        }
    }
    return array;
}


+(NSString *) md5:(NSString *)string {
    const char *cStr = [string UTF8String];
    unsigned char digest[16];
    CC_MD5( cStr, (int) strlen(cStr), digest ); // This is the md5 call
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return [NSString stringWithFormat:@"%@", output];
}


+ (NSString *)stringForEmojiHashOfData:(NSData *)data count:(NSInteger)count positionExtractor:(int32_t (^)(uint8_t *, int32_t, int32_t))positionExtractor
{
    if (data.length != 32)
        return @"";
    
    NSArray *emojis = @[ @"😉", @"😍", @"😛", @"😭", @"😱", @"😡", @"😎", @"😴", @"😵", @"😈", @"😬", @"😇", @"😏", @"👮", @"👷", @"💂", @"👶", @"👨", @"👩", @"👴", @"👵", @"😻", @"😽", @"🙀", @"👺", @"🙈", @"🙉", @"🙊", @"💀", @"👽", @"💩", @"🔥", @"💥", @"💤", @"👂", @"👀", @"👃", @"👅", @"👄", @"👍", @"👎", @"👌", @"👊", @"✌️", @"✋️", @"👐", @"👆", @"👇", @"👉", @"👈", @"🙏", @"👏", @"💪", @"🚶", @"🏃", @"💃", @"👫", @"👪", @"👬", @"👭", @"💅", @"🎩", @"👑", @"👒", @"👟", @"👞", @"👠", @"👕", @"👗", @"👖", @"👙", @"👜", @"👓", @"🎀", @"💄", @"💛", @"💙", @"💜", @"💚", @"💍", @"💎", @"🐶", @"🐺", @"🐱", @"🐭", @"🐹", @"🐰", @"🐸", @"🐯", @"🐨", @"🐻", @"🐷", @"🐮", @"🐗", @"🐴", @"🐑", @"🐘", @"🐼", @"🐧", @"🐥", @"🐔", @"🐍", @"🐢", @"🐛", @"🐝", @"🐜", @"🐞", @"🐌", @"🐙", @"🐚", @"🐟", @"🐬", @"🐋", @"🐐", @"🐊", @"🐫", @"🍀", @"🌹", @"🌻", @"🍁", @"🌾", @"🍄", @"🌵", @"🌴", @"🌳", @"🌞", @"🌚", @"🌙", @"🌎", @"🌋", @"⚡️", @"☔️", @"❄️", @"⛄️", @"🌀", @"🌈", @"🌊", @"🎓", @"🎆", @"🎃", @"👻", @"🎅", @"🎄", @"🎁", @"🎈", @"🔮", @"🎥", @"📷", @"💿", @"💻", @"☎️", @"📡", @"📺", @"📻", @"🔉", @"🔔", @"⏳", @"⏰", @"⌚️", @"🔒", @"🔑", @"🔎", @"💡", @"🔦", @"🔌", @"🔋", @"🚿", @"🚽", @"🔧", @"🔨", @"🚪", @"🚬", @"💣", @"🔫", @"🔪", @"💊", @"💉", @"💰", @"💵", @"💳", @"✉️", @"📫", @"📦", @"📅", @"📁", @"✂️", @"📌", @"📎", @"✒️", @"✏️", @"📐", @"📚", @"🔬", @"🔭", @"🎨", @"🎬", @"🎤", @"🎧", @"🎵", @"🎹", @"🎻", @"🎺", @"🎸", @"👾", @"🎮", @"🃏", @"🎲", @"🎯", @"🏈", @"🏀", @"⚽️", @"⚾️", @"🎾", @"🎱", @"🏉", @"🎳", @"🏁", @"🏇", @"🏆", @"🏊", @"🏄", @"☕️", @"🍼", @"🍺", @"🍷", @"🍴", @"🍕", @"🍔", @"🍟", @"🍗", @"🍱", @"🍚", @"🍜", @"🍡", @"🍳", @"🍞", @"🍩", @"🍦", @"🎂", @"🍰", @"🍪", @"🍫", @"🍭", @"🍯", @"🍎", @"🍏", @"🍊", @"🍋", @"🍒", @"🍇", @"🍉", @"🍓", @"🍑", @"🍌", @"🍐", @"🍍", @"🍆", @"🍅", @"🌽", @"🏡", @"🏥", @"🏦", @"⛪️", @"🏰", @"⛺️", @"🏭", @"🗻", @"🗽", @"🎠", @"🎡", @"⛲️", @"🎢", @"🚢", @"🚤", @"⚓️", @"🚀", @"✈️", @"🚁", @"🚂", @"🚋", @"🚎", @"🚌", @"🚙", @"🚗", @"🚕", @"🚛", @"🚨", @"🚔", @"🚒", @"🚑", @"🚲", @"🚠", @"🚜", @"🚦", @"⚠️", @"🚧", @"⛽️", @"🎰", @"🗿", @"🎪", @"🎭", @"🇯🇵", @"🇰🇷", @"🇩🇪", @"🇨🇳", @"🇺🇸", @"🇫🇷", @"🇪🇸", @"🇮🇹", @"🇷🇺", @"🇬🇧", @"1️⃣", @"2️⃣", @"3️⃣", @"4️⃣", @"5️⃣", @"6️⃣", @"7️⃣", @"8️⃣", @"9️⃣", @"0️⃣", @"🔟", @"❗️", @"❓", @"♥️", @"♦️", @"💯", @"🔗", @"🔱", @"🔴", @"🔵", @"🔶", @"🔷" ];
    
    uint8_t bytes[32];
    [data getBytes:bytes length:32];
    
    NSString *result = @"";
    for (int32_t i = 0; i < count; i++)
    {
        int32_t position = positionExtractor(bytes, i, (int32_t)emojis.count);
        NSString *emoji = emojis[position];
        result = [result stringByAppendingString:emoji];
    }
    
    return result;
}
    

+(NSOpenPanel *)openPanel {
    return [NSOpenPanel openPanel];
}
    
+(NSSavePanel *)savePanel {
    return [NSSavePanel savePanel];
}

+(NSEvent *)scrollEvent:(NSEvent *)from {
    CGWheelCount wheelCount = 1; // 1 for Y-only, 2 for Y-X, 3 for Y-X-Z

    CGEventRef cgEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, wheelCount, from.deltaY, from.deltaX);
    
    // You can post the CGEvent to the event stream to have it automatically sent to the window under the cursor
    CGEventPost(kCGHIDEventTap, cgEvent);
    
    NSEvent *theEvent = [NSEvent eventWithCGEvent:cgEvent];
    CFRelease(cgEvent);

    return theEvent;
}

+(NSString *)callEmojies:(NSData *)keySha256 {
    return [self stringForEmojiHashOfData:keySha256 count:4 positionExtractor:^int32_t(uint8_t *bytes, int32_t i, int32_t count) {
        int offset = i * 8;
        int64_t num = (((int64_t)bytes[offset] & 0x7F) << 56) | (((int64_t)bytes[offset+1] & 0xFF) << 48) | (((int64_t)bytes[offset+2] & 0xFF) << 40) | (((int64_t)bytes[offset+3] & 0xFF) << 32) | (((int64_t)bytes[offset+4] & 0xFF) << 24) | (((int64_t)bytes[offset+5] & 0xFF) << 16) | (((int64_t)bytes[offset+6] & 0xFF) << 8) | (((int64_t)bytes[offset+7] & 0xFF));
        return num % count;
    }];
}

+(NSSize)gifDimensionSize:(NSString *)path {
    
    NSSize size = NSMakeSize(0, 0);
    
    NSInputStream *stream = [[NSInputStream alloc] initWithURL:[NSURL fileURLWithPath:path]];
    
    [stream open];
    
    uint8_t *buffer = (uint8_t *)malloc(3);
    NSUInteger length = [stream read:buffer maxLength:3]; // header
    
    NSData *headerData = [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES];
    
    
    NSString *g = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
    
    if([g isEqualToString:@"GIF"]) {
        [stream read:buffer maxLength:3]; // skip gif version
        
        
        
        unsigned short width = 0;
        unsigned short height = 0;
        
        uint8_t wb[2];
        length = [stream read:wb maxLength:2];
        if(length > 0) {
            memcpy(&width, wb, 2);
        }
        
        uint8_t hb[2];
        length = [stream read:hb maxLength:2];
        if(length > 0) {
            memcpy(&height, hb, 2);
        }
        
        
        size = NSMakeSize(width, height);
        
    }
    
    [stream close];
    
    
    
    return size;
}

+(int)colorMask:(int)idValue mainId:(int)mainId {
    
    __block int colorMask = 0;
    
    
    static NSMutableDictionary *cacheColorIds;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheColorIds = [[NSMutableDictionary alloc] init];
    });
    
    
    if(cacheColorIds[@(idValue)]) {
        colorMask = [cacheColorIds[@(idValue)] intValue];
    } else {
        const int numColors = 8;
        
        if(idValue != -1) {
            char buf[16];
            
            snprintf(buf, 16, "%d%d", idValue, mainId);
            
            unsigned char digest[CC_MD5_DIGEST_LENGTH];
            CC_MD5(buf, (unsigned) strlen(buf), digest);
            colorMask = ABS(digest[ABS(idValue % 16)]) % numColors;
        } else {
            colorMask = -1;
        }
        
        cacheColorIds[@(idValue)] = @(colorMask);
    }
    
    return colorMask;
    
    
}

//NSImage *TGIdenticonImage(NSData *data, CGSize size)
//{
//    
//    uint8_t bits[128];
//    memset(bits, 0, 128);
//    
//    [data getBytes:bits length:MIN(128, data.length)];
//    
//    static CGColorRef colors[6];
//    
//    //int ptr = 0;
//    
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^
//                  {
//                      static const int textColors[] =
//                      {
//                          0xffffff,
//                          0xd5e6f3,
//                          0x2d5775,
//                          0x2f99c9
//                      };
//                      
//                      for (int i = 0; i < 4; i++)
//                      {
//                          int rgbValue = textColors[i];
//                          NSColor *color = [NSColor colorWithDeviceRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];
//                          colors[i] = CGColorRetain(color.CGColor);
//                      }
//                  });
//    
//    
//    CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0,CGColorSpaceCreateDeviceRGB(),kCGImageAlphaPremultipliedLast);
//    
//    int bitPointer = 0;
//    
//    float rectSize = floorf(size.width / 8.0f);
//    
//    for (int iy = 7; iy >= 0; iy--)
//    {
//        for (int ix = 0; ix < 8; ix++)
//        {
//            int32_t byteValue = get_bits(bits, bitPointer, 2);
//            bitPointer += 2;
//            int colorIndex = ABS(byteValue) % 4;
//            
//            
//            CGContextSetFillColorWithColor(context, colors[colorIndex]);
//            CGContextFillRect(context, CGRectMake(ix * rectSize, iy * rectSize, rectSize, rectSize));
//        }
//    }
//    
//    
//    CGImageRef cgImage = CGBitmapContextCreateImage(context);
//    
//    
//    
//    NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:size];
//    
//    CGContextRelease(context);
//    CGImageRelease(cgImage);
//    
//    return image;
//}


NSImage *TGIdenticonImage(NSData *data, NSData *additionalData, CGSize size)
{
    uint8_t bits[128];
    memset(bits, 0, 128);
    
    uint8_t additionalBits[256 * 8];
    memset(additionalBits, 0, 256 * 8);
    
    [data getBytes:bits length:MIN((NSUInteger)128, data.length)];
    [additionalData getBytes:additionalBits length:MIN((NSUInteger)256, additionalData.length)];
    
    static CGColorRef colors[6];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
                  {
                      static const int textColors[] =
                      {
                          0xffffff,
                          0xd5e6f3,
                          0x2d5775,
                          0x2f99c9
                      };
                      
                      for (int i = 0; i < 4; i++)
                      {
                          int rgbValue = textColors[i];
                        NSColor *color = [NSColor colorWithDeviceRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];

                          colors[i] = CGColorRetain(color.CGColor);
                      }
                  });
    
    CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0,CGColorSpaceCreateDeviceRGB(),kCGImageAlphaPremultipliedLast);
    
    CGContextSetFillColorWithColor(context, colors[0]);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    
    if (additionalData == nil) {
        int bitPointer = 0;
        
        CGFloat rectSize = size.width / 8.0f;
        
        for (int iy = 0; iy < 8; iy++)
        {
            for (int ix = 0; ix < 8; ix++)
            {
                int32_t byteValue = get_bits(bits, bitPointer, 2);
                bitPointer += 2;
                int colorIndex = ABS(byteValue) % 4;
                
                CGContextSetFillColorWithColor(context, colors[colorIndex]);
                
                CGRect rect = CGRectMake(ix * rectSize, iy * rectSize, rectSize, rectSize);
                if (size.width > 200) {
                    rect.origin.x = ceil(rect.origin.x);
                    rect.origin.y = ceil(rect.origin.y);
                    rect.size.width = ceil(rect.size.width);
                    rect.size.height = ceil(rect.size.height);
                }
                CGContextFillRect(context, rect);
            }
        }
    } else {
        int bitPointer = 0;
        
        CGFloat rectSize = size.width / 12.0f;
        
        for (int iy = 0; iy < 12; iy++)
        {
            for (int ix = 0; ix < 12; ix++)
            {
                int32_t byteValue = 0;
                if (bitPointer < 128) {
                    byteValue = get_bits(bits, bitPointer, 2);
                } else {
                    byteValue = get_bits(additionalBits, bitPointer - 128, 2);
                }
                bitPointer += 2;
                int colorIndex = ABS(byteValue) % 4;
                
                CGContextSetFillColorWithColor(context, colors[colorIndex]);
                
                CGRect rect = CGRectMake(ix * rectSize, iy * rectSize, rectSize, rectSize);
                if (size.width > 200) {
                    rect.origin.x = ceil(rect.origin.x);
                    rect.origin.y = ceil(rect.origin.y);
                    rect.size.width = ceil(rect.size.width);
                    rect.size.height = ceil(rect.size.height);
                }
                CGContextFillRect(context, rect);
            }
        }
    }
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    
    NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:size];
    
    CGContextRelease(context);
    CGImageRelease(cgImage);
    
    return image;

}


static int32_t get_bits(uint8_t const *bytes, unsigned int bitOffset, unsigned int numBits)
{
    uint8_t const *data = bytes;
    numBits = (unsigned int)pow(2, numBits) - 1; //this will only work up to 32 bits, of course
    data += bitOffset / 8;
    bitOffset %= 8;
    return (*((int*)data) >> bitOffset) & numBits;
}

double mappingRange(double x, double in_min, double in_max, double out_min, double out_max) {
    double slope = 1.0 * (out_max - out_min) / (in_max - in_min);
    return out_min + slope * (x - in_min);
}

+(NSArray<NSString *> *)notificationTones:(NSString *)def {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *list = [[NSMutableArray alloc] init];
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.aiff'"];
    
    [list addObject:@"DefaultSoundName"];
    
    [list addObject:@"NotificationSettingsToneNone"];
    
    NSArray *dirContents = [fm contentsOfDirectoryAtPath:@"~/Library/Sounds" error:nil];
    [list addObjectsFromArray:[dirContents filteredArrayUsingPredicate:fltr]];
    
    dirContents = [fm contentsOfDirectoryAtPath:@"/Library/Sounds" error:nil];
    [list addObjectsFromArray:[dirContents filteredArrayUsingPredicate:fltr]];
    
    dirContents = [fm contentsOfDirectoryAtPath:@"/Network/Library/Sounds" error:nil];
    [list addObjectsFromArray:[dirContents filteredArrayUsingPredicate:fltr]];
    
    dirContents = [fm contentsOfDirectoryAtPath:@"/System/Library/Sounds" error:nil];
    [list addObjectsFromArray:[dirContents filteredArrayUsingPredicate:fltr]];
    
    
    
    for (int i = 0; i < list.count; i++) {
        list[i] = [list[i] stringByDeletingPathExtension];
    }
    
    return [list sortedArrayUsingComparator:^NSComparisonResult(NSString * obj1, NSString * obj2) {
        if([obj2 isEqualToString:def]) {
            return NSOrderedDescending;
        }
        
        return NSOrderedSame;
        
    }];
    
}


+(NSString *)youtubeIdentifier:(NSString *)url {
    
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?<=youtube.com/watch\\?v=)([-a-zA-Z0-9_]+)|(?<=youtu.be/)([-a-zA-Z0-9_]+)"
                                              options:NSRegularExpressionCaseInsensitive
                                                error:&error];
    
    NSTextCheckingResult *match = [regex firstMatchInString:url options:0 range:NSMakeRange(0, [url length])];
    if (match) {
        NSRange videoIDRange = [match rangeAtIndex:0];
        return [url substringWithRange:videoIDRange];
    }
    
    return nil;
}

@end



#import <sys/xattr.h>
#import <sys/stat.h>

@implementation NSFileManager (Extension)


+ (NSString *)xattrStringValueForKey:(NSString *)key atURL:(NSURL *)URL
{
    NSString *value = nil;
    const char *keyName = key.UTF8String;
    const char *filePath = URL.fileSystemRepresentation;
    
    ssize_t bufferSize = getxattr(filePath, keyName, NULL, 0, 0, 0);
    
    if (bufferSize != -1) {
        char *buffer = malloc(bufferSize+1);
        
        if (buffer) {
            getxattr(filePath, keyName, buffer, bufferSize, 0, 0);
            buffer[bufferSize] = '\0';
            value = [NSString stringWithUTF8String:buffer];
            free(buffer);
        }
    }
    return value;
}

+ (BOOL)setXAttrStringValue:(NSString *)value forKey:(NSString *)key atURL:(NSURL *)URL
{
    int failed = setxattr(URL.fileSystemRepresentation, key.UTF8String, value.UTF8String, value.length, 0, 0);
    return (failed == 0);
}

@end

@implementation NSMutableAttributedString(Extension)

-(void)detectBoldColorInStringWithFont:(NSFont *)font  {
    [self detectBoldColorInStringWithFont:font string:[self.string copy]];
}

-(void)detectBoldColorInStringWithFont:(NSFont *)font string:(NSString *)string {
    NSRange range;
    
    NSUInteger offset = 0;
    
    while ((range = [string rangeOfString:@"**" options:0 range:NSMakeRange(offset, string.length - offset)]).location != NSNotFound) {
        
        
        
        offset = range.location + range.length;
        
        
        range = [string rangeOfString:@"**" options:0 range:NSMakeRange(offset, string.length - offset)];
        
        if(range.location != NSNotFound) {
            [self addAttribute:NSFontAttributeName value:font range:NSMakeRange(offset, range.location - offset)];
            
            offset+= (range.location - offset) + range.length;
            
        }
        
        
    }
    
    while ((range = [self.string rangeOfString:@"**"]).location != NSNotFound) {
        [self replaceCharactersInRange:range withString:@""];
    }
}


@end


NSString * trimMessage(NSString * message) {
    NSString *string = message;
    
    while ([string rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location == 0 || [string rangeOfString:@"\n"].location == 0) {
        string = [string substringFromIndex:1];
    }
    
    
    while (string.length > 0 && ([string rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:0 range:NSMakeRange(string.length - 1, 1)].location == string.length-1 || [string rangeOfString:@"\n" options:0 range:NSMakeRange(string.length - 1, 1)].location == string.length-1)) {
        string = [string substringToIndex:string.length - 1];
    }
    
    
    return string;
}

NSArray<NSString *> *cut_long_message(NSString *message, int max_length) {
    
    NSMutableArray *parts = [NSMutableArray array];
    
    int inc = max_length;
    
    if (message.length < max_length) {
        return @[message];
    }
    
    @try {
        for (int i = 0; i < message.length; i += inc)
        {
            int length = MIN(max_length, (int)message.length - i);
            
            NSString *substring = [message substringWithRange:NSMakeRange(i, length)];
            
            NSUInteger (^giveup)(NSCharacterSet *symbol) = ^NSUInteger(NSCharacterSet *symbol) {
                
                NSUInteger index = NSNotFound;
                
                for (int j = (int)substring.length ; j > 0; j --) {
                    
                    if([[substring substringWithRange:NSMakeRange(j-1, 1)] rangeOfCharacterFromSet:symbol].location != NSNotFound) {
                        index = j;
                        break;
                    }
                }
                
                return index;
            };
            
            NSArray<NSCharacterSet *> *csets = @[[NSCharacterSet newlineCharacterSet],[NSCharacterSet characterSetWithCharactersInString:@"."],[NSCharacterSet whitespaceCharacterSet]];
            
            NSUInteger index = substring.length;
            
            if(index + inc > message.length) {
                
                for (NSCharacterSet *set in csets) {
                    NSUInteger idx = giveup(set);
                    if(idx != NSNotFound) {
                        index = idx;
                        break;
                    }
                }
                
            }
            
            substring = [substring substringWithRange:NSMakeRange(0, index)];
            
            inc = (int) substring.length;
            
            if (substring.length != 0) {
                [parts addObject:substring];
            }
            
        }
    } @catch (NSException *exception) {
        
        [parts removeAllObjects];
        
        for (NSUInteger i = 0; i < message.length; i += max_length)
        {
            NSString *substring = [message substringWithRange:NSMakeRange(i, MIN(max_length, message.length - i))];
            if (substring.length != 0) {
                
                [parts addObject:substring];
                
            }
            
        }
        
        return parts;
    }
    
    return parts;
}


int64_t SystemIdleTime(void) {
    int64_t idlesecs = -1;
    io_iterator_t iter = 0;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOHIDSystem"), &iter) == KERN_SUCCESS) {
        io_registry_entry_t entry = IOIteratorNext(iter);
        if (entry) {
            CFMutableDictionaryRef dict = NULL;
            if (IORegistryEntryCreateCFProperties(entry, &dict, kCFAllocatorDefault, 0) == KERN_SUCCESS) {
                CFNumberRef obj = CFDictionaryGetValue(dict, CFSTR("HIDIdleTime"));
                if (obj) {
                    int64_t nanoseconds = 0;
                    if (CFNumberGetValue(obj, kCFNumberSInt64Type, &nanoseconds)) {
                        idlesecs = (nanoseconds >> 30); // Divide by 10^9 to convert from nanoseconds to seconds.
                    }
                }
                CFRelease(dict);
            }
            IOObjectRelease(entry);
        }
        IOObjectRelease(iter);
    }
    
    return idlesecs;
}

NSDictionary<NSString *, NSString *> *audioTags(AVURLAsset *asset) {
    
    __block NSString *artistName = @"";
    __block NSString *songName = @"";
    
    [asset.availableMetadataFormats enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        
        NSArray *metadata = [asset metadataForFormat:obj];
        
        for (AVMutableMetadataItem *metaItem in metadata) {
            if([metaItem.identifier isEqualToString:AVMetadataIdentifierID3MetadataLeadPerformer]) {
                artistName = (NSString *) metaItem.value;
            } else if([metaItem.identifier isEqualToString:AVMetadataIdentifierID3MetadataTitleDescription]) {
                songName = (NSString *) metaItem.value;
            } else if([metaItem.identifier isEqualToString:AVMetadataiTunesMetadataKeyArtist]) {
                if (artistName.length == 0)
                    artistName = (NSString *) metaItem.value;
            } else if([metaItem.identifier isEqualToString:AVMetadataiTunesMetadataKeySongName]) {
                songName = (NSString *) metaItem.value;
            } else if([metaItem.identifier isEqualToString:AVMetadataQuickTimeUserDataKeyArtist]) {
                if (artistName.length == 0)
                    artistName = (NSString *) metaItem.value;
            } else if([metaItem.identifier isEqualToString:AVMetadataQuickTimeUserDataKeyTrackName]) {
                songName = (NSString *)metaItem.value;
            } else if([metaItem.identifier isEqualToString:AVMetadataCommonIdentifierArtist]) {
                if (artistName.length == 0)
                    artistName = (NSString *) metaItem.value;
            } else if([metaItem.identifier isEqualToString:AVMetadataCommonIdentifierTitle]) {
                songName = (NSString *) metaItem.value;
            } else if([metaItem.identifier hasSuffix:@"aART"]) {
                if (artistName.length == 0)
                    artistName = (NSString *)metaItem.value;
            } else if([metaItem.identifier hasSuffix:@"wrt"]) {
                if (artistName.length == 0)
                    artistName = (NSString *)metaItem.value;
            } else if([metaItem.identifier hasSuffix:@"nam"]) {
                songName = (NSString *)metaItem.value;
            }
            
        }
        
        if(artistName.length > 0 && songName.length > 0)
            *stop = YES;
        
    }];
    
    return @{@"performer":artistName,@"title":songName};
}


@implementation NSData (TG)

- (NSString *)stringByEncodingInHex
{
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    if (dataBuffer == NULL)
        return [NSString string];
    
    NSUInteger dataLength  = [self length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < (int)dataLength; ++i)
        [hexString appendString:[[NSString stringWithFormat:@"%02lx ", (unsigned long)dataBuffer[i]] uppercaseString]];
    
    return [hexString substringToIndex:hexString.length - 1];
}

@end

BOOL isEnterEventObjc(NSEvent *theEvent) {
    BOOL isEnter = (theEvent.keyCode == 0x24 || theEvent.keyCode ==  0x4C);
    return isEnter;
}

BOOL isEnterAccessObjc(NSEvent *theEvent, BOOL byCmdEnter) {
    if(isEnterEventObjc(theEvent)) {
        NSUInteger flags = (theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask);
        return !byCmdEnter ? flags == 0 || flags == 65536 : (theEvent.modifierFlags & NSCommandKeyMask) > 0;
    }
    return NO;
}


int colorIndexForUid(int32_t uid, int32_t myUserId)
{
    static const int numColors = 8;
    
    int colorIndex = 0;
    
    char buf[16];
    snprintf(buf, 16, "%d%d", (int)uid, (int)myUserId);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(buf, (CC_LONG)strlen(buf), digest);
    colorIndex = ABS(digest[ABS(uid % 16)]) % numColors;
    
    return colorIndex;
}
inline int64_t TGPeerIdFromChannelId(int32_t channelId) {
    return ((int64_t)INT32_MIN) * 2 - ((int64_t)channelId);
}

inline int colorIndexForGroupId(int64_t groupId)
{
    static const int numColors = 4;
    
    int colorIndex = 0;
    
    char buf[16];
    snprintf(buf, 16, "%lld", groupId);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(buf, (CC_LONG)strlen(buf), digest);
    colorIndex = ABS(digest[ABS(groupId % 16)]) % numColors;
    
    return colorIndex;
}

