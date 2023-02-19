//
//  RRValues.h
//  MarathonBrainwaves
//
//  Created by Lance Brackett on 2/18/23.
//  Copyright © 2023 Alex Cruikshank. All rights reserved.
//

#import "RingBuffer.h"

@interface RRValues : RingBuffer<NSNumber *>

- (instancetype)initWithSize:(NSInteger)size;
- (double)variance;
- (double)standardDeviation;


@end
