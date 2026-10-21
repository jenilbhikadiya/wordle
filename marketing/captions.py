"""Writes captions, hashtags and story stickers for each day, plus a calendar.

Usage: python3 captions.py <outDir>
"""

import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TAGS = "#wordle #dailypuzzle #wordgame #wordpuzzle #brainteaser #puzzlegame"

REEL_NAMES = {
    "launch": "Launch", "hint": "Today's hint", "replay": "Yesterday replay",
    "pause": "Pause & solve", "tip": "Pro tip", "feature": "App feature", "finale": "Day 50 finale",
}
POST_NAMES = {
    "teaser": "Daily teaser + hint ladder", "guess": "Guess the word",
    "recap": "Yesterday's answer", "fill": "Fill the gaps", "poll": "Poll",
}


def reel_caption(d):
    r = d["reel"]
    n, L = d["day"], d["length"]
    t = r["type"]
    if t == "launch":
        body = (f"One word. Every day. The same puzzle for everyone. 🟩🟨⬛\n\n"
                f"Daily #1 is live: {L} letters, 6 tries. Can you get it in 3?\n\n"
                "👇 Comment your first guess (no spoilers!)")
        sticker = "Quiz sticker: 'Green means...?' A) Right spot B) Wrong spot C) Not in word"
    elif t == "hint":
        body = (f"Stuck on Daily #{n}? Here's a spoiler-free nudge 💡\n\n"
                f"Clue: {d['clue']}\n{L} letters · {d['vowels']} vowel{'s' if d['vowels'] != 1 else ''}\n\n"
                "Drop your first guess below 👇 Answer tomorrow.")
        sticker = "Slider sticker: 'How hard is today's word?' 😌 → 🤯"
    elif t == "replay":
        g = len(r["guesses"])
        body = (f"⚠️ Spoiler for Daily #{n - 1}: here's how it was solved in {g}/6.\n\n"
                f"How many did it take you? Comment your number 👇\n\n"
                f"Daily #{n} is live now: {L} letters.")
        sticker = f"Poll sticker: 'Did you get #{n - 1}?' Yes 🟩 / Not today ⬛"
    elif t == "pause":
        body = (f"⏸️ PAUSE & SOLVE. A few clue rows, one answer.\n\n"
                "Comment your guess BEFORE the countdown ends, then watch the reveal.\n"
                f"Clue: {r['clue']}\n\nThen try the real Daily #{n} 👉 link in bio")
        sticker = "Quiz sticker with the answer and 3 decoys from the clue rows"
    elif t == "tip":
        tip = r["tip"]
        body = (f"Pro tip: {tip['title']} 🧠\n\n{tip['body']}\n\n"
                f"Save this for later and try it on Daily #{n} today.")
        sticker = "Question sticker: 'What's YOUR best tip?'"
    elif t == "feature":
        f = r["feature"]
        body = f"{f['title']} ✨\n\n{f['body']}\n\nPlay Daily #{n} free 👉 link in bio"
        sticker = f"Emoji slider: 'Rate {f['title'].lower()}' 🔥"
    else:
        body = ("50 days. 49 words. Thank you for playing every single one. 🎉\n\n"
                "How many did you solve? Comment your total 👇\n\nWord 50 is live now.")
        sticker = "Poll sticker: 'Solved more than 40?' Yes / Not yet"
    return f"{body}\n\n{TAGS} #day{n}", sticker


def post_caption(d):
    p = d["post"]
    n, L = d["day"], d["length"]
    t = p["type"]
    if t == "teaser":
        body = (f"Daily #{n} is live 🟩 {L} letters, 6 tries.\n\n"
                f"Clue: {d['clue']}\nSwipe for the hint ladder 👉 only climb as far as you need.\n\n"
                "Comment your first guess. Answer revealed tomorrow!")
        sticker = "Countdown sticker: 'Next puzzle' at midnight"
    elif t == "guess":
        body = (f"🧩 Guess the word: three rows of clues, one answer.\n\nClue: {p['clue']}\n\n"
                "Comment your answer before you swipe 👉\nThen go play Daily #{n}.").replace("{n}", str(n))
        sticker = "Quiz sticker with the answer and 3 decoys"
    elif t == "recap":
        body = (f"⚠️ Spoiler: the answer to Daily #{n - 1}.\nThe clue was: {p['clue']}\n\n"
                "Swipe to reveal 👉 then tell us your score: 1-6 or X.\n\n"
                f"Daily #{n} is live now.")
        sticker = f"Poll sticker: 'Got #{n - 1}?' 🟩 Yes / ⬛ No"
    elif t == "fill":
        body = (f"Fill the gaps 🔤 {p['pattern'].upper().replace('_', '_ ').strip()}\n"
                f"Clue: {p['clue']}\n\nType it in the comments, then swipe for the answer 👉")
        sticker = "Question sticker: 'Fill the gaps: " + p["pattern"].upper() + "'"
    else:
        poll = p["poll"]
        opts = "\n".join(f"{'ABCD'[i]}) {o}" for i, o in enumerate(poll["opts"]))
        body = f"📊 POLL: {poll['q']}\n\n{opts}\n\nVote in the comments and tag a friend who'd pick differently 👇"
        sticker = f"Poll sticker: '{poll['q']}' with the top two options"
    return f"{body}\n\n{TAGS} #day{n}", sticker


PIN_CAPTIONS = {
    "welcome": lambda p: (
        "👋 New here? Welcome to Daily Wordle!\n\n"
        "🟩 One new word every day\n🟨 The same puzzle for everyone\n⬛ 4 to 6 letters, 6 tries\n\n"
        "Follow for daily hints, replays and play-along puzzles. Today's word is waiting 👉 link in bio\n\n"
        f"{TAGS} #newhere #starthere",
        "Link sticker to the game + 'New here? Start with this reel'"),
    "howto": lambda p: (
        "How to play in 20 seconds ⏱️\n\n"
        "🟩 Green: right letter, right spot\n🟨 Yellow: right letter, wrong spot\n⬛ Grey: not in the word\n\n"
        "Save this for later and send it to the friend who keeps asking what the coloured squares are 😄\n\n"
        f"{TAGS} #howtoplay #tutorial",
        "Quiz sticker: 'What does yellow mean?' A) Right spot B) Wrong spot C) Not in word"),
    "challenge": lambda p: (
        "🎯 THE 3-WORD CHALLENGE\n\n3 words. 3 seconds each. No pausing!\n\n"
        "Comment your score: 0, 1, 2 or 3 👇\nTag a friend you think can beat you.\n\n"
        f"{TAGS} #challenge #playalong",
        "Slider sticker: 'How many did you get?' 0 → 3"),
}


def main(out_dir):
    out = Path(out_dir)
    days = json.loads((HERE / "days.json").read_text())
    rows = []
    for d in days:
        n = d["day"]
        rc, rs = reel_caption(d)
        pc, ps = post_caption(d)
        folder = out / f"day-{n:02d}"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "captions.txt").write_text(
            f"DAILY #{n} · {d['dateLabel']} ({d['date']})\n\n"
            f"=== REEL: {REEL_NAMES[d['reel']['type']]} (reel.mp4, 9:16) ===\n{rc}\n\nStory: {rs}\n\n"
            f"=== POST: {POST_NAMES[d['post']['type']]} (post.mp4 4:5, or carousel post-slide-1/2.png) ===\n{pc}\n\nStory: {ps}\n"
        )
        d["reelCaption"], d["reelSticker"] = rc, rs
        d["postCaption"], d["postSticker"] = pc, ps
        rows.append([n, d["date"], d["dateLabel"], d["length"], REEL_NAMES[d["reel"]["type"]],
                     POST_NAMES[d["post"]["type"]], rc.replace("\n", " "), pc.replace("\n", " ")])
    with open(out / "content-calendar.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["day", "date", "label", "letters", "reel", "post", "reel caption", "post caption"])
        w.writerows(rows)
    (out / "days.captioned.json").write_text(json.dumps(days))

    pins = json.loads((HERE / "pinned.json").read_text())
    for p in pins:
        cap, sticker = PIN_CAPTIONS[p["type"]](p)
        p["caption"], p["sticker"] = cap, sticker
        folder = out / "pinned" / f"pin-{p['pin']}-{p['type']}"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "captions.txt").write_text(
            f"PINNED {p['pin']}/3 · {p['title']}\n"
            "Pin in this order so the grid reads 1, 2, 3 from the left: pin 3 first, then 2, then 1.\n"
            "Use cover.png as the reel cover.\n\n"
            f"=== CAPTION ===\n{cap}\n\nStory: {sticker}\n"
        )
    (out / "pinned.captioned.json").write_text(json.dumps(pins))
    print(f"captions for {len(days)} days and {len(pins)} pinned reels")


if __name__ == "__main__":
    main(sys.argv[1])
