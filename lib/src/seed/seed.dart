/// MIT License
/// Copyright (c) 2021 Skynet Labs

// ignore_for_file: constant_identifier_names

import 'dart:math';
import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';

import 'wordlist.dart';

const SEED_LENGTH = 16;
const SEED_WORDS_LENGTH = 13;
const CHECKSUM_WORDS_LENGTH = 2;
const PHRASE_LENGTH = SEED_WORDS_LENGTH + CHECKSUM_WORDS_LENGTH;

String generatePhrase({required CryptoImplementation crypto}) {
  final seedWords = Uint16List(SEED_WORDS_LENGTH);

  // TODO Use random number generator from CryptoImplementation
  final random = Random.secure();

  // Populate the seed words from the random values.
  for (var i = 0; i < SEED_WORDS_LENGTH; i++) {
    seedWords[i] = random.nextInt(1 << 16);

    var numBits = 10;
    // For the 1st word, only the first 256 words are considered valid.
    if (i == 0) {
      numBits = 8;
    }
    seedWords[i] = seedWords[i] % (1 << numBits);
  }

  // Generate checksum from hash of the seed.
  final checksumWords = generateChecksumWordsFromSeedWords(
    seedWords,
    crypto: crypto,
  );

  final phraseWords = List<String>.filled(PHRASE_LENGTH, '', growable: false);

  for (var i = 0; i < SEED_WORDS_LENGTH; i++) {
    phraseWords[i] = wordlist[seedWords[i]];
  }
  for (var i = 0; i < CHECKSUM_WORDS_LENGTH; i++) {
    phraseWords[i + SEED_WORDS_LENGTH] = wordlist[checksumWords[i]];
  }

  return phraseWords.join(" ");
}

String sanitizePhrase(String phrase) {
  return phrase.trim().toLowerCase();
}

Uint8List validatePhrase(
  String phrase, {
  required CryptoImplementation crypto,
}) {
  phrase = sanitizePhrase(phrase);
  final phraseWords = phrase.split(' ');

  if (phraseWords.length != PHRASE_LENGTH) {
    throw 'Phrase must be 15 words long, was ${phraseWords.length}';
  }

  // Build the seed from words.
  final seedWords = Uint16List(SEED_WORDS_LENGTH);

  var i = 0;
  for (final word in phraseWords) {
    // Check word length.
    if (word.length < 3) {
      throw 'Word ${i + 1} is not at least 3 letters long';
    }

    // Check word prefix.
    final prefix = word.substring(0, 3);
    var bound = wordlist.length;
    if (i == 0) {
      bound = 256;
    }
    var found = -1;
    for (var j = 0; j < bound; j++) {
      final curPrefix = wordlist[j].substring(0, 3);
      if (curPrefix == prefix) {
        found = j;
        break;
      }
    }
    if (found < 0) {
      if (i == 0) {
        throw 'Prefix for word ${i + 1} must be found in the first 256 words of the wordlist';
      } else {
        throw 'Unrecognized prefix "$prefix" at word ${i + 1}, not found in wordlist';
      }
    }

    seedWords[i] = found;

    i++;
    if (i >= SEED_WORDS_LENGTH) break;
  }

  // Validate checksum.
  final checksumWords = generateChecksumWordsFromSeedWords(
    seedWords,
    crypto: crypto,
  );
  for (var i = 0; i < CHECKSUM_WORDS_LENGTH; i++) {
    final prefix = wordlist[checksumWords[i]].substring(0, 3);
    if (phraseWords[i + SEED_WORDS_LENGTH].substring(0, 3) != prefix) {
      throw 'Word "${phraseWords[i + SEED_WORDS_LENGTH + 1]}" is not a valid checksum for the seed';
    }
  }

  return seedWordsToSeed(seedWords);
}

Uint16List generateChecksumWordsFromSeedWords(
  Uint16List seedWords, {
  required CryptoImplementation crypto,
}) {
  if (seedWords.length != SEED_WORDS_LENGTH) {
    throw 'Input seed was not of length $SEED_WORDS_LENGTH';
  }

  final seed = seedWordsToSeed(seedWords);
  final h = Uint8List.fromList(crypto.hashBlake3Sync(seed));
  final checksumWords = hashToChecksumWords(h);

  return checksumWords;
}

Uint16List hashToChecksumWords(Uint8List h) {
  var word1 = h[0] << 8;
  word1 += h[1];
  word1 >>= 6;
  var word2 = h[1] << 10;
  word2 &= 0xffff;
  word2 += h[2] << 2;
  word2 >>= 6;
  return Uint16List.fromList([word1, word2]);
}

Uint8List seedWordsToSeed(Uint16List seedWords) {
  if (seedWords.length != SEED_WORDS_LENGTH) {
    throw 'Input seed was not of length $SEED_WORDS_LENGTH';
  }

  // We are getting 16 bytes of entropy.
  final bytes = Uint8List(SEED_LENGTH);
  var curByte = 0;
  var curBit = 0;

  for (var i = 0; i < SEED_WORDS_LENGTH; i++) {
    final word = seedWords[i];
    var wordBits = 10;
    if (i == 0) {
      wordBits = 8;
    }

    // Iterate over the bits of the 10- or 8-bit word.
    for (var j = 0; j < wordBits; j++) {
      final bitSet = (word & (1 << (wordBits - j - 1))) > 0;

      if (bitSet) {
        bytes[curByte] |= 1 << (8 - curBit - 1);
      }

      curBit += 1;
      if (curBit >= 8) {
        curByte += 1;
        curBit = 0;
      }
    }
  }

  return bytes;
}
