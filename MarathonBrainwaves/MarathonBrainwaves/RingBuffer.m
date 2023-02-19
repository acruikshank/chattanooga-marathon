//
//  RingBuffer.m
//  MarathonBrainwaves
//
//  Created by Lance Brackett on 2/18/23.
//  Copyright © 2023 Alex Cruikshank. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RingBuffer.h"


@implementation RingBuffer

- (instancetype)initWithSize:(NSInteger)size {
    self = [super init];
    if (self) {
        _size = size;
        _data = [NSMutableArray array];
    }
    return self;
}

- (void)appendValue:(id)value {
    if (_data.count < _size) {
        [_data addObject:value];
        return;
    }
    
    _data[_next] = value;
    _next = (_next + 1) % _size;
}

- (void)removeAll {
    [_data removeAllObjects];
    _next = 0;
}

- (id)objectAtIndexedSubscript:(NSInteger)index {
    return _data[index % _size];
}

- (void)setObject:(id)obj atIndexedSubscript:(NSInteger)index {
    _data[index % _size] = obj;
}

@end

