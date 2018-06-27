# This repository has been moved to [gitlab.com/paul-nechifor/markov-pack](http://gitlab.com/paul-nechifor/markov-pack).

Old readme:

# Markov Pack

A Node package for generating and using compacted Markov chains. I use it [to
generate fake titles for CS papers][papers]. Here’s an example:

> A Lax Equivalence Theorem for Multiple Perspective Views via Iterative Depth
> Estimation Algorithm with Admission Control Algorithm Combining Static and
> Interactive Distance Education Technical Specifications into Relational
> Database Design Using the Level Set Framework with Pairwise Constraints for
> Interval and Fuzzy ART Network for Computing Minimal-Norm Solutions to the
> Maximally Flat FIR Fractional Delay Filter and Linearized LNA Applied in
> Hydrology Domain.

## Install

    npm install

## Run tests

    npm test

## Specification

The binary chain is an array of bytes (`Uint8Array` in JavaScript). Numbers are
stored bigendian.

The chain has the following structure:

- `header` - Describes lengths and positions.

- `pairOfLengths` - The lengths of the unique words.

- `wordList` - A list of all the unique words.

- `hashTable` - A table of `wordTuple` to `chain` offset.

- `chain` - List of possible continuation words.

### `header`

Some number fields are included for reference purposes. They don't occupy any
space in the binary but their method of calculation is specified. All the
included lengths and sizes are on 4 bytes. All sizes refer to sizes in bits, not
bytes.

- `magicNumber` (7 bytes) - 0x13e3ff45be9c06 (computed by running `echo
  'markov-pack' | sha1sum | cut -c -14`)

- `version` (1 byte) - For this first version it's 0x01.

- `wordLengthsLen` - The number of unique word lengths.

- `chainLen` - The number of elements in the chain.

- `wordListLen` (not included) - The number of bytes in the `wordList` block.
  Computed as the sum of `wordLength` * `wordCount` for all elements in
  `pairOfLengths`.

- `hashTableLen` - The number of elements in the hash table. This is >= to
  `chainLen`.

- `chainBytesLen` - The number of bytes in the `chain` block.

- `wordSize` (not included) - This can be computed by counting the total number
  of words in `pairOfLengths` and getting the number of bits required to store
  that number.

- `wordTupleSize` (not included) - Double the size of `wordSize`.

- `offsetSize` (not included) - The number of bits required to store
  `chainBytesLen` * 8.

- `contListSize` - The size `pairCount`.

- `weightSize` - The size `contWeight`.

### `pairOfLengths`

A list of `lengthPair` with `wordLengthsLen` elements that represents the unique
sizes of the words.

### `lengthPair`

- `wordLength` (4 bytes) - The size of the word as stored in `wordList` in
  bytes.

- `wordCount` (4 bytes) - How many such words are there.

### `wordList`

A concatenation of all the unique words (only ASCII is supported for now). The
words appear ordered by their length and then sorted alphanumerically. Words of
length 0 can exist (obviously only with count 1).

### `hashTable`

Has a size in bits of (`wordTupleSize` + `offsetSize`) * `hashTableLen`.

This is a hash table structure of `wordTuple` to `chain` offset. Offsets are
used instead of element number since `chain` contains lists which have variable
lengths.

Since this is a hash table, not all values are used. Unused values are zeroed
out.

### `chain`

This is a lists of possible continuation words with their weight: a list of
`contList`. So these are the values that the hash table points to.

### `contList`

- `pairCount` (`contListSize` bits) - The number of `pairs` that will follow.

- `pairs` - The list of `contListPair`.

### `pairs`

- `contWord` (`wordSize` bits) - The word in this continuation.

- `contWeight` (`contWeightSize` bits) - The weight of the word within this
  possible continuation.

## License

MIT

[papers]: https://github.com/paul-nechifor/markov-pack
