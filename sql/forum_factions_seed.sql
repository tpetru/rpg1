-- "Factions" category: one subcategory per in-game faction, each pre-seeded with a pinned
-- "Regulation" topic containing that faction's rules. Author = highest-ranking admin account.
-- Run AFTER forum_migration.sql. Safe to run once (re-running duplicates the rows).

INSERT INTO `z_forum_categories` (`name`, `slug`, `description`, `sort_order`) VALUES
('Factions', 'factions', 'Official rules and internal conduct for every faction on the server', 5);

INSERT INTO `z_forum_subcategories` (`category_id`, `name`, `slug`, `description`, `sort_order`, `admin_only_post`) VALUES
((SELECT id FROM z_forum_categories WHERE slug = 'factions'), 'Police Department',              'faction-police',  'Rules and conduct for the Police Department',              1, 1),
((SELECT id FROM z_forum_categories WHERE slug = 'factions'), 'Department of Motor Vehicles',    'faction-dmv',     'Rules and conduct for the Department of Motor Vehicles',    2, 1),
((SELECT id FROM z_forum_categories WHERE slug = 'factions'), 'SMURD',                           'faction-smurd',   'Rules and conduct for SMURD (medical & fire response)',     3, 1),
((SELECT id FROM z_forum_categories WHERE slug = 'factions'), 'European Mafia',                  'faction-euromafia', 'Rules and conduct for the European Mafia',                4, 1),
((SELECT id FROM z_forum_categories WHERE slug = 'factions'), 'American Mafia',                  'faction-usmafia',   'Rules and conduct for the American Mafia',                5, 1),
((SELECT id FROM z_forum_categories WHERE slug = 'factions'), 'African Mafia',                   'faction-africamafia', 'Rules and conduct for the African Mafia',               6, 1),
((SELECT id FROM z_forum_categories WHERE slug = 'factions'), 'Asian Mafia',                     'faction-asiamafia',  'Rules and conduct for the Asian Mafia',                  7, 1),
((SELECT id FROM z_forum_categories WHERE slug = 'factions'), 'News Reporters',                  'faction-news',    'Rules and conduct for News Reporters',                      8, 1);

-- ============================================================
--  Police Department
-- ============================================================
INSERT INTO `z_forum_topics` (`subcategory_id`, `player_id`, `title`, `is_pinned`) VALUES
((SELECT id FROM z_forum_subcategories WHERE slug = 'faction-police'), (SELECT id FROM players WHERE username = 'Punctulet'), 'Regulation', 1);

INSERT INTO `z_forum_posts` (`topic_id`, `player_id`, `body`) VALUES
((SELECT id FROM z_forum_topics WHERE title = 'Regulation' AND subcategory_id = (SELECT id FROM z_forum_subcategories WHERE slug = 'faction-police')),
 (SELECT id FROM players WHERE username = 'Punctulet'),
'POLICE DEPARTMENT - CODE OF CONDUCT

The badge is a responsibility, not a toy. Every officer represents the Department 24/7, on duty or off - act accordingly.

1. Chain of Command
- Rank 5 is your Chief. Their word on operational matters is final; disagreements go through them privately, never on duty channel.
- New recruits (Rank 1-2) patrol with a training officer before being cleared for solo patrol.

2. Use of Force
- Escalate proportionally: verbal commands, then non-lethal (handcuffs/pursuit), then lethal only when your life or a civilian''s is at genuine risk.
- Never open fire on a suspect who is complying, unarmed, or already restrained.
- Vehicle ramming/PIT is a last resort for dangerous pursuits, not a shortcut to end a chase you''re bored of.

3. Arrests & Detainment
- Read the wanted level before deciding jail time - proportional sentencing, not maximum every time.
- No arresting on suspicion alone. RP the stop: ask for ID, state the reason, give the player a chance to respond.
- Turning yourself in at the Jail point reduces friction for everyone - encourage it over dragging out a losing chase.

4. Equipment & Duty Vehicles
- Marked cruisers, lightbars and department weapons are for on-duty use only. Taking them out for personal errands is a suspension-worthy offense.
- Keep your radio chatter relevant - no dead air hogging, no OOC talk on the department channel.

5. Corruption Policy
- Bribery, selling information to mafias, or letting a suspect go for a cut is grounds for immediate termination and, in serious cases, an in-character IA investigation.
- If you witness corruption, report it to your Chief or an admin - covering for a corrupt officer gets you punished too.

6. Off-Duty Conduct
- You''re still expected to behave like law enforcement in spirit even off the clock - the badge doesn''t disappear when you clock out. Don''t commit crimes you''d arrest a civilian for.

The Department exists to make the city feel alive, not to farm arrests. RP the stop, RP the chase, RP the paperwork - that''s what makes it fun for everyone on the other end too.');

-- ============================================================
--  Department of Motor Vehicles
-- ============================================================
INSERT INTO `z_forum_topics` (`subcategory_id`, `player_id`, `title`, `is_pinned`) VALUES
((SELECT id FROM z_forum_subcategories WHERE slug = 'faction-dmv'), (SELECT id FROM players WHERE username = 'Punctulet'), 'Regulation', 1);

INSERT INTO `z_forum_posts` (`topic_id`, `player_id`, `body`) VALUES
((SELECT id FROM z_forum_topics WHERE title = 'Regulation' AND subcategory_id = (SELECT id FROM z_forum_subcategories WHERE slug = 'faction-dmv')),
 (SELECT id FROM players WHERE username = 'Punctulet'),
'DEPARTMENT OF MOTOR VEHICLES - CODE OF CONDUCT

The DMV keeps the city''s traffic legal and safe - your job is making sure every vehicle on the road is roadworthy and properly documented, not handing out favors.

1. Mission
- You oversee vehicle registration, plates, and road safety compliance: insurance, medical kit, fire extinguisher, and ITP (technical inspection).
- You also tow illegally parked vehicles blocking traffic or private property, using a Towtruck and "/tow".
- Civilians rely on you to enforce these standards consistently, not to wave things through.

2. Vehicle Registration & Plates
- Verify ownership before registering a vehicle or issuing plates through "/v plate". Don''t register a vehicle you have reason to believe is stolen.
- Keep records honest - don''t backdate or falsify registration details as a favor to anyone, faction ally or not.

3. Safety & Compliance Inspections
- ITP (technical inspection) requires the vehicle to be in good condition (near-full health) at the designated inspection point - don''t pass a vehicle that doesn''t meet the standard.
- Know the renewal windows: insurance and extinguisher/medkit documents expire on a set cycle, ITP lasts longer but still expires - remind civilians instead of assuming they know.
- Spot-check vehicles when appropriate and flag missing or expired documents (insurance, extinguisher, medkit, ITP) rather than ignoring them.

4. Illegal Parking & Towing
- Tow vehicles genuinely blocking traffic, driveways, or business/house entrances - not just anything parked slightly off.
- Pull the Towtruck within range ("/tow") and give the owner a reasonable chance to notice before hooking it, when that''s realistic (e.g. they''re nearby vs. long gone).
- Towed vehicles should be recoverable, not punitive - don''t use towing as a way to grief a player you have a personal issue with.

5. Office Conduct
- Keep the queue moving. If you''re going AFK for a while, say so in local chat so people aren''t left waiting.
- Treat every civilian the same regardless of their faction, wealth, or admin level - favoritism undermines the whole point of having standards.

6. Corruption Policy
- Passing a vehicle that fails inspection, or registering a vehicle you know is stolen, is a bannable offense - the DMV''s value depends entirely on its integrity.

7. Ranks & Promotion
- Rank 5 (your director) manages hiring, firing, and internal promotions based on reliability and professionalism, not favoritism.

A boring office job, done well, is what keeps the city''s traffic RP believable and its roads safe. Take pride in the paperwork.');

-- ============================================================
--  SMURD
-- ============================================================
INSERT INTO `z_forum_topics` (`subcategory_id`, `player_id`, `title`, `is_pinned`) VALUES
((SELECT id FROM z_forum_subcategories WHERE slug = 'faction-smurd'), (SELECT id FROM players WHERE username = 'Punctulet'), 'Regulation', 1);

INSERT INTO `z_forum_posts` (`topic_id`, `player_id`, `body`) VALUES
((SELECT id FROM z_forum_topics WHERE title = 'Regulation' AND subcategory_id = (SELECT id FROM z_forum_subcategories WHERE slug = 'faction-smurd')),
 (SELECT id FROM players WHERE username = 'Punctulet'),
'SMURD - CODE OF CONDUCT

SMURD covers both emergency medicine and firefighting. When the map icon for a fire or a downed player shows up, you''re the ones people are counting on.

1. Mission
- Revive injured players and treat disease (/curedisease) at the hospital.
- Respond to fires with the firetruck and put them out before they spread or someone gets hurt.

2. Response Priority
- Life-threatening calls (injured/downed players, active fires) always come before administrative work.
- Respond to EVERY call regardless of the victim''s faction, RP history, or personal beef - SMURD does not pick sides.
- If two calls come in at once, triage: whoever is in more immediate danger goes first.

3. Equipment Discipline
- Lightbars on SMURD Sultans are for active responses only - don''t drive around with them flashing for no reason, it desensitizes people to real emergencies.
- Keep the firetruck stocked and stationed sensibly so response time stays low.

4. Unarmed Policy
- SMURD is a non-combat faction. Don''t carry weapons on duty and don''t insert yourself into shootouts or turf wars - your job is to arrive after it''s safe, not during.
- If a scene isn''t safe (active shooting), stage nearby and wait for Police rather than rushing in.

5. Cooperation with Police & News
- Coordinate with Police at crime-adjacent medical calls - let them secure the scene when needed.
- News Reporters may show up to cover fires; don''t obstruct them, but keep your focus on the emergency first.

6. On-Duty Conduct
- Stay professional and calm in chat even during chaotic multi-casualty scenes - panic in character is fine, panic breaking immersion isn''t.

You''re the reason this city doesn''t feel lawless and cold. Every revive and every fire put out is someone''s RP saved.');

-- ============================================================
--  European Mafia
-- ============================================================
INSERT INTO `z_forum_topics` (`subcategory_id`, `player_id`, `title`, `is_pinned`) VALUES
((SELECT id FROM z_forum_subcategories WHERE slug = 'faction-euromafia'), (SELECT id FROM players WHERE username = 'Punctulet'), 'Regulation', 1);

INSERT INTO `z_forum_posts` (`topic_id`, `player_id`, `body`) VALUES
((SELECT id FROM z_forum_topics WHERE title = 'Regulation' AND subcategory_id = (SELECT id FROM z_forum_subcategories WHERE slug = 'faction-euromafia')),
 (SELECT id FROM players WHERE username = 'Punctulet'),
'EUROPEAN MAFIA - CODE OF CONDUCT

Old-world discipline, new-world money. The European Mafia runs on hierarchy, patience and controlled aggression - not chaos.

1. Identity & Hierarchy
- Respect the chain of command. Rank 5 is your Don; orders flow down, loyalty flows up, and internal disputes are settled inside the family, not in public chat.
- Recruitment is by invitation and vetting, not by adding whoever asks first.

2. Turf & War Conduct
- Only fight wars that are properly declared through the turf war system - no sneak attacks outside a war window.
- Don''t spawn-camp or contest a turf gangzone the moment it starts flashing red just to farm kills; fight for control, not for a scoreboard.
- Losing a turf gracefully is part of the game - retaliate through the system, not through OOC harassment.

3. Smuggling Operations
- Weed runs (boat -> collection points -> hotel delivery) are a crew operation, up to 6 members. Don''t abandon your crew mid-route or sabotage your own driver.
- One successful run per day per faction - don''t beg for extra runs or exploit timing bugs to bypass the cooldown.
- Getting intercepted by Police is an accepted risk of the trade, not a reason to complain in ooc chat.

4. Internal Discipline
- The faction safe (cash, herbs) is family property - unauthorized withdrawals by low-ranking members is theft from your own, dealt with harshly in character.
- Promotions are earned through reliability and loyalty over time, decided by your Don.

5. Roleplay Standards
- Play a criminal organization, not a griefer with a gun. No random drive-by killing of unrelated civilians, no metagaming information you only know OOC.
- Business rivalries are settled through RP (turf, smuggling, negotiation) - not through repeated spawn-killing.

Discretion, discipline, and a long memory - that''s what keeps a family running for years instead of weeks.');

-- ============================================================
--  American Mafia
-- ============================================================
INSERT INTO `z_forum_topics` (`subcategory_id`, `player_id`, `title`, `is_pinned`) VALUES
((SELECT id FROM z_forum_subcategories WHERE slug = 'faction-usmafia'), (SELECT id FROM players WHERE username = 'Punctulet'), 'Regulation', 1);

INSERT INTO `z_forum_posts` (`topic_id`, `player_id`, `body`) VALUES
((SELECT id FROM z_forum_topics WHERE title = 'Regulation' AND subcategory_id = (SELECT id FROM z_forum_subcategories WHERE slug = 'faction-usmafia')),
 (SELECT id FROM players WHERE username = 'Punctulet'),
'AMERICAN MAFIA - CODE OF CONDUCT

Street-built and street-loyal. The American Mafia holds its ground through presence, reputation and crew loyalty.

1. Identity & Hierarchy
- Rank 5 is your Boss - final say on territory, recruitment, and disputes with other crews.
- Loyalty to the crew comes first; snitching to Police or another mafia about internal business ends your membership on the spot, in character and out.

2. Turf & War Conduct
- Wars are fought through the turf system during active war windows only - no camping a gangzone 24/7 to prevent it from ever being contested.
- A loss is a loss - come back stronger next time instead of escalating into harassment outside the game.

3. Smuggling Operations
- The weed run is a full-crew effort (up to 6) - boat to collection points to hotel delivery. Everyone pulls their weight, from driver to lookout.
- One clean run per day - don''t look for loopholes around the cooldown, and don''t leave crew members behind to save your own cut.
- Getting caught by Police mid-run is part of the risk of doing business - that''s the game working as intended.

4. Internal Discipline
- The faction safe is crew money - unauthorized access is treated as betrayal, not a mistake.
- Earn your rank through showing up, pulling runs, and holding turf - not through who''s friends with the Boss.

5. Roleplay Standards
- Be a crew, not a killing spree. No random civilian drive-bys, no metagaming, no exploiting mechanics to duck a fair fight.
- Settle beef with rival mafias through turf and business, not by ruining someone else''s unrelated RP.

Respect is earned on the street, not given for free - build the reputation, don''t just claim it.');

-- ============================================================
--  African Mafia
-- ============================================================
INSERT INTO `z_forum_topics` (`subcategory_id`, `player_id`, `title`, `is_pinned`) VALUES
((SELECT id FROM z_forum_subcategories WHERE slug = 'faction-africamafia'), (SELECT id FROM players WHERE username = 'Punctulet'), 'Regulation', 1);

INSERT INTO `z_forum_posts` (`topic_id`, `player_id`, `body`) VALUES
((SELECT id FROM z_forum_topics WHERE title = 'Regulation' AND subcategory_id = (SELECT id FROM z_forum_subcategories WHERE slug = 'faction-africamafia')),
 (SELECT id FROM players WHERE username = 'Punctulet'),
'AFRICAN MAFIA - CODE OF CONDUCT

Family first, territory always. The African Mafia is built on tight-knit loyalty and a fierce defense of what''s theirs.

1. Identity & Hierarchy
- Rank 5 leads the family and makes the final call on territory, recruitment and conflicts.
- New members are brought in by trust, not convenience - vouch for who you recruit.

2. Turf & War Conduct
- Fight for turf only through declared war windows in the turf system - no exploiting the gangzone timer to lock out a fair fight.
- Defending your territory is your top priority during a war, but don''t turn a loss into an OOC grudge - reset and come back stronger.

3. Smuggling Operations
- Weed runs are a family operation - up to 6 members, from the boat driver to the crew covering the collection points and the hotel drop-off.
- One successful run per day - respect the cooldown, and never leave a family member stranded mid-route to save yourself.
- If Police intercept the run, that''s the risk of the business, not a reason for OOC complaints.

4. Internal Discipline
- The faction safe belongs to the whole family - taking from it without authorization is treated as a serious betrayal.
- Rank is earned through loyalty, reliability, and contribution to runs and turf defense - not friendship with leadership.

5. Roleplay Standards
- Represent an organized family, not random violence - no drive-by killing of uninvolved civilians, no metagaming.
- Handle disputes with rival mafias through turf and business RP, never by dragging in players who aren''t part of it.

A family stands strong because its members stand together - protect that, and the rest follows.');

-- ============================================================
--  Asian Mafia
-- ============================================================
INSERT INTO `z_forum_topics` (`subcategory_id`, `player_id`, `title`, `is_pinned`) VALUES
((SELECT id FROM z_forum_subcategories WHERE slug = 'faction-asiamafia'), (SELECT id FROM players WHERE username = 'Punctulet'), 'Regulation', 1);

INSERT INTO `z_forum_posts` (`topic_id`, `player_id`, `body`) VALUES
((SELECT id FROM z_forum_topics WHERE title = 'Regulation' AND subcategory_id = (SELECT id FROM z_forum_subcategories WHERE slug = 'faction-asiamafia')),
 (SELECT id FROM players WHERE username = 'Punctulet'),
'ASIAN MAFIA - CODE OF CONDUCT

Quiet, efficient, and always business-minded. The Asian Mafia wins through discretion and precision, not noise.

1. Identity & Hierarchy
- Rank 5 leads the organization and has final authority over territory, business and recruitment.
- Discretion is the culture here - internal business stays internal, and members represent the organization calmly even under pressure.

2. Turf & War Conduct
- Contest turf strictly within declared war windows through the turf system - patience over impulsive fights you''re not prepared for.
- A lost turf is a business setback, not a reason to escalate into OOC conflict with the winning faction.

3. Smuggling Operations
- Weed runs are executed as a precise team operation (up to 6) - boat, collection points, hotel delivery. Sloppy execution costs the whole crew the payout.
- One run per day, no exceptions and no bypassing the cooldown through exploits.
- A run intercepted by Police is a calculated risk of the operation, not grounds for complaint.

4. Internal Discipline
- The faction safe is organizational property - unauthorized access is a serious breach of trust and handled internally, decisively.
- Promotion follows demonstrated reliability and results, not seniority alone.

5. Roleplay Standards
- Operate like a business, not a mob of chaos - no random violence against uninvolved civilians, no metagaming.
- Resolve conflicts with other mafias through turf and business channels, keeping uninvolved players out of it entirely.

Efficiency is the brand - every member''s conduct reflects on the whole organization.');

-- ============================================================
--  News Reporters
-- ============================================================
INSERT INTO `z_forum_topics` (`subcategory_id`, `player_id`, `title`, `is_pinned`) VALUES
((SELECT id FROM z_forum_subcategories WHERE slug = 'faction-news'), (SELECT id FROM players WHERE username = 'Punctulet'), 'Regulation', 1);

INSERT INTO `z_forum_posts` (`topic_id`, `player_id`, `body`) VALUES
((SELECT id FROM z_forum_topics WHERE title = 'Regulation' AND subcategory_id = (SELECT id FROM z_forum_subcategories WHERE slug = 'faction-news')),
 (SELECT id FROM players WHERE username = 'Punctulet'),
'NEWS REPORTERS - CODE OF CONDUCT

You''re the city''s eyes and ears - what you publish shapes how everyone else sees what''s happening. Report it straight.

1. Mission
- Write newspaper stories about city events and, at Rank 3+, host live Q&A sessions with the community.
- Cover fires, crime scenes and major incidents in the field with your camera, working around (not in the way of) Police and SMURD.

2. Field Reporting
- Get the story without interfering with an active operation - stay back from a live shootout or an unsecured fire until it''s safe.
- A press badge doesn''t grant immunity from danger or special treatment from other factions - report responsibly and read the scene.

3. Editorial Standards
- No fabricated stories or twisting events for drama - if you didn''t witness or verify it, don''t print it as fact.
- Respect victims'' privacy in sensitive stories (medical emergencies, deaths) - report the event, not gratuitous details.
- Bias is inevitable in tone, but don''t knowingly publish misinformation to favor a faction you''re close to.

4. Live Q&A Etiquette
- Only one live Q&A session can run server-wide at a time - check before starting one, and don''t spam invites to force your way in.
- Keep sessions on-topic and respectful; you''re moderating a public conversation, so shut down harassment in your own session.

5. Ranks & Progression
- Rank 5 oversees editorial standards and who gets promoted to host live sessions - promotion is based on quality of coverage, not activity alone.

A newspaper only matters if people trust it. Every story you publish either builds that trust or spends it.');
