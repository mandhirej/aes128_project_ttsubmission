import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


# AES-128 known answer test:
# key       = 00000000000000000000000000000000
# plaintext = 00000000000000000000000000000000
# ciphertext= 66e94bd4ef8a2c3b884cfa59ca342b2e

KEY = 0x00000000000000000000000000000000
PLAINTEXT = 0x00000000000000000000000000000000
EXPECTED_CT = 0x66e94bd4ef8a2c3b884cfa59ca342b2e


def split_16bit_words(value):
    """Split 128-bit value into 8 x 16-bit words, MSW first."""
    return [(value >> shift) & 0xFFFF for shift in range(112, -1, -16)]


async def drive_16bit_word(dut, word):
    """
    Your design uses:
      uio_in[7:0] = MSB
      ui_in[7:0]  = LSB
    """
    dut.uio_in.value = (word >> 8) & 0xFF
    dut.ui_in.value = word & 0xFF
    await RisingEdge(dut.clk)


async def reset_dut(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start AES-128 serial iterative test")

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await reset_dut(dut)

    dut._log.info("Loading 128-bit key")
    for word in split_16bit_words(KEY):
        await drive_16bit_word(dut, word)

    dut._log.info("Loading 128-bit plaintext")
    for word in split_16bit_words(PLAINTEXT):
        await drive_16bit_word(dut, word)

    dut._log.info("Waiting for ciphertext unload phase")

    # Wait until uio_oe becomes 0xFF, meaning the design is outputting ciphertext.
    for _ in range(100):
        await RisingEdge(dut.clk)
        if int(dut.uio_oe.value) == 0xFF:
            break

    assert int(dut.uio_oe.value) == 0xFF, "Timeout waiting for ciphertext unload phase"

    dut._log.info("Reading 128-bit ciphertext")

    ciphertext = 0

    for _ in range(8):
        upper = int(dut.uio_out.value) & 0xFF
        lower = int(dut.uo_out.value) & 0xFF
        word = (upper << 8) | lower

        ciphertext = (ciphertext << 16) | word

        await RisingEdge(dut.clk)

    dut._log.info(f"Ciphertext = {ciphertext:032x}")
    dut._log.info(f"Expected   = {EXPECTED_CT:032x}")

    assert ciphertext == EXPECTED_CT
