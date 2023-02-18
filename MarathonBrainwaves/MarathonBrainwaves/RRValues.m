//
//  RRValues.m
//  MarathonBrainwaves
//
//  Created by Lance Brackett on 2/18/23.
//  Copyright © 2023 Alex Cruikshank. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RRValues.h"

@implementation RRValues

- (instancetype)initWithSize:(NSInteger)size {
    self = [super initWithSize:size];
    return self;
}

- (double)mean {
  if ([self.data count] == 0) return 0.0;
    NSArray *data = [self data];
  double sum = 0.0;
  for (NSNumber *num in [self data]) {
    sum += [num doubleValue];
  }
  double average = sum / data.count;
  return average;
}

- (double)variance {
  if ([self.data count] == 0) return 0.0;

  double u = [self mean];
  double sum = 0.0;
  for (NSNumber *num in [self data]) {
      double x = [num doubleValue];
      sum += pow(u - x, 2);
  }
  return sum / [[self data] count];
}

- (double)standardDeviation {
    return sqrt([self variance]);
}

@end
