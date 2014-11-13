# Markov Pack

A Node package for generating and using compacted Markov chains.

## Specification

The binary chain is an array of bytes (`Uint8Array` in JavaScript). Numbers are
stored bigendian.

The chain has the following structure:

- `header` - Describes lengths and positions.
- `pairOfLengths` - The lengths of the unique words.
- `wordList` - A list of all the unique words.
- `hashTable` - A table of `wordTuple` to `chainNext` offset.
- `chainNext` - List of possible continuation words.

### `header`

- `magicNumber` (4 bytes) - Includes version. Value TBD.
- `numberOfLengths` (4 bytes) - The number of unique word sizes.
- `hashTableSize` (4 bytes) - The number of hashTable elements.
- `nextsSize` (4 bytes) - The total size of the `chainNext` block (in bytes).
- `wordSize` (4 bytes) - The size of words (in bits).
- `wordTupleSize` (4 bytes) - The size of word tuples (in bits).
- `offsetSize` (4 bytes) - The size of `chainNext` offsets (in bits).
- `contListSize` (4 bytes) - The size `elementCount` (in bits).
- `weightSize` (4 bytes) - The size `contWeight` (in bits).

### `pairOfLengths`

Has a length of `numberOfLengths` * 2 * 4 bytes.

A list of all the sizes of the words. Something like [[0, 1], [2, 4]], meaning
that there is one word with length 0 and 4 words with length 2. So it's a list
of `lengthPair` with `numberOfLengths` elements.

### `lengthPair`

- `wordLength` (4 bytes) - The size of the word.
- `wordCount` (4 bytes) - How many such words are there.

### `wordList`

A concatenation of all the unique words (encoded with UTF-8). The words appear
ordered by their length and then sorted alphanumerically. Words of length 0 can
exist (obviously only with count 1).

The size of this list is the sum of `wordLength` * `wordCount` for all elements
in `pairOfLengths`.

### `hashTable`

Has a size in bits of (`wordTupleSize` + `offsetSize`) * `hashTableSize`.

This is a hash table structure of `wordTuple` to `chainNext` offset. Offsets are
used instead of element number since `chainNext` contains lists which have
variable lengths.

Since this is a hash table, not all values are used. Unused values are zeroed
out.

### `chainNext`

This is a lists of possible continuation words with their weight: a list of
`contList`. So this represents the values of the hash table.

### `contList`

- `elementCount` (contListSize bits) - The number of pairs to follow.
- `contListPairs` - The list of `contListPair`.

### `contListPair`

- `contWord` (`contWordSize` bits) - The index of the continuation chain
  continuation word.
- `contWeight` (`contWordSize` bits) - The weight of the word within this
  possible continuation.

## License

MIT
