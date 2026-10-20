# Wordle

A daily word puzzle game built with Flutter, for Android, iOS, web and desktop.

## Features

- **Daily puzzle**: one word a day, the same for everyone, 4 to 6 letters long. A new one unlocks at midnight.
- **Day streak and calendar**: keep a streak by playing each day, and catch up on past days from the calendar.
- **Practice**: unlimited random 4, 5 or 6 letter words.
- **Hard mode**: every letter you find must be used in later guesses. Wins earn bonus points.
- **Hints**: reveal a letter, up to 2 per game, for a few points.
- **Stats**: win %, streaks and guess distribution for each word length.
- **Share**: copy an emoji grid of your result.
- **Light and dark themes**, plus physical keyboard support on web and desktop.

## Project layout

```
lib/
  main.dart               App entry and theme wiring
  app_settings.dart       Theme mode and hard mode, shared across screens
  theme/app_theme.dart    Colours (incl. tile colours) for light and dark
  game/game_logic.dart    Pure rules: scoring, hard mode, daily word, streaks
  game/game_controller.dart  One game's state, input and persistence
  data/word_repository.dart  Loads and caches the word lists
  data/storage.dart       Points, stats, daily progress and settings
  models/game_stats.dart  Per-length statistics
  screens/                Home, game and calendar screens
  widgets/                Board, keyboard, stats, result and info sheets
assets/
  daily_words.json        2,000 dated daily puzzles; loops after the last day
  easy_words_json/        Answers for practice mode
  all_english_words/      Words accepted as guesses
```

## Running

```
flutter pub get
flutter run
flutter test
```
