// Modified by Princeton University on June 9th, 2015
/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T1 Processor File: dram_secc_env.s
* Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
* DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
* 
* The above named program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License version 2 as published by the Free Software Foundation.
* 
* The above named program is distributed in the hope that it will be 
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
* 
* You should have received a copy of the GNU General Public
* License along with this work; if not, write to the Free Software
* Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
* 
* ========== Copyright Header End ============================================
*/
/***********************************************************************
 * Name:    dram_secc_env.s
 * Date:    July 24, 2003
 *
 *  Description:
 *    Dram test trying to inject SECC error and read the location back.
 *    The SECC error should be corrected and reported. 
 *    Scrubbing is happening in the back ground which should
 *    detect and correct the error.
 *
 *  This test is self checking
 * Add self check :  6800000000000662,68000000000049f2,6800000000003197,680000000000768f ( 0x280)
 *  
 *   THIS USES THE ENV/PLUS ARG CMP_DRAM_ENB_ERROR for error injection 
 *   and can *****NOT****** be uses as a tester test.
 *
 **********************************************************************/

#define H_HT0_Corrected_ECC_error_0x63 My_Corrected_ECC_error_trap
#define H_HT0_Reserved_0x78 My_Data_Access_Exception1
#define TRAP_TYPE 0x63
#define TRAP_TYPE_78 0x78


#define MAIN_PAGE_HV_ALSO

#include "boot.s"

#define  ASI_LSU_CONTROL  0x45
#define  L2CS_PA1         0xA900000000

.text
.global main
.global  My_Corrected_ECC_error_trap
.global My_Data_Access_Exception1


main:

  ! Boot code does not provide TLB translation for IO address space
  ta    T_CHANGE_HPRIV

  setx  0x9700000000, %l0, %l1  ! dram base address
  setx  0x1000, %l0, %l4        ! channel increment
  add   %g0, 0x4, %l5           ! loop count 4, all ch
  set   data_segment, %l7       ! set the data

  ! Now access L2 control and status registers

disable_l1:
 ldxa  [%g0] ASI_LSU_CONTROL, %l0
 ! Remove the lower 2 bits (I-Cache and D-Cache enables)
 andn  %l0, 0x3, %l0
 stxa  %l0, [%g0] ASI_LSU_CONTROL

 disable_l2:
  setx  L2CS_PA1, %l1, %l0
  mov   0x1, %l2
  ! disable all banks
  stx   %l2, [%l0]
  stx   %l2, [%l0+0x40]
  stx   %l2, [%l0+0x80]
  stx   %l2, [%l0+0xc0]

! set all 4 channels
loop_reg : 
  ! Clear the error registers
  setx  0xfe00000000000000, %l0, %l2
  stx   %l2, [%l1+0x280]

  ! Error location register
  setx  0x0000000000000000, %l0, %l2
  stx   %l2, [%l1+0x2a0]

  ! DRAM Err Injection Register, enable 
  ! cont. error with ecc mask , 0x000f, SECC
  ! Use env feature
  !setx  0x000000008000000f, %l0, %l2
  !stx   %l2, [%l1+0x290]
  !nop

  add   %l1, %l4, %l1        ! next channel

  deccc   %l5
  bne     loop_reg           ! repeat till all ch done
  nop



  ! do stores starting @ loc 0
  setx    0x1111111111111111, %l3, %l1
  mov     0, %l2
  add   %g0, 0x008, %l5        ! next channel
loop_ld_st : 
  stx     %l1, [%l2]
  ld      [%l2], %l1

  !call      trap_check
  !nop

  inc    %l1
  add    %l2, 0x40, %l2

  deccc   %l5
  bne loop_ld_st
  nop

  setx  0x9700000000, %l0, %l1
  add   %g0, 0x4, %l5           ! loop count 4, all ch
loop_reg1 : 
  ! create another test which has scrub only , this
  ! part goes away from here .

  ! Enable Scrub 
  setx  0x0000000000000001, %l0, %l2
  stx   %l2, [%l1+0x40]

  ! Set Scrub frequency to a low value
  setx  0x0000000000000005, %l0, %l2
  stx   %l2, [%l1+0x18]

  add   %l1, %l4, %l1        ! next channel

  deccc   %l5
  bne     loop_reg1          ! repeat till all ch done
  nop

  ! do stores starting @ loc 0
  setx    0x1111111111111111, %l3, %l1
  mov     0x100, %l2
  add   %g0, 0x004, %l5        ! next channel
loop_ld_st1 : 
  stx     %l1, [%l2]
  ld      [%l2], %l1

  !call      trap_check
  !nop

  inc    %l1
  add    %l2, 0x240, %l2

  deccc   %l5
  bne loop_ld_st1
  nop


  ! wait
  !nop; nop; nop; nop; nop; nop; nop;
  !nop; nop; nop; nop; nop; nop; nop;
  !nop; nop; nop; nop; nop; nop; nop;
  !nop; nop; nop; nop; nop; nop; nop;

  add   %g0, 0x4, %l5           ! loop count 4, all ch
  setx  0x9700000000, %l0, %l1
loop_check : 
  ! Read the error status register
  ldx   [%l1+0x280], %l0
  srlx    %l0, 56, %l0
  !cmp     %l0, 0x68  ! Mult. SECC, SECC, SCB SECC
  !bne test_fail
  !nop

  ! read error location register
  ldx   [%l1+0x2a0], %l0
  srlx    %l0, 32, %l0
  !cmp     %l0, 0x8   ! Error in ECC nibble 0
  !bne test_fail
  !nop

  ! dummy loads to buy scrub time
  ldx   [%l1+0x2a0], %l0
  ldx   [%l1+0x2a0], %l0
  ldx   [%l1+0x2a0], %l0
  ldx   [%l1+0x2a0], %l0

  ! DRAM Err Injection Register, clear
  setx  0x0000000000000000, %l0, %l2
  stx   %l2, [%l1+0x290]
  nop


  add   %l1, %l4, %l1        ! next channel

  deccc   %l5
  bne     loop_check          ! repeat till all ch done
  nop

! Enable the L2,L1.
! NOTE : the dram registers (error/etc) are affected
!        by this test and are not cleared

enable_l2:
  setx  L2CS_PA1, %l1, %l0
  stx   %g0, [%l0]
  stx   %g0, [%l0+0x40]
  stx   %g0, [%l0+0x80]
  stx   %g0, [%l0+0xc0]

enable_l1:
  ldxa  [%g0] ASI_LSU_CONTROL, %l0
  or    %l0, 0x3, %l0
  stxa  %l0, [%g0] ASI_LSU_CONTROL


  ba    test_pass
  nop

My_Corrected_ECC_error_trap:
  rdpr  %tt, %o0
  retry

My_Data_Access_Exception1:
  ! Read trap type register, disruptive trap
  rdpr  %tt, %o0
  cmp  %o0, TRAP_TYPE_78
  bne   test_fail
  nop
  nop
  retry

trap_check : 
  nop
  nop  
  ! Expecting a trap here in the diag
  ! Check if a trap happens
  cmp  %o0, TRAP_TYPE
  bne   test_fail
  nop
  retl       ! return back
  nop  

/*******************************************************
 * Exit code
 *******************************************************/

test_pass:
ta  T_GOOD_TRAP

test_fail:
ta  T_BAD_TRAP

.data 
 data_segment:

        .word   0x00112233
        .word   0x44556677
        .word   0x8899aabb
        .word   0xccddeeff
        .word   0x00112233
        .word   0x44556677
        .word   0x8899aabb
        .word   0xccddeeff

.align  128

.end


