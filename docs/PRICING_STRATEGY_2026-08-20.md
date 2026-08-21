# FoxyCo pricing strategy — build 55

**Reviewed:** 20 August 2026  
**Scope:** product and pricing analysis only; no Play Console or billing changes

## Recommendation

### Recommended model

Lifetime

### Recommended Canada price

CA$24.99

### Recommended US price

US$17.99

### Recommended trial

7 days

### Confidence

Medium

### Why

Build 55 is more than a simple rate calculator. It detects live Uber, Lyft and
Hopp offers, applies driver-set distance or hourly rules, adds Minimum Offer and
Pickup Guard context, shows a configurable overlay and Voice Verdict, and keeps
local History with scoring snapshots, editable outcomes, sessions, earnings
estimates, hourly/app analysis and CSV export. The current prices are credible
for that useful, focused bundle while remaining far below a year of a typical
driver-utility subscription. Confidence is not High because real trial-to-paid,
refund and retention data do not exist yet, and parser reliability still needs
current device validation.

## Current customer value

Counted as current value:

- real-time offer reading and GOOD / OK / BAD scoring;
- configurable distance or hourly thresholds;
- Minimum Offer, Pickup Guard, floating bubble, verdict pill and Voice Verdict;
- Uber, Lyft and Hopp parser architecture;
- Live Preview, local History and historical scoring snapshots;
- editable outcomes, sessions, estimated completed-offer earnings and session
  hourly rate;
- History filters, By Hour / By App analysis and CSV export;
- Garage, reminders, appearance and overlay controls;
- local-first offer data, a 7-day trial and one lifetime entitlement.

Not counted as current value:

- future driver platforms;
- temporary fixed-date tester access;
- any guaranteed earnings improvement;
- server-backed cross-device offer history or automatic tax/mileage tracking.

## Price assessment

### Canada — CA$24.99 lifetime

**Appropriate.** CA$19.99 would be easier for casual drivers but would leave
little room to price the ongoing parser maintenance. CA$29.99 is defensible for
frequent multi-app drivers only after current-platform reliability is proven at
launch scale. CA$24.99 is the balanced psychological point: below CA$25 in
buyer perception, substantial enough to signal a maintained utility, and still
a one-time decision.

### United States — US$17.99 lifetime

**Appropriate.** US$14.99 improves impulse conversion but risks undervaluing the
live overlay and analysis bundle. US$19.99 is cleaner and likely sustainable,
but creates more resistance before FoxyCo has public reviews and broad device
evidence. US$17.99 is an unusual but acceptable middle price and gives the US
storefront a clear sub-US$20 decision.

The Canada/US relationship is sensible. It is close enough to currency reality
without pretending regional pricing is a live exchange-rate conversion, and
both prices land below a strong local psychological boundary. Do not change one
merely to make their converted values identical.

## Trial length

- **3 days:** too short. Part-time drivers may not work at all, and even active
  drivers may see too few useful offer conditions.
- **7 days:** best fit. It normally includes weekdays and a weekend, supports
  several real sessions, and retains a clear purchase decision point.
- **14 days:** better for very casual drivers, but delays the decision and gives
  away more use than this focused utility needs to demonstrate its value.

Keep 7 days. Explain that the clock starts only when the driver chooses Start
trial; do not imply that installation silently starts it.

## Lifetime versus subscription

Keep lifetime for launch. It matches cost-sensitive drivers, avoids subscription
fatigue, is easy to explain and strengthens trust: pay once, no renewal. A
monthly subscription would fund ongoing parser maintenance better but adds the
largest possible objection to a utility whose reliability can be disrupted by
third-party app changes. Annual-only is less irritating than monthly but still
creates renewal anxiety. A hybrid model adds entitlement and messaging
complexity without a second clearly distinct product today.

Revisit the model only if recurring costs become material—for example, a
server-backed service, continuous market data, or support/maintenance costs that
lifetime sales cannot sustain. Do not add a subscription solely because other
apps use one.

## Value and payback wording

“One avoided BAD offer can help pay for FoxyCo” is possible for some drivers,
but it still sounds like an earnings claim and depends on what the driver would
otherwise accept. Do not use it as the main promise.

Safer wording:

> See weak offers before you decide.
>
> Compare each offer using your own distance or hourly rules.

Drivers can do their own payback calculation without FoxyCo promising that an
offer would have lost a particular amount.

## Competitive positioning

FoxyCo sits between a simple mileage/earnings tracker and an automation tool. It
provides live offer analysis but remains read-only: the driver makes every
decision. That narrower risk profile and lifetime model are meaningful
differences from tools that link accounts or accept/decline offers.

Current official examples show why the one-time price is credible rather than
high. Gridwise offers free tracking and lists Plus at US$14.99/month or
US$107.99/year, with a 14-day subscription trial. Mystro states that it requires
an active subscription and can automatically accept or reject matching offers,
but directs users to the app for its current price. These are product-shape
comparisons, not feature-for-feature price matches: FoxyCo does not provide
Gridwise's linked-account mileage/tax system or Mystro's automation.

Sources: [Gridwise pricing](https://help.gridwise.io/hc/en-us/articles/360061691773-How-Much-Does-Gridwise-Cost),
[Gridwise Plus](https://gridwise.io/plus),
[Mystro getting started](https://mystrodriver.com/blog/getting-started-with-mystro).

## Price sensitivity

| Driver | Likely reaction |
|---|---|
| Casual | May resist CA$24.99 / US$17.99 unless the trial overlaps a real shift |
| Part-time | Reasonable if several offers demonstrate the rules and overlay |
| Frequent/full-time | Strongest value perception; reliability matters more than a few dollars |
| One platform | Still useful, but multi-platform architecture adds less perceived value |
| Several platforms | Best fit for the current price and History comparison features |

One paid tier remains preferable. There is no compelling product boundary for
multiple lifetime tiers.

## Regional pricing

Set Canada and the US manually. Use a Google Play price template as the starting
point for other countries, then review priority markets for purchasing power,
tax-inclusive display and familiar price endings. Avoid blindly accepting every
currency conversion, but also avoid a large manual matrix before international
demand exists.

## Trial-to-purchase messaging audit

The product now clearly says 7 days, lifetime access, Google Play purchase and
no subscription in onboarding and the paywall. Restore purchase and Redeem code
are available under **Settings → Profile → Access**. Remaining device gates are
the real localized Play price, purchase, restore, refund/revoke and redeemed-code
flows.

Closed-track membership currently grants no special access. License testing is
for trusted billing QA and lifetime promo codes permanently unlock the product.
A fixed-date tester entitlement remains future work and must not be described as
available in build 55.

## Decision summary

1. **Strongest argument for current pricing:** a complete live offer-analysis,
   overlay and local-history bundle costs less once than many comparable tools
   charge in a few months.
2. **Strongest argument against it:** parser reliability and public support
   quality are not yet proven broadly enough to make every casual driver
   comfortable paying near CA$25.
3. **Biggest risk:** a supported driver app changes its offer screen soon after
   purchase, making a lifetime buyer feel the core value disappeared.
4. **Biggest opportunity:** the no-subscription lifetime message is unusually
   simple in a subscription-heavy driver-utility market.
5. **Current position:** fairly priced; slightly underpriced for frequent
   multi-app drivers, slightly high for very casual single-app drivers.
6. **Before launch:** keep prices stable. Collect conversion, refund and support
   data before changing them.
7. **Play wording:** “7 days free. Then one payment for lifetime access. No
   subscription.” Pair it with “See weak offers before you decide.”
8. **Future price-rise trigger:** verified support for more high-demand
   platforms, consistently strong real-device parsing, materially deeper
   analysis, or sustained support costs. At that point CA$29.99 / US$19.99 is a
   reasonable next test for new buyers; existing owners keep lifetime access.
