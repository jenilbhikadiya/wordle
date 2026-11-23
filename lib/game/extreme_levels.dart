// The Extreme levels: 50 hand-picked puzzles played in order, each one
// harder than the last. Kept free of Flutter so the rules are easy to test.

/// The five tiers of Extreme levels, ten levels each. Every tier tightens the
/// rules of the one before it.
enum ExtremeTier {
  gilded(
    name: 'Gilded',
    tagline: 'Rare letters and vowel-starved words',
    rules: '5 guesses · Hard mode · 1 hint',
  ),
  onyx(
    name: 'Onyx',
    tagline: 'Doubled letters and odd shapes',
    rules: '5 guesses · Hard mode · No hints',
  ),
  obsidian(
    name: 'Obsidian',
    tagline: 'Six letters, few vowels, strange pairs',
    rules: '5 guesses · Hard mode · No hints',
  ),
  phantom(
    name: 'Phantom',
    tagline: 'Word traps with up to 17 look-alikes',
    rules: '5 guesses · Hard mode · Blind keyboard',
  ),
  sovereign(
    name: 'Sovereign',
    tagline: 'The final ten. Four guesses. No mercy.',
    rules: '4 guesses · Hard mode · Blind keyboard',
  );

  final String name;
  final String tagline;
  final String rules;

  const ExtremeTier({
    required this.name,
    required this.tagline,
    required this.rules,
  });

  int get firstLevel => index * 10 + 1;
  int get lastLevel => index * 10 + 10;
}

/// One Extreme level. Every level is played in hard mode.
class ExtremeLevel {
  /// 1 to 50.
  final int number;
  final String word;
  final ExtremeTier tier;

  /// Why this word is hard, shown once the level is finished.
  final String twist;

  const ExtremeLevel(this.number, this.word, this.tier, this.twist);

  int get wordLength => word.length;

  /// Guesses allowed: five, and only four in the final tier.
  int get maxAttempts => tier == ExtremeTier.sovereign ? 4 : 5;

  /// Letter reveals allowed. Only the first tier gets one.
  int get hints => tier == ExtremeTier.gilded ? 1 : 0;

  /// The on-screen keyboard stops showing letter colours, so every clue has
  /// to be read from the board.
  bool get blindKeyboard => tier.index >= ExtremeTier.phantom.index;

  /// Points for a win: more for higher tiers and for spare guesses.
  int pointsFor(int guessesUsed) =>
      15 + tier.index * 5 + (maxAttempts - guessesUsed) * 4;
}

const _g = ExtremeTier.gilded;
const _o = ExtremeTier.onyx;
const _b = ExtremeTier.obsidian;
const _p = ExtremeTier.phantom;
const _s = ExtremeTier.sovereign;

/// All 50 levels in play order.
const List<ExtremeLevel> extremeLevels = [
  // Gilded: rare letters and vowel-starved words
  ExtremeLevel(1, 'vivid', _g, 'Two Vs and the same vowel twice'),
  ExtremeLevel(2, 'nymph', _g, 'No vowel at all, Y does the work'),
  ExtremeLevel(3, 'gawk', _g, 'A rare AW, with hawk waiting as the decoy'),
  ExtremeLevel(4, 'foyer', _g, 'Y sits where you expect a vowel'),
  ExtremeLevel(5, 'tryst', _g, 'One vowel-ish Y and a repeated T'),
  ExtremeLevel(6, 'quaff', _g, 'QU at the front, a double F at the end'),
  ExtremeLevel(7, 'kiosk', _g, 'Two Ks around a rare IO pair'),
  ExtremeLevel(8, 'glyph', _g, 'Y is the only vowel'),
  ExtremeLevel(9, 'pique', _g, 'Ends in the French -IQUE'),
  ExtremeLevel(10, 'jazzy', _g, 'A J, a double Z and a Y'),

  // Onyx: doubled letters and odd shapes
  ExtremeLevel(11, 'fuzzy', _o, 'Double Z behind a single U'),
  ExtremeLevel(12, 'joker', _o, 'One of joked, jokes, jokey, poker and toker'),
  ExtremeLevel(
    13,
    'boxer',
    _o,
    'X in the middle, with borer, bower and boner nearby',
  ),
  ExtremeLevel(14, 'gauze', _o, 'Three vowels and a Z'),
  ExtremeLevel(
    15,
    'mummy',
    _o,
    'Three Ms, with dummy, gummy and tummy waiting',
  ),
  ExtremeLevel(16, 'crypt', _o, 'No vowel, five common consonants'),
  ExtremeLevel(17, 'lymph', _o, 'No vowel, and an MPH cluster'),
  ExtremeLevel(18, 'kayak', _o, 'A palindrome with two Ks'),
  ExtremeLevel(19, 'waltz', _o, 'Ends in a rare LTZ'),
  ExtremeLevel(20, 'whizz', _o, 'One vowel and a double Z'),

  // Obsidian: six letters, few vowels, strange pairs
  ExtremeLevel(21, 'sphinx', _b, 'One vowel and an X at the end'),
  ExtremeLevel(22, 'zephyr', _b, 'Z, PH and Y in one word'),
  ExtremeLevel(23, 'quartz', _b, 'Starts with Q and ends with Z'),
  ExtremeLevel(24, 'jigsaw', _b, 'J and W at both ends'),
  ExtremeLevel(25, 'voodoo', _b, 'Four Os and only two other letters'),
  ExtremeLevel(26, 'bazaar', _b, 'Three As, two of them side by side'),
  ExtremeLevel(27, 'kitsch', _b, 'Five consonants around a single I'),
  ExtremeLevel(28, 'jockey', _b, 'J, CK and EY together'),
  ExtremeLevel(29, 'fizzle', _b, 'A double Z inside a common ending'),
  ExtremeLevel(30, 'rhythm', _b, 'Six letters and no vowel at all'),

  // Phantom: word traps, with the keyboard gone dark
  ExtremeLevel(
    31,
    'hound',
    _p,
    'bound, found, mound, pound, round, sound and wound all fit',
  ),
  ExtremeLevel(32, 'ditty', _p, 'bitty, kitty, nitty and witty all fit'),
  ExtremeLevel(33, 'vaunt', _p, 'gaunt, haunt, jaunt and taunt all fit'),
  ExtremeLevel(34, 'riper', _p, 'ricer, rider, rimer, riser and river all fit'),
  ExtremeLevel(35, 'daddy', _p, 'baddy, caddy, faddy, laddy and paddy all fit'),
  ExtremeLevel(
    36,
    'latch',
    _p,
    'batch, catch, hatch, match, patch and watch all fit',
  ),
  ExtremeLevel(
    37,
    'parer',
    _p,
    'pacer, pager, paler, paper, pater, paver and payer all fit',
  ),
  ExtremeLevel(
    38,
    'mower',
    _p,
    'bower, cower, lower, power, rower, sower and tower all fit',
  ),
  ExtremeLevel(39, 'wager', _p, 'cager, eager, lager, pager and sager all fit'),
  ExtremeLevel(40, 'dill', _p, 'One of 17 words ending in -ILL'),

  // Sovereign: four guesses, blind keyboard
  ExtremeLevel(41, 'jinx', _s, 'J and X in four letters'),
  ExtremeLevel(42, 'quiz', _s, 'Q, U and Z with a single I'),
  ExtremeLevel(
    43,
    'fjord',
    _s,
    'FJ: a pair almost no English word starts with',
  ),
  ExtremeLevel(44, 'pygmy', _s, 'Two Ys and no other vowel'),
  ExtremeLevel(45, 'buxom', _s, 'An X between two lone vowels'),
  ExtremeLevel(46, 'epoxy', _s, 'E, O and Y around a P and an X'),
  ExtremeLevel(47, 'affix', _s, 'Double F and an X'),
  ExtremeLevel(48, 'yacht', _s, 'A silent CH most people misspell'),
  ExtremeLevel(
    49,
    'golly',
    _s,
    'dolly, folly, holly, jolly, lolly and molly all fit',
  ),
  ExtremeLevel(
    50,
    'zigzag',
    _s,
    'The final level: two Zs, two Gs, one I, one A',
  ),
];

/// Every Extreme word, so they are always accepted as guesses.
Iterable<String> extremeWords(int length) =>
    extremeLevels.map((l) => l.word).where((w) => w.length == length);

/// The level a player may play: every level up to the first one not cleared.
bool isExtremeUnlocked(int number, int cleared) =>
    number >= 1 && number <= extremeLevels.length && number <= cleared + 1;
