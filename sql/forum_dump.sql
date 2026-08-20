
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `z_forum_categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `z_forum_categories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `slug` varchar(50) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `sort_order` tinyint(4) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

LOCK TABLES `z_forum_categories` WRITE;
/*!40000 ALTER TABLE `z_forum_categories` DISABLE KEYS */;
INSERT INTO `z_forum_categories` VALUES (1,'Suggestions','suggestions','Ideas and proposals for the server',5),(2,'Complaints','complaints','Complaints about other players or in-game situations',3),(3,'Bugs','bugs','Bugs and issues found in the game or in the UCP',4),(4,'Rules','rules','The server\'s official rules',1),(5,'Factions','factions','Official rules and internal conduct for every faction on the server',2);
/*!40000 ALTER TABLE `z_forum_categories` ENABLE KEYS */;
UNLOCK TABLES;
DROP TABLE IF EXISTS `z_forum_subcategories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `z_forum_subcategories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `category_id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `slug` varchar(50) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `sort_order` tinyint(4) NOT NULL DEFAULT 0,
  `admin_only_post` tinyint(1) NOT NULL DEFAULT 0,
  `require_login` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`),
  KEY `category_id` (`category_id`),
  CONSTRAINT `z_forum_subcategories_category_fk` FOREIGN KEY (`category_id`) REFERENCES `z_forum_categories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

LOCK TABLES `z_forum_subcategories` WRITE;
/*!40000 ALTER TABLE `z_forum_subcategories` DISABLE KEYS */;
INSERT INTO `z_forum_subcategories` VALUES (1,5,'Police Department','faction-police','Rules and conduct for the Police Department',1,1,1),(2,5,'Department of Motor Vehicles','faction-dmv','Rules and conduct for the Department of Motor Vehicles',2,1,1),(3,5,'SMURD','faction-smurd','Rules and conduct for SMURD (medical & fire response)',3,1,1),(4,5,'European Mafia','faction-euromafia','Rules and conduct for the European Mafia',4,1,1),(5,5,'American Mafia','faction-usmafia','Rules and conduct for the American Mafia',5,1,1),(6,5,'African Mafia','faction-africamafia','Rules and conduct for the African Mafia',6,1,1),(7,5,'Asian Mafia','faction-asiamafia','Rules and conduct for the Asian Mafia',7,1,1),(8,5,'News Reporters','faction-news','Rules and conduct for News Reporters',8,1,1);
/*!40000 ALTER TABLE `z_forum_subcategories` ENABLE KEYS */;
UNLOCK TABLES;
DROP TABLE IF EXISTS `z_forum_topics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `z_forum_topics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `subcategory_id` int(11) NOT NULL,
  `player_id` int(11) NOT NULL,
  `title` varchar(150) NOT NULL,
  `status` enum('open','in_progress','resolved','rejected') NOT NULL DEFAULT 'open',
  `is_pinned` tinyint(1) NOT NULL DEFAULT 0,
  `is_locked` tinyint(1) NOT NULL DEFAULT 0,
  `sort_order` tinyint(4) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `last_post_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `subcategory_id` (`subcategory_id`),
  KEY `last_post_at` (`last_post_at`),
  KEY `player_id` (`player_id`),
  CONSTRAINT `z_forum_topics_player_fk` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE,
  CONSTRAINT `z_forum_topics_subcategory_fk` FOREIGN KEY (`subcategory_id`) REFERENCES `z_forum_subcategories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

LOCK TABLES `z_forum_topics` WRITE;
/*!40000 ALTER TABLE `z_forum_topics` DISABLE KEYS */;
INSERT INTO `z_forum_topics` VALUES (1,1,1,'Regulation','resolved',1,1,0,'2026-08-17 17:17:32','2026-08-17 17:17:32'),(2,2,1,'Regulation','open',1,0,0,'2026-08-17 17:17:32','2026-08-17 17:17:32'),(3,3,1,'Regulation','open',1,0,0,'2026-08-17 17:17:32','2026-08-17 17:17:32'),(4,4,1,'Regulation','open',1,0,0,'2026-08-17 17:17:32','2026-08-17 17:17:32'),(5,5,1,'Regulation','open',1,0,0,'2026-08-17 17:17:32','2026-08-17 17:17:32'),(6,6,1,'Regulation','open',1,0,0,'2026-08-17 17:17:32','2026-08-17 17:17:32'),(7,7,1,'Regulation','open',1,0,0,'2026-08-17 17:17:32','2026-08-17 17:17:32'),(8,8,1,'Regulation','open',1,0,0,'2026-08-17 17:17:32','2026-08-17 17:17:32'),(9,1,1,'test topic','open',0,0,0,'2026-08-18 09:53:51','2026-08-18 09:53:51');
/*!40000 ALTER TABLE `z_forum_topics` ENABLE KEYS */;
UNLOCK TABLES;
DROP TABLE IF EXISTS `z_forum_posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `z_forum_posts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `topic_id` int(11) NOT NULL,
  `player_id` int(11) NOT NULL,
  `body` text NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `edited_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `topic_id` (`topic_id`),
  KEY `player_id` (`player_id`),
  CONSTRAINT `z_forum_posts_player_fk` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE,
  CONSTRAINT `z_forum_posts_topic_fk` FOREIGN KEY (`topic_id`) REFERENCES `z_forum_topics` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

LOCK TABLES `z_forum_posts` WRITE;
/*!40000 ALTER TABLE `z_forum_posts` DISABLE KEYS */;
INSERT INTO `z_forum_posts` VALUES (1,1,1,'POLICE DEPARTMENT - CODE OF CONDUCT\n\nThe badge is a responsibility, not a toy. Every officer represents the Department 24/7, on duty or off - act accordingly.\n\n1. Chain of Command\n- Rank 5 is your Chief. Their word on operational matters is final; disagreements go through them privately, never on duty channel.\n- New recruits (Rank 1-2) patrol with a training officer before being cleared for solo patrol.\n\n2. Use of Force\n- Escalate proportionally: verbal commands, then non-lethal (handcuffs/pursuit), then lethal only when your life or a civilian\'s is at genuine risk.\n- Never open fire on a suspect who is complying, unarmed, or already restrained.\n- Vehicle ramming/PIT is a last resort for dangerous pursuits, not a shortcut to end a chase you\'re bored of.\n\n3. Arrests & Detainment\n- Read the wanted level before deciding jail time - proportional sentencing, not maximum every time.\n- No arresting on suspicion alone. RP the stop: ask for ID, state the reason, give the player a chance to respond.\n- Turning yourself in at the Jail point reduces friction for everyone - encourage it over dragging out a losing chase.\n\n4. Equipment & Duty Vehicles\n- Marked cruisers, lightbars and department weapons are for on-duty use only. Taking them out for personal errands is a suspension-worthy offense.\n- Keep your radio chatter relevant - no dead air hogging, no OOC talk on the department channel.\n\n5. Corruption Policy\n- Bribery, selling information to mafias, or letting a suspect go for a cut is grounds for immediate termination and, in serious cases, an in-character IA investigation.\n- If you witness corruption, report it to your Chief or an admin - covering for a corrupt officer gets you punished too.\n\n6. Off-Duty Conduct\n- You\'re still expected to behave like law enforcement in spirit even off the clock - the badge doesn\'t disappear when you clock out. Don\'t commit crimes you\'d arrest a civilian for.\n\nThe Department exists to make the city feel alive, not to farm arrests. RP the stop, RP the chase, RP the paperwork - that\'s what makes it fun for everyone on the other end too.','2026-08-17 17:17:32',NULL),(2,2,1,'DEPARTMENT OF MOTOR VEHICLES - CODE OF CONDUCT\n\nThe DMV keeps the city\'s traffic legal and safe - your job is making sure every vehicle on the road is roadworthy and properly documented, not handing out favors.\n\n1. Mission\n- You oversee vehicle registration, plates, and road safety compliance: insurance, medical kit, fire extinguisher, and ITP (technical inspection).\n- You also tow illegally parked vehicles blocking traffic or private property, using a Towtruck and \"/tow\".\n- Civilians rely on you to enforce these standards consistently, not to wave things through.\n\n2. Vehicle Registration & Plates\n- Verify ownership before registering a vehicle or issuing plates through \"/v plate\". Don\'t register a vehicle you have reason to believe is stolen.\n- Keep records honest - don\'t backdate or falsify registration details as a favor to anyone, faction ally or not.\n\n3. Safety & Compliance Inspections\n- ITP (technical inspection) requires the vehicle to be in good condition (near-full health) at the designated inspection point - don\'t pass a vehicle that doesn\'t meet the standard.\n- Know the renewal windows: insurance and extinguisher/medkit documents expire on a set cycle, ITP lasts longer but still expires - remind civilians instead of assuming they know.\n- Spot-check vehicles when appropriate and flag missing or expired documents (insurance, extinguisher, medkit, ITP) rather than ignoring them.\n\n4. Illegal Parking & Towing\n- Tow vehicles genuinely blocking traffic, driveways, or business/house entrances - not just anything parked slightly off.\n- Pull the Towtruck within range (\"/tow\") and give the owner a reasonable chance to notice before hooking it, when that\'s realistic (e.g. they\'re nearby vs. long gone).\n- Towed vehicles should be recoverable, not punitive - don\'t use towing as a way to grief a player you have a personal issue with.\n\n5. Office Conduct\n- Keep the queue moving. If you\'re going AFK for a while, say so in local chat so people aren\'t left waiting.\n- Treat every civilian the same regardless of their faction, wealth, or admin level - favoritism undermines the whole point of having standards.\n\n6. Corruption Policy\n- Passing a vehicle that fails inspection, or registering a vehicle you know is stolen, is a bannable offense - the DMV\'s value depends entirely on its integrity.\n\n7. Ranks & Promotion\n- Rank 5 (your director) manages hiring, firing, and internal promotions based on reliability and professionalism, not favoritism.\n\nA boring office job, done well, is what keeps the city\'s traffic RP believable and its roads safe. Take pride in the paperwork.','2026-08-17 17:17:32','2026-08-17 18:53:38'),(3,3,1,'SMURD - CODE OF CONDUCT\n\nSMURD covers both emergency medicine and firefighting. When the map icon for a fire or a downed player shows up, you\'re the ones people are counting on.\n\n1. Mission\n- Revive injured players and treat disease (/curedisease) at the hospital.\n- Respond to fires with the firetruck and put them out before they spread or someone gets hurt.\n\n2. Response Priority\n- Life-threatening calls (injured/downed players, active fires) always come before administrative work.\n- Respond to EVERY call regardless of the victim\'s faction, RP history, or personal beef - SMURD does not pick sides.\n- If two calls come in at once, triage: whoever is in more immediate danger goes first.\n\n3. Equipment Discipline\n- Lightbars on SMURD Sultans are for active responses only - don\'t drive around with them flashing for no reason, it desensitizes people to real emergencies.\n- Keep the firetruck stocked and stationed sensibly so response time stays low.\n\n4. Unarmed Policy\n- SMURD is a non-combat faction. Don\'t carry weapons on duty and don\'t insert yourself into shootouts or turf wars - your job is to arrive after it\'s safe, not during.\n- If a scene isn\'t safe (active shooting), stage nearby and wait for Police rather than rushing in.\n\n5. Cooperation with Police & News\n- Coordinate with Police at crime-adjacent medical calls - let them secure the scene when needed.\n- News Reporters may show up to cover fires; don\'t obstruct them, but keep your focus on the emergency first.\n\n6. On-Duty Conduct\n- Stay professional and calm in chat even during chaotic multi-casualty scenes - panic in character is fine, panic breaking immersion isn\'t.\n\nYou\'re the reason this city doesn\'t feel lawless and cold. Every revive and every fire put out is someone\'s RP saved.','2026-08-17 17:17:32',NULL),(4,4,1,'EUROPEAN MAFIA - CODE OF CONDUCT\n\nOld-world discipline, new-world money. The European Mafia runs on hierarchy, patience and controlled aggression - not chaos.\n\n1. Identity & Hierarchy\n- Respect the chain of command. Rank 5 is your Don; orders flow down, loyalty flows up, and internal disputes are settled inside the family, not in public chat.\n- Recruitment is by invitation and vetting, not by adding whoever asks first.\n\n2. Turf & War Conduct\n- Only fight wars that are properly declared through the turf war system - no sneak attacks outside a war window.\n- Don\'t spawn-camp or contest a turf gangzone the moment it starts flashing red just to farm kills; fight for control, not for a scoreboard.\n- Losing a turf gracefully is part of the game - retaliate through the system, not through OOC harassment.\n\n3. Smuggling Operations\n- Weed runs (boat -> collection points -> hotel delivery) are a crew operation, up to 6 members. Don\'t abandon your crew mid-route or sabotage your own driver.\n- One successful run per day per faction - don\'t beg for extra runs or exploit timing bugs to bypass the cooldown.\n- Getting intercepted by Police is an accepted risk of the trade, not a reason to complain in ooc chat.\n\n4. Internal Discipline\n- The faction safe (cash, herbs) is family property - unauthorized withdrawals by low-ranking members is theft from your own, dealt with harshly in character.\n- Promotions are earned through reliability and loyalty over time, decided by your Don.\n\n5. Roleplay Standards\n- Play a criminal organization, not a griefer with a gun. No random drive-by killing of unrelated civilians, no metagaming information you only know OOC.\n- Business rivalries are settled through RP (turf, smuggling, negotiation) - not through repeated spawn-killing.\n\nDiscretion, discipline, and a long memory - that\'s what keeps a family running for years instead of weeks.','2026-08-17 17:17:32',NULL),(5,5,1,'AMERICAN MAFIA - CODE OF CONDUCT\n\nStreet-built and street-loyal. The American Mafia holds its ground through presence, reputation and crew loyalty.\n\n1. Identity & Hierarchy\n- Rank 5 is your Boss - final say on territory, recruitment, and disputes with other crews.\n- Loyalty to the crew comes first; snitching to Police or another mafia about internal business ends your membership on the spot, in character and out.\n\n2. Turf & War Conduct\n- Wars are fought through the turf system during active war windows only - no camping a gangzone 24/7 to prevent it from ever being contested.\n- A loss is a loss - come back stronger next time instead of escalating into harassment outside the game.\n\n3. Smuggling Operations\n- The weed run is a full-crew effort (up to 6) - boat to collection points to hotel delivery. Everyone pulls their weight, from driver to lookout.\n- One clean run per day - don\'t look for loopholes around the cooldown, and don\'t leave crew members behind to save your own cut.\n- Getting caught by Police mid-run is part of the risk of doing business - that\'s the game working as intended.\n\n4. Internal Discipline\n- The faction safe is crew money - unauthorized access is treated as betrayal, not a mistake.\n- Earn your rank through showing up, pulling runs, and holding turf - not through who\'s friends with the Boss.\n\n5. Roleplay Standards\n- Be a crew, not a killing spree. No random civilian drive-bys, no metagaming, no exploiting mechanics to duck a fair fight.\n- Settle beef with rival mafias through turf and business, not by ruining someone else\'s unrelated RP.\n\nRespect is earned on the street, not given for free - build the reputation, don\'t just claim it.','2026-08-17 17:17:32',NULL),(6,6,1,'AFRICAN MAFIA - CODE OF CONDUCT\n\nFamily first, territory always. The African Mafia is built on tight-knit loyalty and a fierce defense of what\'s theirs.\n\n1. Identity & Hierarchy\n- Rank 5 leads the family and makes the final call on territory, recruitment and conflicts.\n- New members are brought in by trust, not convenience - vouch for who you recruit.\n\n2. Turf & War Conduct\n- Fight for turf only through declared war windows in the turf system - no exploiting the gangzone timer to lock out a fair fight.\n- Defending your territory is your top priority during a war, but don\'t turn a loss into an OOC grudge - reset and come back stronger.\n\n3. Smuggling Operations\n- Weed runs are a family operation - up to 6 members, from the boat driver to the crew covering the collection points and the hotel drop-off.\n- One successful run per day - respect the cooldown, and never leave a family member stranded mid-route to save yourself.\n- If Police intercept the run, that\'s the risk of the business, not a reason for OOC complaints.\n\n4. Internal Discipline\n- The faction safe belongs to the whole family - taking from it without authorization is treated as a serious betrayal.\n- Rank is earned through loyalty, reliability, and contribution to runs and turf defense - not friendship with leadership.\n\n5. Roleplay Standards\n- Represent an organized family, not random violence - no drive-by killing of uninvolved civilians, no metagaming.\n- Handle disputes with rival mafias through turf and business RP, never by dragging in players who aren\'t part of it.\n\nA family stands strong because its members stand together - protect that, and the rest follows.','2026-08-17 17:17:32',NULL),(7,7,1,'ASIAN MAFIA - CODE OF CONDUCT\n\nQuiet, efficient, and always business-minded. The Asian Mafia wins through discretion and precision, not noise.\n\n1. Identity & Hierarchy\n- Rank 5 leads the organization and has final authority over territory, business and recruitment.\n- Discretion is the culture here - internal business stays internal, and members represent the organization calmly even under pressure.\n\n2. Turf & War Conduct\n- Contest turf strictly within declared war windows through the turf system - patience over impulsive fights you\'re not prepared for.\n- A lost turf is a business setback, not a reason to escalate into OOC conflict with the winning faction.\n\n3. Smuggling Operations\n- Weed runs are executed as a precise team operation (up to 6) - boat, collection points, hotel delivery. Sloppy execution costs the whole crew the payout.\n- One run per day, no exceptions and no bypassing the cooldown through exploits.\n- A run intercepted by Police is a calculated risk of the operation, not grounds for complaint.\n\n4. Internal Discipline\n- The faction safe is organizational property - unauthorized access is a serious breach of trust and handled internally, decisively.\n- Promotion follows demonstrated reliability and results, not seniority alone.\n\n5. Roleplay Standards\n- Operate like a business, not a mob of chaos - no random violence against uninvolved civilians, no metagaming.\n- Resolve conflicts with other mafias through turf and business channels, keeping uninvolved players out of it entirely.\n\nEfficiency is the brand - every member\'s conduct reflects on the whole organization.','2026-08-17 17:17:32',NULL),(8,8,1,'NEWS REPORTERS - CODE OF CONDUCT\n\nYou\'re the city\'s eyes and ears - what you publish shapes how everyone else sees what\'s happening. Report it straight.\n\n1. Mission\n- Write newspaper stories about city events and, at Rank 3+, host live Q&A sessions with the community.\n- Cover fires, crime scenes and major incidents in the field with your camera, working around (not in the way of) Police and SMURD.\n\n2. Field Reporting\n- Get the story without interfering with an active operation - stay back from a live shootout or an unsecured fire until it\'s safe.\n- A press badge doesn\'t grant immunity from danger or special treatment from other factions - report responsibly and read the scene.\n\n3. Editorial Standards\n- No fabricated stories or twisting events for drama - if you didn\'t witness or verify it, don\'t print it as fact.\n- Respect victims\' privacy in sensitive stories (medical emergencies, deaths) - report the event, not gratuitous details.\n- Bias is inevitable in tone, but don\'t knowingly publish misinformation to favor a faction you\'re close to.\n\n4. Live Q&A Etiquette\n- Only one live Q&A session can run server-wide at a time - check before starting one, and don\'t spam invites to force your way in.\n- Keep sessions on-topic and respectful; you\'re moderating a public conversation, so shut down harassment in your own session.\n\n5. Ranks & Progression\n- Rank 5 oversees editorial standards and who gets promoted to host live sessions - promotion is based on quality of coverage, not activity alone.\n\nA newspaper only matters if people trust it. Every story you publish either builds that trust or spends it.','2026-08-17 17:17:32',NULL),(9,9,1,'this is a test topic','2026-08-18 09:53:51',NULL);
/*!40000 ALTER TABLE `z_forum_posts` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

