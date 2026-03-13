
uppercase.bin:     file format elf32-littleriscv


Disassembly of section .text:

00010000 <_start>:
   10000:	ffff2517          	auipc	a0,0xffff2
   10004:	00050513          	mv	a0,a0
   10008:	00050293          	mv	t0,a0

0001000c <loop>:
   1000c:	00028303          	lb	t1,0(t0)
   10010:	02030263          	beqz	t1,10034 <end_loop>
   10014:	06100393          	li	t2,97
   10018:	00734a63          	blt	t1,t2,1002c <next_char>
   1001c:	07a00393          	li	t2,122
   10020:	0063c663          	blt	t2,t1,1002c <next_char>
   10024:	fe030313          	addi	t1,t1,-32
   10028:	00628023          	sb	t1,0(t0)

0001002c <next_char>:
   1002c:	00128293          	addi	t0,t0,1
   10030:	fddff06f          	j	1000c <loop>

00010034 <end_loop>:
   10034:	0000006f          	j	10034 <end_loop>
