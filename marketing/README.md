# Social kit: 50 days of reels and posts

Generates one animated reel (1080x1920, with sound) and one post (1080x1350
video plus a two-slide carousel) for each of the first 60 daily puzzles, along
with captions, story-sticker ideas and an interactive preview page.

`social/pinned/` holds three evergreen reels to pin at the top of the profile
(welcome, how to play, 3-word challenge), each with a `cover.png`. Pin 3
first, then 2, then 1, so the grid reads 1, 2, 3 from the left.

Nothing gives away a day's answer on that day: replays and recaps show
yesterday's word, and guess-along puzzles use practice words that are not in
the daily schedule.

| File | Does |
| --- | --- |
| `plan.py` | Builds `days.json` and `pinned.json`: formats, clues, guess paths, polls, tips |
| `engine.js` | Draws every reel and post as a function of time (canvas) |
| `render.js` | Renders frames in headless Chromium and encodes MP4s and PNGs |
| `audio.py` | Synthesises music and sound effects from the engine's cues |
| `captions.py` | Writes captions, hashtags and a content calendar CSV |
| `build_preview.py` | Bundles `preview.html` into one interactive page |

```
python3 plan.py
node render.js out 1-60 --workers=4      # needs Playwright and ffmpeg
node render.js out --pins
python3 audio.py out
python3 captions.py out
python3 build_preview.py out
```
