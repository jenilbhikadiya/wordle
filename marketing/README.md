# Social kit: 50 days of reels and posts

Generates one animated reel (1080x1920, with sound) and one post (1080x1350
video plus a two-slide carousel) for each of the first 50 daily puzzles, along
with captions, story-sticker ideas and an interactive preview page.

Nothing gives away a day's answer on that day: replays and recaps show
yesterday's word, and guess-along puzzles use practice words that are not in
the daily schedule.

| File | Does |
| --- | --- |
| `plan.py` | Builds `days.json`: formats, clues, guess paths, polls, tips |
| `engine.js` | Draws every reel and post as a function of time (canvas) |
| `render.js` | Renders frames in headless Chromium and encodes MP4s and PNGs |
| `audio.py` | Synthesises music and sound effects from the engine's cues |
| `captions.py` | Writes captions, hashtags and a content calendar CSV |
| `build_preview.py` | Bundles `preview.html` into one interactive page |

```
python3 plan.py
node render.js out 1-50 --workers=4      # needs Playwright and ffmpeg
python3 audio.py out
python3 captions.py out
python3 build_preview.py out
```
