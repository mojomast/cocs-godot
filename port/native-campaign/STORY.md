# Quiet Relay story authority

`story.mjs` stages four optional proximity encounters per chapter on reviewed
critical-path positions. Mara (`claude`) and Ivo (`gemini`) are recurring friendly
maintenance operators: they wave and direct the player, repair the repeater/pump/
uplink/feeder, escort the crossing, and reunite after ECHO's transmission. Patch
(`patch`) appears near each chapter entrance and again near the Crown finale.
None is a `Match` actor: they cannot participate in damage, collision, hostile
targeting, guard clear conditions, or kill accounting.

Entity feet positions come from authored route points and are checked against the
same source floor and obstruction queries as player movement, including adjacent
terrain clearance. The server alone selects active chapter beats and publishes
`snapshot.campaign.story` version 1 per `port/campaign/STORY_EVENTS.md`.
Captions have stable IDs and only appear once on proximity; a short display and
cooldown prevent them from replacing one another each frame. The player can pet
Patch using a new Interact press within 2.6 horizontal / 1.4 vertical units and
the source's terrain/block visibility ray. A usable mandatory relay interaction
always has priority. Every accepted press advances Patch's `reactionSerial` and
the campaign-wide `pets` count; holding Interact does not repeat it, and a one
second reaction cooldown survives checkpoint retry. Patch recognizes the player
on the first pet in subsequent chapters based on campaign-wide pet history.

`campaignCheckpoint()` carries a server-local chapter story record on retry.
Continue carries it into the next chapter; restart removes only the current
chapter's record while retaining earlier chapters' pet count and beat history.
Neither story proximity nor coordinates are accepted from the wire. The final
Continue retains the completed match, so the final pet and reunion remain in the
terminal results snapshot.

Light checks: `node --test port/native-campaign/story.test.mjs
port/native-campaign/authority.test.mjs`. Full campaign simulation and visual
acceptance use the normal campaign integration gates when the shared engine slot
is available.
