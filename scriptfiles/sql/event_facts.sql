-- Curiozitati despre sarbatori romanesti si europene, spuse de personajele inactive
-- ale evenimentului (/holiday npc ... idle). Tabelul e creat de gamemode (DB_CreateTables);
-- fisierul asta doar il populeaza.
--
-- Rularea (din radacina serverului):
--   "C:\xampp\mysql\bin\mysql.exe" -u root rpg1 < scriptfiles/sql/event_facts.sql
--
-- Cheia unica e `holiday`, deci fisierul se poate rula de cate ori vrei: rularile urmatoare
-- actualizeaza textele in loc sa adauge duplicate.
--
-- Limita: 160 caractere per text. Mesajul se trimite cu SendClientMessage, care taie la 144,
-- iar in joc textul e incadrat de ghilimele - tine-le sub ~135 de caractere.
-- Fara diacritice: clientul SA-MP nu le afiseaza corect.

CREATE TABLE IF NOT EXISTS `event_facts` (
  `id`      INT AUTO_INCREMENT PRIMARY KEY,
  `holiday` VARCHAR(48)  NOT NULL DEFAULT '',
  `country` VARCHAR(32)  NOT NULL DEFAULT '',
  `fact_en` VARCHAR(160) NOT NULL DEFAULT '',
  `fact_ro` VARCHAR(160) NOT NULL DEFAULT '',
  `enabled` TINYINT(1)   NOT NULL DEFAULT 1,
  UNIQUE KEY `uq_event_fact` (`holiday`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `event_facts` (`holiday`,`country`,`fact_en`,`fact_ro`) VALUES

-- ---------- Romania (15) ----------
('Dragobete','Romania',
 'The Romanian day of love, on 24 February. Girls used to wash their face with snow water, believing it kept them beautiful all year.',
 'Ziua indragostitilor la romani, pe 24 februarie. Fetele se spalau pe fata cu apa din zapada, crezand ca asa raman frumoase tot anul.'),

('Martisor','Romania',
 'On 1 March you give a red and white string charm for luck. UNESCO listed the custom in 2017, shared with Bulgaria, Moldova and North Macedonia.',
 'Pe 1 martie daruiesti un snur alb-rosu, de noroc. UNESCO a inscris obiceiul in 2017, impreuna cu Bulgaria, Moldova si Macedonia de Nord.'),

('Boboteaza','Romania',
 'On 6 January a priest throws a cross into icy water and men dive after it. Whoever brings it back is said to have luck all year.',
 'Pe 6 ianuarie preotul arunca crucea in apa inghetata si barbatii se arunca dupa ea. Cine o aduce inapoi se zice ca are noroc tot anul.'),

('Sfantul Andrei','Romania',
 'On the night of 29 November garlic is hung on doors and windows. Folklore says it keeps the strigoi, the restless dead, outside.',
 'In noaptea de 29 noiembrie se pune usturoi la usi si la ferestre. Se zice ca tine strigoii afara.'),

('Ziua Nationala','Romania',
 'On 1 December Romania marks the 1918 Great Union at Alba Iulia. The main parade passes under the Arcul de Triumf in Bucharest.',
 'Pe 1 decembrie se sarbatoreste Marea Unire de la Alba Iulia, din 1918. Parada principala trece pe sub Arcul de Triumf, in Bucuresti.'),

('Sanziene','Romania',
 'On 24 June girls wear wreaths of yellow sanziene flowers, then throw them onto the roof. Where the wreath sticks, the fortune is good.',
 'Pe 24 iunie fetele poarta cununi de sanziene galbene, apoi le arunca pe casa. Daca se prinde cununa pe acoperis, e semn bun.'),

('Ignatul','Romania',
 'On 20 December the household pig is slaughtered for Christmas. The whole village used to help, and the day ended with pomana porcului.',
 'Pe 20 decembrie se taie porcul pentru Craciun. Se ajuta tot satul, iar ziua se incheia cu pomana porcului.'),

('Sfantul Nicolae','Romania',
 'On the night of 5 December children leave their boots by the door. Good ones find sweets, the naughty ones a nuielusa - a wooden switch.',
 'In noaptea de 5 decembrie copiii isi lasa ghetutele la usa. Cei cuminti gasesc dulciuri, cei obraznici o nuielusa.'),

('Pastele','Romania',
 'Red-dyed eggs are tapped against each other with the words Hristos a inviat. The one whose egg does not crack wins the round.',
 'Se ciocnesc oua rosii, spunand Hristos a inviat. Castiga cel al carui ou nu se sparge.'),

('Craciunul','Romania',
 'Carollers go door to door from Christmas Eve. Hosts give them nuts, apples and colaci - and turning them away is considered bad luck.',
 'Colindatorii merg din casa in casa din Ajun. Gazdele le dau nuci, mere si colaci - iar sa ii refuzi e semn rau.'),

('Plugusorul','Romania',
 'On New Year''s Eve boys go house to house with a decorated plough and a buhai, a friction drum that growls like a bull, wishing a rich harvest.',
 'In seara de Anul Nou baietii merg din casa in casa cu plugul impodobit si cu buhaiul, care mugeste ca un taur, urand recolta bogata.'),

('Ziua Unirii Principatelor','Romania',
 'On 24 January 1859 Moldavia and Wallachia chose the same ruler. Today people join hands in the street and dance the Hora Unirii.',
 'Pe 24 ianuarie 1859 Moldova si Tara Romaneasca l-au ales pe acelasi domnitor. Azi lumea se prinde in strada in Hora Unirii.'),

('Armindeni','Romania',
 'On 1 May a green branch was tied at the gate to guard the household. These days the country mostly spends it outdoors, with mici and beer.',
 'Pe 1 mai se punea o ramura verde la poarta, ca sa apere casa. Azi tara o petrece mai ales afara, cu mici si bere.'),

('Rusaliile','Romania',
 'The Calusari dance a ritual said to heal those taken by the fairies. UNESCO put the Calus ritual on its heritage list in 2008.',
 'Calusarii joaca un ritual despre care se spune ca vindeca pe cei luati din Calus. UNESCO a inscris ritualul Calusului in 2008.'),

('Ziua Iei','Romania',
 'On 24 June the Romanian blouse is celebrated worldwide. The day was started in 2013 by an online community, not by the state.',
 'Pe 24 iunie se sarbatoreste ia romaneasca in toata lumea. Ziua a fost pornita in 2013 de o comunitate online, nu de stat.'),

-- ---------- Europa (15) ----------
('La Tomatina','Spain',
 'On the last Wednesday of August the town of Bunol throws about 150 tons of tomatoes at itself. The fight lasts exactly one hour.',
 'In ultima miercuri din august, orasul Bunol arunca cu vreo 150 de tone de rosii. Bataia dureaza exact o ora.'),

('Oktoberfest','Germany',
 'Munich''s beer festival began in 1810 as a royal wedding party. Despite the name, most of it now happens in September.',
 'Festivalul berii din Munchen a inceput in 1810, ca petrecere de nunta regala. In ciuda numelui, azi se tine mai mult in septembrie.'),

('Bastille Day','France',
 'On 14 July, the Champs-Elysees hosts the oldest regular military parade in Europe, running since 1880.',
 'Pe 14 iulie, pe Champs-Elysees are loc cea mai veche parada militara regulata din Europa, tinuta din 1880.'),

('St Patrick''s Day','Ireland',
 'On 17 March the world goes green for Ireland''s patron saint. Chicago has been dyeing its river green for the day since 1962.',
 'Pe 17 martie lumea se face verde pentru sfantul patron al Irlandei. Chicago isi vopseste raul in verde de ziua asta din 1962.'),

('Sinterklaas','Netherlands',
 'On 5 December children leave a shoe by the fireplace, with a carrot in it for the saint''s horse, and find a present in the morning.',
 'Pe 5 decembrie copiii isi lasa un pantof langa semineu, cu un morcov in el pentru calul sfantului, si dimineata gasesc un cadou.'),

('Midsommar','Sweden',
 'A flower-covered maypole is raised and danced around. Tradition says seven kinds of flowers under your pillow show you your future spouse.',
 'Se ridica un stalp acoperit cu flori si se danseaza in jurul lui. Se zice ca sapte feluri de flori sub perna iti arata viitorul sot.'),

('Carnevale di Venezia','Italy',
 'Venice''s masked carnival ends on Shrove Tuesday. Its best known mask, the long-beaked plague doctor, was originally medical gear.',
 'Carnavalul mascat al Venetiei se termina in Martea Grasa. Cea mai cunoscuta masca, doctorul de ciuma cu cioc lung, era la inceput un echipament medical.'),

('Las Fallas','Spain',
 'Valencia spends all year building giant papier-mache figures, then burns nearly every one of them in a single night, on 19 March.',
 'Valencia construieste tot anul figuri uriase din papier-mache, apoi le arde aproape pe toate intr-o singura noapte, pe 19 martie.'),

('Krampusnacht','Austria',
 'On 5 December, Krampus - a horned companion of St Nicholas - parades through Alpine towns to frighten the children who misbehaved.',
 'Pe 5 decembrie, Krampus - insotitorul cu coarne al Sfantului Nicolae - defileaza prin orasele alpine ca sa sperie copiii neascultatori.'),

('Guy Fawkes Night','United Kingdom',
 'On 5 November Britain lights bonfires and fireworks to mark the 1605 plot to blow up Parliament - which failed.',
 'Pe 5 noiembrie britanicii aprind focuri si artificii pentru complotul din 1605 de a arunca in aer Parlamentul - care a esuat.'),

('San Fermin','Spain',
 'Pamplona''s running of the bulls covers 875 metres through the old town. The whole thing is usually over in two to three minutes.',
 'Alergarea cu taurii din Pamplona are 875 de metri prin orasul vechi. Totul se termina de obicei in doua-trei minute.'),

('Santa Lucia','Sweden',
 'On 13 December a girl in a crown of candles leads a procession of singers. The date was the longest night under the old calendar.',
 'Pe 13 decembrie o fata cu o coroana de lumanari conduce o procesiune de cantareti. Data era cea mai lunga noapte in vechiul calendar.'),

('La Befana','Italy',
 'On the night of 5 January an old woman flies in on a broom, leaving sweets for good children and a lump of coal for the rest.',
 'In noaptea de 5 ianuarie vine o batrana pe o matura, lasand dulciuri copiilor cuminti si o bucata de carbune celorlalti.'),

('Koningsdag','Netherlands',
 'On 27 April the whole country dresses in orange and turns into one enormous flea market, where anyone may sell anything, tax free.',
 'Pe 27 aprilie toata tara se imbraca in portocaliu si se transforma intr-un urias targ de vechituri, unde oricine poate vinde orice, fara taxe.'),

('Up Helly Aa','Scotland',
 'On the last Tuesday of January, Lerwick in Shetland marches a replica Viking longship through town and then sets it on fire.',
 'In ultima marti din ianuarie, Lerwick din Shetland plimba prin oras o replica de corabie vikinga si apoi ii da foc.')

ON DUPLICATE KEY UPDATE
  `country` = VALUES(`country`),
  `fact_en` = VALUES(`fact_en`),
  `fact_ro` = VALUES(`fact_ro`);
