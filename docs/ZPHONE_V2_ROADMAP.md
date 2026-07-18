# Z-Phone v2 — Product & Design Roadmap

Living document for turning Z-Phone into a premium, LB-Phone-competitive resource while keeping an open, restylable UI and GTA lore-friendly branding.

**Status:** Planning  
**Last updated:** 2026-07-18  
**Related discussion:** Paid version parity / Liquid Glass UI / lore brands

---

## 1. North star

Ship a phone that servers choose over paid alternatives because it feels like a real **iFruit OS** device in Los Santos:

1. Modern **Liquid Glass (iOS-inspired)** UI
2. **GTA lore-friendly** app names and brands
3. Platform systems that match paid phones (unique phones, media, custom apps)
4. Remains **editable / open** (advantage LB cannot offer)

We are **not** cloning LB app-for-app. We win on immersion, shell polish, and extensibility.

---

## 2. Current baseline (Z-Phone today)

### Strengths
- Cohesive dark UI redesign over classic qb-phone
- Core RP loop: Phone, Messages, Camera/Gallery, Mail, Bank, Garage, Services
- Custom apps: Pulses (social), Proxi (marketplace), Party (groups/jobs), Ping
- QBCore + Qbox / ox_inventory / ox_target / ox_lib compatibility
- Browser `?dev=1` preview for frontend work
- Open HTML/CSS/JS (fully restylable)

### Gaps vs paid phones (e.g. LB Phone)
| Area | Today | Target |
|---|---|---|
| Phone identity | Character-bound (qb-phone style) | Unique item-bound phones |
| UI language | Dark neon / Samsung One UI hybrid | Liquid Glass iFruit OS |
| Branding | Mixed generic + some lore (Fleeca) | Full lore brand pack |
| Media | Basic camera/gallery | Video, albums, reliable hosting |
| Calls | Voice | Voice + video / WebRTC path |
| Extensibility | Hardcoded apps | Custom app API + iFruit Store |
| Frameworks | QB / Qbox | QB / Qbox first; ESX/standalone later |
| Frontend stack | jQuery + Bootstrap + per-app CSS | Component system + design tokens |

Rough scale: ~26k LOC today vs ~60k for a mature paid phone product. The biggest deficit is **platform**, not only app count.

---

## 3. Product principles

1. **Shell first** — If lock screen, home, dock, and notifications look mid, no app count saves it.
2. **One OS language** — Default is iFruit / Liquid Glass. Android (Whiz) is a later theme, not a mixed default.
3. **Canon where it fits; original for crime/custom** — Use Rockstar parody brands for civilian apps; invent Z-Phone brands for dark web / weed / server-specific systems.
4. **Stable internal IDs** — Keep `pulses`, `proxi`, etc. in code; change display names via a brand/locale layer.
5. **Parity by feel, not by checklist** — Unique phones + plugin API + gorgeous shell beat cloning Trendy/Spark on day one.
6. **Performance under load** — Progressive lists, pagination, less full-state sync.

---

## 4. UI direction — Liquid Glass / iFruit OS

### Decision
- **Primary visual identity:** iOS Liquid Glass–inspired **iFruit OS**
- **Secondary (later):** Whiz OS / Material You Android theme pack

### Why not incremental CSS?
Current stack (jQuery, Bootstrap, ~11k lines of per-app CSS, mixed fonts, neon blue accents, One UI home comments) cannot reach Liquid Glass with blur tweaks alone. Needs a design system + shell rewrite.

### Design system (required before app redraws)
Token layers every app must inherit:

- **Materials:** `glass-thin`, `glass-regular`, `glass-thick`, opaque
- **Radii / spacing:** consistent 4/8/12/16 scale
- **Blur / specular / hairline border recipes**
- **Type scale:** display / title / body / caption (SF-like; avoid random font mix)
- **Semantic colors:** label, secondary, tertiary, fill, separator
- **Motion curves:** app open, dismiss, sheet, toast

### Shell must include
- Wallpaper-aware glass (materials sample wallpaper, not flat `#111`)
- Lock screen + notification stack
- Home + dock with separation blur
- Consistent squircle app icons / lighting
- Status bar (carrier, signal, battery)
- Control Center–lite (brightness/volume/mute/vibrate)
- Signature motions: icon-origin app open/close, interactive dismiss, banner physics

### App migration order (visual)
1. Shell (frame, status, lock, home, dock, notifications)
2. Phone + Contacts
3. Messages
4. Settings
5. Camera / Gallery (Snapmatic)
6. Bank / Mail / Services
7. Lifeinvader / Classifieds / SecuroServ / Garage

### Frontend architecture target
- New `ui/` app (React or Vue, or solid componentized vanilla)
- Shared primitives: `GlassSurface`, `ListRow`, `NavBar`, `Sheet`, `TabBar`, `IconButton`, `SearchField`
- Single theme variables file
- Remove Bootstrap from phone chrome
- Keep Lua/NUI callback contracts stable during migration
- Continue using `html/?dev=1` (or successor) for browser-first UI review

---

## 5. Lore branding bible

### OS & carrier
| Role | Brand |
|---|---|
| OS | **iFruit** |
| Alternate OS (later) | **Whiz** |
| Default carrier | **iFruit Wireless** (alts: Whiz Mobile, Badger Telecom) |
| App Store | **iFruit Store** |
| Maps | **iFruit Maps** |

### Current apps — display names

| Internal ID | Current label | v2 display name | Notes |
|---|---|---|---|
| `phone` | Phone | **Phone** | Keep generic under iFruit |
| `message` | Messages | **Messages** | Optional alt: Tinkle |
| `camera` | Camera | **Snapmatic** | Canon camera brand |
| `gallery` | Gallery | **Snapmatic** | Same family / albums tab |
| `settings` | Settings | **Settings** | Generic OK |
| `ping` | Ping | **iFruit Maps** | Location share belongs here |
| `mail` | Mail | **Mail** | Addresses `@eyefind.info` |
| `bank` | Bank | **Fleeca** | Already close (`Fleeca Digital`) |
| `garage` | Garages | **SecuroServ** or **LSC Garage** | Decide: valet/premium vs civilian |
| `services` | Services | **Eyefind Services** | Directory / on-duty jobs |
| `calculator` | Calculator | **Calculator** | No rename |
| `pulses` | Pulses | **Lifeinvader** | Social feed / profiles |
| `proxi` | Proxi | **Eyefind Classifieds** | Or original mall brand if preferred |
| `party` | Party App | **SecuroServ** | Groups / job stages |
| `weed-marketplace` | Weed Marketplace | **Original brand TBD** | Do not force a Rockstar brand |
| `group-chats` | Dark Web | **ShadowNet** (working title) | Original crime brand |
| `lsbn` | Wezeal News | **Weazel News** | Fix spelling |

### Future apps — brand from day one

| Feature | Brand |
|---|---|
| Microblog (Twitter-like) | **Bleeter** |
| Short video | Weazel **Reelz** (working) or Fame-or-Shame flavored original |
| Dating | Original (e.g. **SparkLS**) — avoid over-meme |
| Stocks / crypto | **Bawsaq** |
| Housing | **Dynasty 8** |
| Music | **Radio Los Santos** / Media Player |
| Browser | **Eyefind.info** |
| Weather | **Weazel Weather** |
| Notes / Clock | Generic |

### Branding rules
1. Canon brands for civilian life; **original brands for crime/custom RP**.
2. Satirical GTA copy voice in empty states / taglines — premium shell, not comedy spam.
3. Email domains: `@eyefind.info`, business `@weazel-news.tv`, etc.
4. Implement as **`Config.Brand` / locale pack**, not hardcoded strings in every JS file.

### Draft `Config.Brand` shape

```lua
Config.Brand = {
    OS = "iFruit",
    Carrier = "iFruit Wireless",
    Apps = {
        pulses = { name = "Lifeinvader", tagline = "Share your life." },
        proxi  = { name = "Classifieds", tagline = "Buy local. Sell faster." },
        bank   = { name = "Fleeca", tagline = "Banking for regular people." },
        camera = { name = "Snapmatic", tagline = "Capture Los Santos." },
        gallery = { name = "Snapmatic", tagline = "Your moments." },
        party  = { name = "SecuroServ", tagline = "Organization tools." },
        ping   = { name = "Maps", tagline = "Find your way." },
        mail   = { name = "Mail", tagline = "Inbox zero is a myth." },
        services = { name = "Eyefind", tagline = "Services near you." },
        garage = { name = "Garage", tagline = "Your vehicles." },
    }
}
```

*(Exact garage/services naming still open — see Open questions.)*

---

## 6. Platform roadmap (feature parity)

### Phase A — Foundation
1. Unique phone items + data ownership (steal/drop/give keeps data)
2. Media hosting + gallery/video pipeline
3. Custom app API + one reference third-party app
4. Message/call reliability (groups, attachments, missed-call UX)

### Phase B — Daily drivers
5. Notes, Clock, Weather, real Maps
6. Garage valet + housing keys (Dynasty 8)
7. Social v2 (Lifeinvader: richer feed, DMs, media)
8. iFruit Store / installable apps

### Phase C — Premium feel
9. Video calls / speaker / nearby share (AirShare-like)
10. Locales, ringtones, setup wizard, battery/airplane polish
11. ESX / standalone adapters
12. Admin logs, moderation, anti-abuse

### Keep as Z-Phone advantages
- Fully editable open UI
- Party / job-group tooling for QB servers
- Themed originals (classifieds, weed market, ShadowNet)

---

## 7. Suggested build sequence

```text
Brand bible lock
    → Design tokens + Liquid Glass shell prototype (browser dev)
        → Wire shell to existing NUI callbacks
            → Migrate Messages + Phone
                → Snapmatic camera/gallery pass
                    → Rename layer (Lifeinvader, Fleeca, etc.)
                        → Phase A platform (unique phones, media, custom apps)
                            → Phase B/C features
```

UI shell prototype should be reviewable in browser without FiveM.

---

## 8. Open questions

- [ ] Garage display brand: **SecuroServ** vs **Los Santos Customs** vs generic Garage?
- [ ] Proxi display brand: **Eyefind Classifieds** vs original mall name?
- [ ] Messages: stay **Messages** or use **Tinkle**?
- [ ] Frontend framework for `ui/`: React vs Vue vs componentized vanilla?
- [ ] Unique phones: require `ox_inventory` only, or also QB item info path?
- [ ] Media host: Fivemanage / custom S3 / other?
- [ ] Weed marketplace + ShadowNet final brand names?
- [ ] Is Whiz Android theme in v2 scope or explicitly later?

---

## 9. Decision log

| Date | Decision |
|---|---|
| 2026-07-18 | Pursue LB-competitive parity via platform + shell, not 1:1 app clones |
| 2026-07-18 | Primary UI direction = **Liquid Glass / iFruit OS** |
| 2026-07-18 | Use **GTA lore-friendly** app/brand names; original brands for crime apps |
| 2026-07-18 | Keep internal app IDs stable; display names via brand/locale config |
| 2026-07-18 | This roadmap doc created under `docs/` |

---

## 10. Idea backlog (unsorted)

- Browser-first Liquid Glass shell mock (lock + home + dock + sample list)
- Icon pack redraw for lore brands (Lifeinvader, Bleeter, Snapmatic, Fleeca, Weazel, Eyefind, SecuroServ, Bawsaq, Dynasty 8)
- Setup / first-boot iFruit wizard (name device, face ID joke, wallpaper)
- Carrier / signal / battery simulation tied to world or airplane mode
- Dynamic Island–style compact call / recording pill
- Wallpaper store with lore artist packs
- Companion tablet later (MDT) — out of scope until phone shell is solid
- Export surface cleanup (`Exports.MD` still legacy qb-phone oriented)
- Performance pass: virtualized chat/mail/pulse lists

---

## 11. How to use this doc

- Append new ideas to **Idea backlog** or the relevant section.
- Record locked choices in **Decision log** with a date.
- Move resolved open questions into the decision log.
- When implementation PRs land, link them under the matching phase.

---

*Built for the Z-Phone / Cosmo direction — premium RP phone, lore-first, open UI.*
