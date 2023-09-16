//
//  RingBuffer.h
//  MarathonBrainwaves
//
//  Created by Lance Brackett on 2/18/23.
//  Copyright © 2023 Alex Cruikshank. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RingBuffer<__covariant T> : NSObject

@property (nonatomic, strong) NSMutableArray<T> *data;
@property (nonatomic, assign) NSInteger next;
@property (nonatomic, assign) NSInteger size;

- (instancetype)initWithSize:(NSInteger)size;
- (void)appendValue:(T)value;
- (void)removeAll;
- (T)objectAtIndexedSubscript:(NSInteger)index;
- (void)setObject:(T)obj atIndexedSubscript:(NSInteger)index;
- (void)subarrayWithRange: (NSRange)range;

@end
