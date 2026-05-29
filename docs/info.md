<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements an AES-128 encryption accelerator using a partially unrolled 2-round datapath, a 16-bit serial loading wrapper, and a case-statement S-box.

Because Tiny Tapeout has limited input and output pins, the 128-bit key, 128-bit plaintext, and 128-bit ciphertext are not exposed directly. Instead, the design transfers data 16 bits at a time using ui_in[7:0] and uio[7:0].

The operation sequence is:

Load the 128-bit AES key over 8 clock cycles.
Load the 128-bit plaintext over 8 clock cycles.
Perform AES encryption using a 2-round partially unrolled datapath.
Output the 128-bit ciphertext over 8 clock cycles.

The AES core processes two AES rounds per clock cycle, so AES rounds 1 to 10 are completed in 5 processing cycles. The final AES round skips MixColumns, as required by AES-128.

The bidirectional uio[7:0] pins are used as inputs during key/plaintext loading and as outputs during ciphertext unloading. The uio_oe[7:0] signal controls the direction of these bidirectional pins.

## How to test

Reset the design by driving rst_n low, then release reset by setting rst_n high.

After reset, provide the 128-bit key as eight 16-bit words. Each 16-bit word is formed from:

uio_in[7:0] as the upper byte
ui_in[7:0] as the lower byte

Then provide the 128-bit plaintext in the same 16-bit word format.

After the key and plaintext are loaded, the design enters the AES processing state. The AES encryption takes 5 processing cycles because two AES rounds are completed per cycle.

When encryption is complete, the ciphertext is shifted out as eight 16-bit words. During ciphertext output:

uio_out[7:0] provides the upper byte
uo_out[7:0] provides the lower byte
uio_oe[7:0] is set high so that the bidirectional pins act as outputs

The output ciphertext can be compared against known AES-128 test vectors, such as NIST AESAVS known-answer test values.

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
