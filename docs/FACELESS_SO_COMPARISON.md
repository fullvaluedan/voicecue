# faceless.so vs VoiceCue plus our pipeline

Written 2026-11-21. Research only, no code changed. Kept as a reference: faceless.so modelled the script,
edit and post service well, so use this when planning those parts.

## Dan's direction (2026-11-21)

Keep the product simple. The one headline feature is the VoiceCue teleprompter floating directly over TikTok
while you record there, following your voice. That is `NATIVE_APP_PLAN.md`, Phase 0 first. The script, edit
and post pieces below are for later, using faceless.so as the model.

## Do they really post for you?

Yes, per their own developer docs (faceless.so/developers/docs/publishing-and-scheduling.md), not tested by us:

- You connect each social account once in their dashboard (the normal "log in with TikTok" style approval).
- Then a finished video goes out to YouTube, TikTok, Instagram, Facebook, LinkedIn, Threads or X, either right
  away or at a scheduled time, and they return the link to the live post.
- A daily "series" can make and post a new video every day on its own, with an optional approve step first.
- Posting is free on every plan; only making the video costs credits.
- How many posts a plan allows: 3 a week on Starter up to 8 a day on Agency.

Dan's question: can we offer everything faceless.so offers, built around VoiceCue? His flow is: get a script,
record it with VoiceCue, let the tool edit the video, then post it.

## Short answer

Yes for the flow Dan wants, and it is a different product from faceless.so. faceless.so makes videos with no
person in them (AI images, AI video clips, AI actors). It never mentions recording yourself, a camera or a
teleprompter. Our strength is the opposite: you on camera, reading a script that follows your voice.

Every step of Dan's flow already exists for Dan's own channels. None of it is built for outside users yet. The
editing and posting run on Dan's PC, use his accounts, and need Resolve or his GPU. Turning it into a service
is mostly that work: accounts, billing, a cloud editor, and posting to the customer's own social accounts.

Matching faceless.so's faceless side too (AI images, AI video clips, AI actors) is possible, since we already
use Gemini, Flow and Veo for Dan, but it would put us in a crowded race against a company doing about 50,000
dollars a month. I would not lead with it.

## What faceless.so is

- Company: Faceless LLC, India. Founded August 2023. [vendor]
- Size: about 49,500 dollars monthly revenue and 1,139 active subscriptions, Stripe verified on TrustMRR.
  [independent] Their home page claims "10,000+ channels" and "500+ five-star reviews", which I could not
  verify and which look high next to 1,139 subscriptions.
- Reviews: almost none. Product Hunt has 32 upvotes and no reviews. No Trustpilot, G2 or Capterra listing. One
  directory comment says it claims "free" but has no free option. [independent]
- Careful: most "Faceless" reviews online are about Faceless.video or FacelessReels, different companies.

Sources: faceless.so/pricing, faceless.so, faceless.so/llms.txt, faceless.so/developers,
faceless.so/ai-instructions.md, faceless.so/terms.md, faceless.so/tools/ai-ugc-video-generator,
faceless.so/roadmap, producthunt.com/products/faceless-so/reviews, trustmrr.com/startup/faceless-so.

## Pricing summary [vendor]

| Plan | Monthly | Yearly (per month) | Credits a month | About how many 1 min Shorts (image / AI video) | Auto posts | Seats |
|---|---|---|---|---|---|---|
| Starter | 29 | 24 | 500 | 25 / 8 | 3 a week | 3 |
| Growth | 39 (shown as "was 49") | 32 | 1,000 | 50 / 16 | daily | 5 |
| Influencer | 69 | 57 | 2,000 | 100 / 33 | 2 a day | 7 |
| Ultra | 99 | 82 | 4,000 | 200 / 66 | 4 a day | 10 |
| Agency | 199 | 166 | 8,000 | 400 / 133 | 8 a day | 25 |

- All plans get every creation feature and auto posting. Growth and up add the AI agent editor. UGC (AI
  actors) is Growth and up on one page, Influencer and up on another. Ultra and up get the API.
- Credit costs: image Short 20 (30 with fast cuts), AI video 2 to 6 credits a second, captions on your own
  video 20, Reddit story or fake text video 20, slideshow 5, 10 minute stickman video about 442.
- Extra credits: 10 dollars for 100, 25 for 275, 50 for 600. Plan credits stop rolling over from 2026-10-02.
- No free trial. You can write scripts and pick voices free, rendering needs a plan. No refund once any credit
  is used. Failed videos refund their credits, the first regenerate is free.
- What one Short costs a customer: about 1.15 dollars (image Short on Starter) to about 3.60 dollars (AI video
  Short on Starter). Captioning your own video costs the same 20 credits as a full image Short, about 1.15.

## Feature by feature

"Have" means it works today for Dan. Almost nothing is ready for outside users; that is the last column.

| Feature | faceless.so [vendor] | Us today | Gap to sell it |
|---|---|---|---|
| Script from a prompt | Yes, model not named | Have: scriptwriter skill (Claude), with a check team | Needs a web form and an API call per user instead of Dan's Claude Code session |
| Script from live sources (Trends, News, Reddit, Wikipedia) | Yes | Part: Reddit RSS, X bookmarks, YouTube search, idea board, all for Dan's niches | Per user topics and a simple "give me 5 ideas" page |
| Paste your own script | Yes | Have: VoiceCue editor | None |
| Teleprompter that follows your voice | No | Have: VoiceCue, calm tracking, notes it skips, phone and desktop | Phone limit: tracking pauses while the camera records on phones (mic conflict). Native app plan fixes this |
| Record yourself on camera | No (import only) | Have: VoiceCue Studio Camera, 9:16 and 16:9, takes, markers, EDL and markers export | Takes only download to the device. Needs upload to our cloud |
| Float the script over TikTok | No | Planned: NATIVE_APP_PLAN.md, not built | Phase 0 test on iPhone first |
| AI voices | ElevenLabs built in, 90+ languages | Have: Gemini TTS (Larry voice), for Dan | Voice picker and per user billing. Only needed for faceless mode |
| Clone your own voice | Yes | Part: used for Dan's long faceless format (vo_mode clone) | Consent flow, per user voice storage |
| Cut out mistakes and pauses from your take | Not mentioned | Have for Dan: Groq word times, retake detection, "last take is best", cut checks | Must run in the cloud without Resolve. clipcut needs only ffmpeg, a good start |
| Captions | Word timed, "cinematic" styles | Have: .srt and burned captions, Resolve subtitle pass | Two or three caption styles rendered in the cloud |
| Graphics over a talking head | No | Have: Argon face plus graphics formats, thgfx segment graphics. Best in class, but slow and hand checked | Too slow and too custom for self serve today. Offer a few fixed templates first |
| AI images or AI video b-roll | Yes: Veo 3.1, Kling 3.0, Seedance, Wan, Nano Banana Pro, GPT Image | Part: Flow and Veo b-roll adapter, Gemini images, for Dan | Paid API keys per video, credit system |
| AI actors (lip synced avatars) | Yes, 8 lip sync engines, up to 60 s | No | Skip. It is the opposite of our pitch |
| Reddit story, fake texts, gameplay split screen, stickman | Yes, 28 niches | Part: game clip format, docreel engine | Skip at launch |
| Music and sound effects | Yes | Have: music beds, Flow music, sfx tools | License check for resale. Use a royalty free library |
| Timeline editor | Yes, "Studio" desktop editor | Part: Resolve timelines (fcpxml export from clipcut) | A simple web trim editor, or skip and offer "fix it" in plain words |
| Edit by plain language ("make it faster") | Yes, AI agent, Growth and up | Part: that is how Dan works with Claude today | Wrap as a chat box on the finished video |
| Auto post | YouTube, TikTok, Instagram, Facebook, LinkedIn, Threads, X | Have: Postiz for Shorts (TikTok, Instagram, Facebook, X), YouTube API for long videos, Dan's accounts only | Customers must connect their own accounts. See posting below |
| Schedule and autopilot series | Yes, up to 6 a day, queue to approve or skip | Have: niche config, schedule, one tap approve | Per user queue page |
| Analytics | iPhone app, views and growth | Part: A1 track node for Dan's channels | Later |
| API, CLI, MCP server | Yes, Ultra and up | No public one | Later |
| Team seats | 3 to 25 | No | Later |
| Languages | 90+ | Part: localize pipeline for Pocket Watching | Later |

## What it takes to sell it

Our tools assume one user (Dan), one PC with an RTX 3080, Resolve open, and his own logins. A service needs:

| # | Piece | Why | Rough effort |
|---|---|---|---|
| 1 | Accounts and billing | Sign in, a plan, credits, Stripe. Dan's Smarter Futures LLC already has Stripe | 1 to 2 weeks |
| 2 | Take upload | VoiceCue takes go to cloud storage (Cloudflare R2, already used by Prends Studio) instead of only downloading | 3 to 5 days |
| 3 | Cloud auto edit, version 1 | Transcribe the take, cut stumbles and long pauses, keep the last good take, crop 9:16, add captions and music. ffmpeg and Groq on a server, no Resolve | 2 to 4 weeks, mostly tuning so cuts are clean on strangers' recordings |
| 4 | Script helper | Topic in, script out, written for reading aloud, straight into VoiceCue | 1 week |
| 5 | Posting to the customer's own accounts | Hardest legal and review part. TikTok's posting API needs an app audit before posts can be public. Instagram and Facebook need Meta app review and a business account. YouTube's default quota allows only about 6 uploads a day for the whole app, so we must apply for more. A paid posting API (Ayrshare, upload-post and similar) skips most of this for a monthly fee | 1 to 2 weeks with a posting API, 1 to 3 months doing our own app reviews |
| 6 | Native iPhone app (floating script) | Our real moat, see NATIVE_APP_PLAN.md | Already planned, 1 to 2 weeks after Phase 0 |
| 7 | Graphics templates | Two or three fixed looks from the Argon and thgfx work, rendered on a cloud GPU | 2 to 3 weeks |
| 8 | Faceless mode (AI voice and b-roll) | Only if customers ask. Gemini TTS plus Veo or image b-roll | 2 to 3 weeks, higher running cost |

A first paid version is items 1 to 5: about 6 to 10 weeks of build, faster with parallel sessions.

## Running cost per video (rough estimates, check before pricing)

For a 1 minute Short the customer recorded themselves:

- Transcription (Groq Whisper): under 1 cent.
- Script help (Claude API): about 2 to 10 cents.
- Cutting and captions on a cloud server or GPU: about 5 to 20 cents.
- Storage (R2, kept 20 days like Prends Studio): about 1 cent.
- Posting through a paid posting API: about 10 to 30 cents a post spread over its monthly fee, or near zero
  after our own app reviews pass.
- Total: roughly 20 to 60 cents. Self recorded videos are cheap because no AI video is generated.
- Adding Veo b-roll or AI voice raises it to about 1 to 4 dollars, close to faceless.so's own costs.

So we could charge in faceless.so's range (29 dollars a month for about 25 videos) and keep a good margin on
recorded videos.

## What makes us different

1. You, not an AI actor. faceless.so is built for people who hide. We are built for people who show up, and
   for them the hard part is reading a script naturally. That is VoiceCue.
2. A teleprompter that follows your voice and ignores ad-libs. faceless.so has no teleprompter at all.
3. Floating over TikTok (after the native app). Neither faceless.so nor most teleprompters do this well.
4. Edits that fix your take: cut the stumble, keep the last good line. faceless.so only captions your video.
5. Scripts written for talking, checked before you read them, from the same skill Dan uses.

## Build list in priority order

1. Native app Phase 0 (does the script float over TikTok and still hear you). It decides the hook of the product.
2. Take upload from VoiceCue to the cloud.
3. Cloud auto edit v1: cuts, 9:16 crop, captions, music.
4. Accounts, credits and Stripe.
5. Posting through a paid posting API first, own app reviews in the background.
6. Script helper inside VoiceCue.
7. Two or three graphics templates.
8. Later, only on demand: faceless mode, AI voices, analytics, API, team seats, more languages.

## Recommendation

Do not copy faceless.so. Sell the face version of it: "Write it, read it, we cut and post it." Start with the
native app test, because floating over TikTok is the thing nobody else has. Then build upload, cloud edit and
posting through a paid posting API, which gets a first paid version in about two months. Leave AI actors and
AI b-roll out until customers ask. Price near faceless.so's Starter (about 29 dollars a month) and test with a
few creators on TestFlight first.

Open questions for Dan: the name check from the native app plan (VoiceCue vs VoicePrompter), and whether he
wants to run posting through a paid posting API or wait for our own TikTok and Meta app approvals.
