# DreamCast — Closed test (12 testers × 14 days)

Google requires new personal developer accounts to run a **closed test with
at least 12 testers who stay opted in continuously for the last 14 days**
before **Apply for production** unlocks on the Dashboard
([Play Console Help 14151465](https://support.google.com/googleplay/android-developer/answer/14151465)).

**Recruit 16–20 testers, not 12.** People drop out; if the opted-in count
falls below 12 the 14 days effectively restart.

## Timeline

| Day | What happens |
|---|---|
| Before day 0 | Backend live over HTTPS · legal pages live · release `.aab` built against the live API · reviewer account created |
| Day 0 | Upload to the closed track, send to review (usually 1–3 days), then send the opt-in link |
| Days 1–14 | Testers keep the app installed and use it a few times; you fix issues and ship at least one update |
| Day 15+ | Apply for production (answers drafted below); review takes up to ~7 days |

## 1. One-time Play Console setup

1. **Create the tester list.** Use a Google Group so testers can join
   themselves: groups.google.com › Create group › name `dreamcast-testers`,
   *Who can join*: "Anyone on the web can ask" (or "Invited users only"). Or
   use an email list (Play Console › Testing › Closed testing › Testers ›
   Create email list) and paste the Gmail addresses from `testers.csv`.
2. **Create the track.** Testing › Closed testing › **Create track** ›
   name `Closed testing - DreamCast beta`.
   - **Countries/regions:** Cameroon plus every country your testers live in.
   - **Testers:** add the Google Group email (or the email list).
   - **Feedback URL or email:** `chinjiesylvestern@gmail.com` (or a Google Form).
3. **Make purchases free for testers.** Setup › **License testing** › add
   every tester's Gmail. License testers can buy subscriptions with Google's
   test cards (no real charge); test monthly subscriptions renew every 5
   minutes and stop after 6 renewals, so the full lifecycle can be tested.
4. **Create a release.** Closed testing › your track › Create new release ›
   upload `app-release.aab` › paste the release notes from `STORE_LISTING.md` ›
   Review release › **Start rollout to Closed testing**. Accept **Play App
   Signing** when asked (Google holds the app signing key; you keep the
   upload key).
5. Once approved, copy the **opt-in link** (Testers tab ›
   "How testers join your test" › Join on Android) and send the invitation
   below.

## 2. Invitation message

### English

```
Hi! I've built DreamCast, an app that turns the dreams you record into
thoughtful readings, and I need testers for two weeks before it launches on
Google Play.

What I'm asking:
1. Join the test group: <GOOGLE GROUP LINK>   (use your Gmail)
2. Accept the test here: <OPT-IN LINK>
3. Install DreamCast from the Play Store page that opens.
4. Keep it installed for 14 days and open it a few times — record a dream or two.

Subscriptions are free for testers (Google test payment, no real charge).
Tell me anything that feels broken or confusing: chinjiesylvestern@gmail.com
Thank you — it really helps!
```

### Français

```
Bonjour ! J'ai créé DreamCast, une application qui transforme les rêves que
vous notez en interprétations, et j'ai besoin de testeurs pendant deux
semaines avant son lancement sur Google Play.

Ce que je vous demande :
1. Rejoignez le groupe de test : <LIEN DU GROUPE GOOGLE>   (avec votre Gmail)
2. Acceptez le test ici : <LIEN D'INSCRIPTION>
3. Installez DreamCast depuis la page Play Store qui s'ouvre.
4. Gardez l'application installée 14 jours et ouvrez-la quelques fois — notez un ou deux rêves.

Les abonnements sont gratuits pour les testeurs (paiement de test Google, aucun vrai débit).
Signalez-moi tout problème : chinjiesylvestern@gmail.com
Merci beaucoup, ça m'aide énormément !
```

## 3. What testers should try (send on day 1, 5 and 10)

| When | Ask testers to… |
|---|---|
| Day 1 | Create an account · record a dream by typing · read the result · open the Archive |
| Day 3 | Record a dream by **voice** (mic button) · share a Dream Card |
| Day 5 | Open **PLANS** · subscribe to **Lucid** (free test payment) · check the PLANS pill now says LUCID |
| Day 7 | **Upgrade** to Mystic or Oracle · compare how readings change |
| Day 10 | **Report** a reading with the flag icon · open Privacy Policy and Terms from the account menu |
| Day 12 | Cancel in Google Play › Subscriptions and confirm access continues until the period ends · **Restore purchases** after reinstalling |
| Day 14 | Send overall feedback (what they liked, what confused them) |

Remind testers **not** to uninstall or leave the group until you confirm
day 14 has passed. Never ask testers to delete their account during the test.

## 4. Track testers

Keep `testers.csv` up to date (name, Gmail, invited, joined group, opted in,
installed, last active, feedback). Play Console shows the opted-in count
under Testing › Closed testing › your track.

## 5. During the 14 days

- Ship at least **one update** (fix something testers found; bump `version`
  in `pubspec.yaml`, e.g. `1.0.1+2`). Google looks for evidence that testing
  shaped the app.
- Write down every piece of feedback and what you changed — you need it for
  the application.
- Check `dream_reports` and the backend logs daily.

## 6. Apply for production — draft answers

Dashboard › **Apply for production**. Edit with your real numbers and
feedback before submitting.

**How did you recruit users for your closed test?**
> I invited friends, family and colleagues in Cameroon who are interested in
> dreams and journaling, through WhatsApp and email, using a Google Group.
> <N> people joined and <N> stayed opted in for the full 14 days.

**How easy was it to recruit testers?** Pick the honest option.

**Describe the engagement you received from testers.**
> Testers created accounts, recorded dreams by typing and by voice, read
> their interpretations, browsed their archive, shared Dream Cards, and
> tested the Lucid, Mystic and Oracle subscriptions with test payments,
> including upgrades, cancellation and restore. <Add numbers: e.g. "about N
> dreams recorded, N subscriptions tested".>

**Summarize the feedback you received and how you collected it.**
> Feedback came by email and WhatsApp messages and a short form at the end of
> the test. <List the 3–5 most common points, e.g. "voice entry stopped too
> early", "wanted clearer plan differences".>

**What changes did you make based on testing?**
> <List each change and the version it shipped in, e.g. "1.0.1: longer
> listening time for voice entry; clearer plan comparison text".>

**Who is the intended audience?**
> Adults (18+) who want to remember and reflect on their dreams, starting in
> Cameroon and French- and English-speaking Africa.

**How does your app provide value to users?**
> DreamCast makes it quick to capture a dream before it is forgotten and
> offers a thoughtful, non-clinical reading of its symbols and themes, with a
> private archive to see patterns over time.

**How many installs do you expect in your first year?** Choose a realistic
range.

**What changes did you make to make your app ready for production?**
> Completed Data safety, content rating and target audience declarations;
> published a privacy policy, terms and an account-deletion page; added
> in-app account deletion and reporting of AI-generated content; verified
> subscriptions server-side with Google Play.
