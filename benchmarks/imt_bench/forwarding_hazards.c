// SPDX-License-Identifier: Apache-2.0
// Directed checks for the optional generated no-forwarding controller.
#include "runtime.h"
static unsigned cell;
static unsigned alu_chain(void) {
 unsigned x;
 __asm__ volatile("li t0,23; addi t1,t0,7; sub %0,t1,t0":"=r"(x)::"t0","t1");
 return x==7;
}
static unsigned alu_rs2(void) {
 unsigned x;
 __asm__ volatile("li t0,13; li t1,27; add t2,t1,t0; sub %0,t2,t1":"=r"(x)::"t0","t1","t2");
 return x==13;
}
static unsigned load_use(void) {
 unsigned x;cell=232;
 __asm__ volatile("lw t0,0(%1); addi %0,t0,7":"=r"(x):"r"(&cell):"t0","memory");
 return x==239;
}
static unsigned store_data(void) {
 unsigned x;
 __asm__ volatile("li t0,37; add t1,t0,t0; sw t1,0(%1); lw %0,0(%1)":"=r"(x):"r"(&cell):"t0","t1","memory");
 return x==74;
}
static unsigned mul_raw(void) {
 unsigned x;
 __asm__ volatile("li t0,17; li t1,19; mul t2,t0,t1; addi %0,t2,1":"=r"(x)::"t0","t1","t2");
 return x==324;
}
static unsigned mul_waw(void) {
 unsigned x;
 __asm__ volatile("li t0,17; li t1,19; mul t2,t0,t1; li t3,7; addi t3,t3,1; li t2,99; mv %0,t2":"=r"(x)::"t0","t1","t2","t3");
 return x==99;
}
static unsigned csr_raw(void) {
 unsigned x;
 __asm__ volatile("csrr t0,cycle; addi t1,t0,7; sub %0,t1,t0":"=r"(x)::"t0","t1");
 return x==7;
}
static unsigned jalr_raw(void) {
 unsigned x;
 __asm__ volatile("la t0,1f; jalr t1,t0,0; li %0,0; j 2f; 1: li %0,1; 2:":"=r"(x)::"t0","t1");
 return x==1;
}
static unsigned mul_high(void) {
 unsigned a,b,c;
 __asm__ volatile("li t0,-17; li t1,19; mulh t2,t0,t1; addi %0,t2,1":"=r"(a)::"t0","t1","t2");
 __asm__ volatile("li t0,-1; li t1,19; mulhu t2,t0,t1; addi %0,t2,1":"=r"(b)::"t0","t1","t2");
 __asm__ volatile("li t0,-17; li t1,-1; mulhsu t2,t0,t1; addi %0,t2,17":"=r"(c)::"t0","t1","t2");
 return a==0 && b==19 && c==0;
}
static unsigned misaligned(void) {
 static unsigned char data[12] __attribute__((aligned(4)))={0};
 unsigned x;
 for(unsigned offset=1;offset<=3;offset++) {
  __asm__ volatile("li t0,0x78563412; sw t0,0(%1); lw t1,0(%1); addi %0,t1,1"
     :"=r"(x):"r"(data+offset):"t0","t1","memory");
  if(x!=0x78563413 || data[offset]!=0x12 || data[offset+1]!=0x34 ||
     data[offset+2]!=0x56 || data[offset+3]!=0x78)return 0;
 }
 return 1;
}
static unsigned div_raw(void) {
 unsigned a,b;
 __asm__ volatile("li t0,323; li t1,19; div t2,t0,t1; addi %0,t2,1":"=r"(a)::"t0","t1","t2");
 __asm__ volatile("li t0,325; li t1,19; rem t2,t0,t1; addi %0,t2,1":"=r"(b)::"t0","t1","t2");
 return a==18 && b==3;
}
static unsigned branch_raw(void) {
 unsigned x;
 __asm__ volatile("li t0,7; addi t1,t0,1; bne t0,t1,1f; li %0,0; j 2f; 1: li %0,1; 2:"
     :"=r"(x)::"t0","t1");
 return x==1;
}
int main(void) {
 unsigned failed=0;
 bench_measure_begin();
 for(unsigned i=0;i<64;i++) {
  failed|=(!alu_chain())<<0;failed|=(!alu_rs2())<<1;
  failed|=(!load_use())<<2;failed|=(!store_data())<<3;
  failed|=(!mul_raw())<<4;failed|=(!mul_waw())<<5;
  failed|=(!csr_raw())<<6;failed|=(!jalr_raw())<<7;
  failed|=(!mul_high())<<8;failed|=(!misaligned())<<9;
  failed|=(!div_raw())<<10;failed|=(!branch_raw())<<11;
 }
 bench_measure_end();
 return (int)failed;
}
