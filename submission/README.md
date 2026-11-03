# Submission

Everything for the hackathon submission, kept apart from the app: nothing in this folder is
built, tested or deployed with OSMS.

- **`osms-demo.mp4`**: the demo video, 3:00 exactly, 1080p at 30 fps. Biscuit, a cartoon
  dog, presents it with its own voice: the problem OSMS solves and how, a tour of the live
  web app, the Meta models it uses, where and why Fireworks runs its judge, and its
  architecture. Built by the scripts in
  `video/`. It's git-ignored: upload it to the submission form, don't commit it.
- **`submission.md`**: the text for the form, the links, and the post on X.
- **`demo-video.md`**: a shot list for recording the tour by hand, if you'd rather narrate
  it yourself.
- **`video/`**: how the video is made, below. `video/script.md` has every line and shot.

## How the video is made

The video is put together on a Mac (Apple Silicon, 48 GB) from five parts:

1. **Biscuit** (`video/dog.py`). The art (`video/assets/`) is a generated illustration.
   LTX-2.5 (Lightricks; distilled, 8-bit, through `ltx-2-mlx`) animates it and speaks
   each line in one pass, picture and voice together. It uses the model pack and
   environment from the `modelsgoalsdataknowledge` checkout, the same setup as that
   project's cartoon reels. Each clip runs in its own process, one at a time, about
   30 seconds of machine time per second of clip. The LTX-2.x Community License is
   free for testing and evaluation and for companies under US$10M a year. It asks for
   generated media to be disclosed, so the closing card says Biscuit is AI-generated.
2. **Listening back** (`video/check_speech.py`). Meta's SeamlessM4T v2, run on this Mac,
   transcribes every clip, and the transcript is compared with the line. It's the same
   idea as OSMS's briefings, whose chapters are transcribed back before a reader hears them
   (by Muse Voice Transcribe in English and Tamil). A
   low score means a clip needs another take (another `seed` in `video/scenes.py`).
3. **The app** (`video/record.mjs`). Headless Chrome records the live demo through
   DevTools: real clicks on the app's own controls, a drawn pointer, 1440×810 points at
   4/3 scale. The signed-in shot (Add a source, Saved) is recorded on a local copy of
   OSMS, signed in as a made-up test reader. The demo has no account, so this is the only
   way to show it without anyone's real one.
4. **The cards** (`video/cards.py`, `video/look.py`): the problem, the seven Meta models,
   Fireworks (where the judge runs, and why), the architecture and the close. They use
   the app's fonts and colours, and each part appears as Biscuit says it.
5. **The cut** (`video/compose.py`): every scene timed to Biscuit's speech, captions
   from the script, and one line of the real morning briefing (SeamlessM4T v2's voice).
   The total is 180.0 s to the frame. When the lines run longer than that, Biscuit's
   clips play a little faster, picture and voice together with the pitch kept (1.06x now,
   never more than 1.08x). When they run shorter, the time left goes to a short title and
   the closing card. `scenes.py` is where every line lives.

## Making it again

```bash
PY=~/src/dev/modelsgoalsdataknowledge/.venv/bin/python   # Pillow, torch, transformers, ltx-2-mlx
cd submission/video

$PY dog.py                       # Biscuit's twelve clips (about 90 min); kept clips are skipped
HF_HUB_OFFLINE=1 $PY check_speech.py   # SeamlessM4T v2 listens back; scores in build/speech-check.json

# The live demo, in a headless Chrome:
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --remote-debugging-port=9333 --user-data-dir=build/chrome --hide-scrollbars --mute-audio &
node record.mjs today story sections decided listen listenIn ask

# The signed-in shot, on a copy of your local data (your own is never touched):
cp -R ../../data build/localdata
(cd ../../auth && AUTH_DATABASE_PATH=$PWD/../submission/video/build/localdata/auth.db OSMS_DEV_SIGN_IN=1 npm start) &
(cd ../../backend && L=$PWD/../submission/video/build/localdata && DATABASE_URL=sqlite:///$L/osms.db \
  OSMS_MILVUS_PATH=$L/milvus.db OSMS_BRIEFINGS_DIR=$L/briefings uv run uvicorn app.main:app --port 8000) &
(cd ../../frontend && flutter build web --release --no-web-resources-cdn --output=../submission/video/build/localweb)
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/localweb &
#   sign in at http://localhost:8080 with "Email me a sign-in link" and a made-up address,
#   open the link the sign-in service logs, pick Startups and product + AI research; then:
node record.mjs yours

# The briefing whose first #706 sentence is the listen-in (Nov 3's; see LISTEN_IN in compose.py):
curl -s "$(curl -s https://api.onestory-osms.duckdns.org/demo/briefing \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["audio_url"])')" -o build/briefing-audio

$PY compose.py --still 42        # one frame, to look at first
$PY compose.py                   # ../osms-demo.mp4
```

The shots name stories as the live demo had them on 3 November (#706 iPad mini, #516
Apple Intelligence in China, #309 the M6 iMac with its Danish source). Check that they're
still there before recording again. A new day's briefing moves the listen-in line, too.
