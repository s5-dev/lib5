/// MIT License
/// Copyright (c) 2020 Nebulous

/// To prevent analysis that can occur by looking at the sizes of files, all
/// encrypted files will be padded to the nearest "pad block" (after encryption).
/// A pad block is minimally 4 kib in size, is always a power of 2, and is always
/// at least 5% of the size of the file.
///
/// For example, a 1 kib encrypted file would be padded to 4 kib, a 5 kib file
/// would be padded to 8 kib, and a 105 kib file would be padded to 112 kib.
/// Below is a short table of valid file sizes:
///
/// ```
///   4 KiB      8 KiB     12 KiB     16 KiB     20 KiB
///  24 KiB     28 KiB     32 KiB     36 KiB     40 KiB
///  44 KiB     48 KiB     52 KiB     56 KiB     60 KiB
///  64 KiB     68 KiB     72 KiB     76 KiB     80 KiB
///
///  88 KiB     96 KiB    104 KiB    112 KiB    120 KiB
/// 128 KiB    136 KiB    144 KiB    152 KiB    160 KiB
///
/// 176 KiB    192 Kib    208 KiB    224 KiB    240 KiB
/// 256 KiB    272 KiB    288 KiB    304 KiB    320 KiB
///
/// 352 KiB    ... etc
/// ```
///
/// Note that the first 20 valid sizes are all a multiple of 4 KiB, the next 10
/// are a multiple of 8 KiB, and each 10 after that the multiple doubles. We use
/// this method of padding files to prevent an adversary from guessing the
/// contents or structure of the file based on its size.
///
/// @param initialSize - The size of the file.
/// @returns - The final size, padded to a pad block.

int padFileSizeDefault(int initialSize) {
  final kib = 1 << 10;
  // Only iterate to 53 (the maximum safe power of 2).
  for (var n = 0; n < 53; n++) {
    if (initialSize <= (1 << n) * 80 * kib) {
      final paddingBlock = (1 << n) * 4 * kib;
      var finalSize = initialSize;
      if (finalSize % paddingBlock != 0) {
        finalSize = initialSize - (initialSize % paddingBlock) + paddingBlock;
      }
      return finalSize;
    }
  }
  // Prevent overflow.
  throw "Could not pad file size, overflow detected.";
}

bool checkPaddedBlock(int size) {
  final kib = 1024;
  // Only iterate to 53 (the maximum safe power of 2).
  for (int n = 0; n < 53; n++) {
    if (size <= (1 << n) * 80 * kib) {
      final paddingBlock = (1 << n) * 4 * kib;
      return size % paddingBlock == 0;
    }
  }
  throw "Could not check padded file size, overflow detected.";
}
