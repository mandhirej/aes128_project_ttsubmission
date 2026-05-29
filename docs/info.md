<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This design implements an AES-128 encryption accelerator using a 1-round iterative AES datapath, a serial loading wrapper, and a case-statement S-box.

The AES core processes one AES round per clock cycle. AES-128 requires an initial AddRoundKey step followed by 10 AES rounds. In this implementation, the same round hardware is reused for each round, so the design uses less hardware compared to a partially unrolled or fully unrolled AES design.

To fit within the limited Tiny Tapeout I/O pins, the 128-bit key, 128-bit plaintext, and 128-bit ciphertext are not exposed directly as 128-bit ports. Instead, data is transferred serially through the Tiny Tapeout input/output pins. The key and plaintext are loaded in smaller words over multiple clock cycles, and the ciphertext is shifted out in the same way.

The S-box is implemented using a case-statement lookup table. This directly maps each 8-bit input byte to its AES S-box output value. This approach is easy to verify, synthesis-friendly, and avoids the long compile time of a fixed Boolean S-box implementation.

The main operation sequence is:

Load the 128-bit AES key serially.
Load the 128-bit plaintext serially.
Perform AES encryption using the 1-round iterative datapath.
Output the 128-bit ciphertext serially.

This design prioritizes lower area and Tiny Tapeout compatibility. The tradeoff is that encryption takes more clock cycles than a 2-round partially unrolled design, because only one AES round is processed per clock cycle.
## How to test

Reset the design by driving rst_n low, then release reset by setting rst_n high.

After reset, load the 128-bit AES key serially through the input pins. Then load the 128-bit plaintext in the same serial format. Once the key and plaintext have been loaded, the AES core begins encryption.

The AES processing stage performs one AES round per clock cycle. Since AES-128 has 10 rounds, the round-processing stage takes 10 clock cycles, excluding the serial loading and unloading cycles.

After encryption is complete, the 128-bit ciphertext is shifted out serially through the output pins. The output ciphertext should be compared against known AES-128 test vectors, such as NIST AESAVS known-answer test values.

A typical test should check:

Apply reset.
Load a known 128-bit key.
Load a known 128-bit plaintext.
Wait for the AES encryption process to complete.
Read the 128-bit ciphertext from the output pins.
Compare the output ciphertext with the expected AES-128 ciphertext.

For example, the design can be tested using AES-128 known-answer vectors in the format:

Plaintext | Key | Ciphertext

A test passes when the ciphertext produced by the hardware matches the expected ciphertext from the test vector.

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
