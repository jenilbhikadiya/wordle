"""Builds the 50-day social content plan (days.json) from the daily word list.

Each day gets one reel and one post. Formats rotate so the feed stays varied,
and nothing posted on a day gives away that day's answer: replays and recaps
only ever show yesterday's word, and guess-along puzzles use practice words
that are not in the daily schedule.
"""

import json
import random
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
OUT = Path(__file__).resolve().parent / "days.json"
DAYS = 50

LENGTH_FILES = {4: "four_name_word.json", 5: "five_name_word.json", 6: "six_name_word.json"}

CLUES = {
    "pastor": "Leads a flock, but not of sheep",
    "penny": "A ___ for your thoughts",
    "stock": "Found on shelves and on trading floors",
    "rose": "Got out of bed, or grew thorns",
    "till": "Where the cash goes, or what farmers do to soil",
    "tall": "Giraffes have this covered",
    "truly": "Yours ___, at the end of a letter",
    "struck": "What lightning did to the tree",
    "annual": "Happens once every trip around the sun",
    "rough": "Not smooth, and golfers dread it",
    "urgent": "It can't wait until tomorrow",
    "modern": "The opposite of old-fashioned",
    "signed": "What you did on the dotted line",
    "beat": "A drummer keeps it, a champion does it",
    "book": "You can read one, or reserve a table with one",
    "belief": "Something you hold without proof",
    "noted": "Duly ___: message received",
    "tend": "Look after a garden, or lean a certain way",
    "pipe": "Carries water, or plays a Highland tune",
    "brand": "A logo is the face of one",
    "police": "They answer 911 and 999",
    "houses": "Streets are lined with them",
    "horse": "Can be dark, or Trojan",
    "needs": "Wants and ___",
    "nurse": "Works the night shift on the ward",
    "reach": "Stretch for the top shelf",
    "lock": "The reason keys exist",
    "nobody": "Not a single person",
    "eight": "Count a spider's legs",
    "rapid": "Very fast, like white water",
    "strong": "Describes coffee and weightlifters",
    "hero": "Every story needs one",
    "insist": "Refuse to take no for an answer",
    "fist": "A hand, fully closed",
    "secret": "Keep it and don't tell",
    "costly": "Hard on the wallet",
    "ever": "Happily ___ after",
    "well": "Fine, or where water is drawn from",
    "days": "Seven of them make a week",
    "upset": "A surprise win, or an unhappy feeling",
    "puzzle": "You solve one every single day",
    "text": "A message that buzzes your phone",
    "trial": "Held in a courtroom, or a free version",
    "select": "Pick from the options",
    "proud": "How you feel after a 2/6",
    "threat": "A warning of danger",
    "exit": "The way out",
    "museum": "Where old things go on display",
    "purple": "Mix red and blue",
    "expose": "Bring something hidden to light",
}

# Each demo row is "word:states", with c = right spot, p = wrong spot, a = absent.
TIPS = [
    {"title": "Open with vowels", "body": "A starter like ARISE tests three vowels in one go.", "demo": ["arise:paapc", "ocean:apcpa"]},
    {"title": "Grey means gone", "body": "Never reuse a grey letter. Every guess should learn something new.", "demo": ["crane:aaaaa", "moist:apaca"]},
    {"title": "Yellow means move it", "body": "The letter is in the word, just not in that spot.", "demo": ["stale:ppppa", "least:ccccc"]},
    {"title": "Watch for doubles", "body": "Letters can repeat. Words like BALLOT and COFFEE are fair game.", "demo": ["ballot:accaca", "coffee:cccccc"]},
    {"title": "Count the tiles", "body": "The daily word can be 4, 5 or 6 letters. Check before you type.", "demo": ["word:aaaa", "words:aaaaa", "worded:aaaaaa"]},
    {"title": "Think in endings", "body": "-ER, -ED and -LY turn up a lot in longer words.", "demo": ["paper:aaacc", "rested:aaaacc", "lately:aaaacc"]},
    {"title": "Spend hints wisely", "body": "Hints cost points, so save them for when you're truly stuck.", "demo": ["hints:aaaaa"]},
    {"title": "Try hard mode", "body": "Every letter you find must be reused. Wins earn bonus points.", "demo": ["brave:apaac", "grade:acccc"]},
    {"title": "Guess to learn", "body": "Stuck between MIGHT, FIGHT and LIGHT? Play a word that tests M, F and L at once.", "demo": ["night:acccc", "film:aaaa"]},
    {"title": "Play every day", "body": "Your streak only grows on the day itself. Don't break the chain.", "demo": ["daily:ccccc"]},
]

FEATURES = [
    {"title": "Day streak", "body": "Play each daily puzzle on its day and watch the flame grow.", "icon": "flame"},
    {"title": "Calendar", "body": "Missed a day? Catch up from the calendar any time.", "icon": "calendar"},
    {"title": "Practice mode", "body": "Unlimited 4, 5 or 6 letter words. Pick a length and go.", "icon": "practice"},
    {"title": "Light and dark", "body": "Two themes, easy on the eyes at any hour.", "icon": "theme"},
    {"title": "Share your grid", "body": "Copy an emoji grid of your result, no spoilers.", "icon": "share"},
    {"title": "Stats", "body": "Win %, streaks and guess distribution for every length.", "icon": "stats"},
    {"title": "Hints", "body": "Reveal a letter, up to two per game.", "icon": "hint"},
    {"title": "Hard mode", "body": "Found letters must be reused. Bonus points per win.", "icon": "hard"},
    {"title": "New at midnight", "body": "A fresh puzzle unlocks every night, the same for everyone.", "icon": "clock"},
    {"title": "Keyboard ready", "body": "Type with a real keyboard on web and desktop.", "icon": "keyboard"},
]

POLLS = [
    {"q": "What's your go-to starter word?", "opts": ["CRANE", "ADIEU", "SLATE", "AUDIO"]},
    {"q": "Which length do you like best?", "opts": ["4 letters", "5 letters", "6 letters", "Surprise me"]},
    {"q": "Hard mode: yes or no?", "opts": ["Always on", "Sometimes", "Never", "What's hard mode?"]},
    {"q": "How many guesses did today take you?", "opts": ["1-2", "3", "4", "5-6"]},
    {"q": "When do you play?", "opts": ["Right at midnight", "Morning coffee", "Lunch break", "Before bed"]},
    {"q": "Which letter scares you most?", "opts": ["Q", "X", "Z", "J"]},
    {"q": "What's your current streak?", "opts": ["0-2 days", "3-9 days", "10-29 days", "30+ days"]},
    {"q": "Do you ever use hints?", "opts": ["Never", "Only to save a streak", "Sometimes", "Every game"]},
    {"q": "Light mode or dark mode?", "opts": ["Light", "Dark", "Follows my phone", "I switch it up"]},
    {"q": "Who do you share results with?", "opts": ["Group chat", "Family", "Social media", "Nobody, I'm a lone wolf"]},
]

# Fun, familiar answers for guess-along puzzles. None are daily words.
PRACTICE = """bloom crisp dwarf grape jolly kayak mango ninja quilt salsa vivid waltz
yacht zebra daisy fudge glove hippo igloo koala llama maple otter panda raven
scarf tulip unzip viper whale bagel cocoa donut gecko""".split()

PRACTICE_CLUES = {
    "bloom": "What flowers do in spring", "crisp": "Fresh lettuce, or a cold morning",
    "dwarf": "Tiny star, or one of seven", "grape": "Comes in bunches, becomes wine",
    "jolly": "Cheerful, like a certain Roger", "kayak": "A boat that reads the same backwards",
    "mango": "Tropical fruit with a big stone", "ninja": "Silent, stealthy and in black",
    "quilt": "Patchwork that keeps you warm", "salsa": "A dip, or a dance",
    "vivid": "Bright and full of colour", "waltz": "A dance in three-four time",
    "yacht": "A fancy boat with sails", "zebra": "Stripes on four legs",
    "daisy": "Fresh as one, says the saying", "fudge": "A sweet treat, or a dodge",
    "glove": "A hand's best friend in winter", "hippo": "Big river animal with a big yawn",
    "igloo": "A house made of snow", "koala": "Australian tree hugger",
    "llama": "Fluffy, and might spit at you", "maple": "Gives syrup and red leaves",
    "otter": "Holds hands while it sleeps", "panda": "Black, white and full of bamboo",
    "raven": "A black bird with a famous poem", "scarf": "Wrap it round your neck",
    "tulip": "Spring flower of the Netherlands", "unzip": "Open a jacket, or a file",
    "viper": "A snake with a bite", "whale": "The biggest animal in the sea",
    "bagel": "Bread with a hole", "cocoa": "Hot drink, or what chocolate starts as",
    "donut": "Fried ring with sprinkles", "gecko": "Little lizard that climbs walls",
}

STARTERS = {4: ["rate", "tale", "near", "sore", "mail"],
            5: ["crane", "slate", "arise", "trace", "stare"],
            6: ["planet", "stored", "carton", "senior", "master"]}

REEL_CYCLE = {1: "hint", 2: "replay", 3: "pause", 4: "tip", 0: "feature"}
POST_CYCLE = {1: "teaser", 2: "guess", 3: "recap", 4: "fill", 0: "poll"}


def load(path):
    return json.loads((ASSETS / path).read_text())


def score(guess, answer):
    """Tile states for a guess, with Wordle's handling of repeated letters."""
    res = ["absent"] * len(guess)
    left = {}
    for g, a in zip(guess, answer):
        if g != a:
            left[a] = left.get(a, 0) + 1
    for i, (g, a) in enumerate(zip(guess, answer)):
        if g == a:
            res[i] = "correct"
    for i, g in enumerate(guess):
        if res[i] != "correct" and left.get(g, 0) > 0:
            res[i] = "present"
            left[g] -= 1
    return res


def solve(answer, pool, rng, lo=3, hi=5):
    """A believable path of guesses that ends on the answer in lo..hi tries."""
    starters = [w for w in STARTERS[len(answer)] if w != answer]
    for _ in range(400):
        guesses = [rng.choice(starters)]
        cands = [w for w in pool if w != guesses[0]]
        while guesses[-1] != answer and len(guesses) < 6:
            fb = score(guesses[-1], answer)
            cands = [w for w in cands if score(guesses[-1], w) == fb and w != guesses[-1]]
            if answer not in cands:
                cands.append(answer)
            # Prefer a near miss before the answer to keep the reel tense.
            others = [w for w in cands if w != answer]
            if len(guesses) + 1 < lo and others:
                guesses.append(rng.choice(others))
            else:
                guesses.append(rng.choice(cands))
        if guesses[-1] == answer and lo <= len(guesses) <= hi:
            return [{"word": g, "states": score(g, answer)} for g in guesses]
    if (lo, hi) != (2, 6):
        return solve(answer, pool, rng, 2, 6)
    raise RuntimeError(f"no path for {answer}")


def main():
    daily = load("daily_words.json")
    daily_words = {d["word"] for d in daily}
    # Guess paths draw on common words; the daily list drops the proper nouns.
    # Words due soon are left out so a wrong guess never hints at a coming day.
    soon = {d["word"] for d in daily[: DAYS + 30]}
    easy = {n: [w for w in load(f"easy_words_json/{f}") if w in daily_words and w not in soon]
            for n, f in LENGTH_FILES.items()}
    rng = random.Random(2026)

    allowed = set(load("all_english_words/five_name_word.json"))
    practice = [w for w in PRACTICE if w not in daily_words and w in allowed]
    rng.shuffle(practice)
    practice_iter = iter(practice)

    days = []
    for d in daily[:DAYS]:
        n = d["day"]
        word = d["word"]
        prev = daily[n - 2]["word"] if n > 1 else None
        dt = date.fromisoformat(d["date"])
        reel = REEL_CYCLE[n % 5]
        post = POST_CYCLE[n % 5]
        if n == 1:
            reel = "launch"
        if n == DAYS:
            reel = "finale"
        item = {
            "day": n,
            "date": d["date"],
            "dateLabel": dt.strftime("%a %d %b").replace(" 0", " "),
            "length": len(word),
            "clue": CLUES[word],
            "vowels": sum(c in "aeiou" for c in word),
            "word": word,
            "prev": prev,
            "reel": {"type": reel},
            "post": {"type": post},
        }
        r, p = item["reel"], item["post"]

        if reel == "replay":
            r["guesses"] = solve(prev, easy[len(prev)], rng)
        if reel == "pause":
            pw = next(practice_iter)
            r["answer"] = pw
            r["clue"] = PRACTICE_CLUES[pw]
            r["guesses"] = solve(pw, easy[5], rng, lo=4, hi=5)
        if reel == "tip":
            r["tip"] = TIPS[(n // 5) % len(TIPS)]
        if reel == "feature":
            r["feature"] = FEATURES[(n // 5 - 1) % len(FEATURES)]
        if reel == "finale":
            r["past"] = [x["word"] for x in daily[: n - 1]]

        if post == "guess":
            pw = next(practice_iter)
            p["answer"] = pw
            p["guesses"] = solve(pw, easy[5], rng, lo=4, hi=5)[:-1]
            p["clue"] = PRACTICE_CLUES[pw]
        if post == "fill":
            pw = next(practice_iter)
            k = rng.sample(range(5), 2)
            p["answer"] = pw
            p["pattern"] = "".join(c if i in k else "_" for i, c in enumerate(pw))
            p["clue"] = PRACTICE_CLUES[pw]
        if post == "poll":
            p["poll"] = POLLS[(n // 5 - 1) % len(POLLS)]
        if post == "recap":
            p["clue"] = CLUES[prev]
        days.append(item)

    OUT.write_text(json.dumps(days, indent=1))
    print(f"wrote {len(days)} days to {OUT}")


if __name__ == "__main__":
    main()
