# Spec: Saved, Share and Add a source (Nov 3, 2026)

**Goal:** the last dead buttons work. Saved is the same list on every device; Share
passes a story on as links; Add a source follows any site, feed or handle by pasting it.

## Saved

- Storage: `saved_stories` (reader, story, when; migration `0010`), deleted with the
  account by the foreign keys' cascades.
- API, signed in only: `GET /saved` (the same shape as `/stories`, newest saved first,
  only stories the reader's sources still reach), `PUT` and `DELETE
  /stories/{id}/saved` (204, both safe to repeat; saving a story the reader can't see
  is a 404, never a peek, rule 7).
- App: the bookmark in the story toolbar saves at once and sends it after; a refusal
  puts it back and says so. The sidebar's Saved and the phone's Saved tab list them.
  Signed out, the demo saves on the page only. The invented samples have no Save.

## Share

Copies the story's title, OSMS's summary, who reported it and up to five links to the
original reports. Links only, never the publishers' text (rule 5). No Share for the
invented samples.

## Add a source

- Input: a link (a bare domain gets `https://`) or a handle: `@name@host` (Mastodon),
  `@name.bsky.social` (Bluesky), `r/name` (Reddit).
- Discovery (`services/ingestion/discovery.py`): one fetch through the fetcher, public
  addresses only and every redirect re-checked. A feed is read as a feed; an HTML page
  only for the feed it names (`<link rel="alternate">`, relative links resolved, the
  first one wins). Type from the host or handle (arXiv, YouTube, Reddit, Bluesky,
  Mastodon), podcast when an entry has audio, else feed. Language from the entries'
  words, else the feed's own. Frequency in words from the entries' dates.
- API, signed in only, 20 lookups per reader per 10 minutes (429):
  - `POST /me/sources/discover {query}`: the preview (the source as OSMS would keep it,
    its three newest titles and links, how often it publishes, whether the reader
    already follows it). Stores nothing. 404 when there's no feed, 422 for an address
    OSMS never fetches.
  - `POST /me/sources {query}`: looks it up again (the preview is never trusted for
    the address), reuses the source OSMS already has at that address or adds it, follows
    it and fetches it at once. At most 500 sources per reader.
  - `DELETE /me/sources/{id}`: stops following; the source stays for other readers.
- App: the sidebar's **Add a source** and the empty states open the sheet: paste,
  **Find**, the preview, **Subscribe**. The new source appears in the sidebar; its
  stories arrive with the fetch. Signed out, there is no Add a source.

## Not yet

OPML import from the app (the sheet hides the button until it works); YouTube channel
pages from the EU, which answer with a consent page instead of naming their feed.

## How to test

- Backend: `tests/test_discovery.py` (direct feed, a page naming its feed, handles,
  podcast and YouTube types, nothing found, unsafe addresses and redirects, frequency
  words, input checks, the rate limit, following, reusing a seed source, unfollowing);
  saved-story tests in `tests/test_stories_api.py`.
- App: `test/keep_share_add_test.dart` (save, list, unsave and a refused save; the
  demo's page-only saves; Share's clipboard text; finding and following a source; no
  feed found; the demo's sample episodes labelled).
