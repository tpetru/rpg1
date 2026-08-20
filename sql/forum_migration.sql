-- Forum simplu (idei/sugestii, reclamatii, bug-uri, regulament), integrat cu contul din `players`.
-- Ierarhie: category -> subcategory -> topic -> post.
-- Ruleaza manual (phpMyAdmin / HeidiSQL) pe aceeasi baza de date ca UCP-ul si gamemode-ul.

-- Permisiune de forum separata de `admin_level` (site admin): 0=niciuna, 1=muta categorii/subcategorii,
-- 2=pin/lock/status pe topicuri, 3=stergere topicuri/postari. Seteaza manual cui vrei sa dai puteri de forum.
ALTER TABLE `players` ADD COLUMN `admin_forum` TINYINT(4) NOT NULL DEFAULT 0 AFTER `admin_level`;

CREATE TABLE `z_forum_categories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `slug` varchar(50) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `sort_order` tinyint(4) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  CONSTRAINT `z_forum_topics_subcategory_fk` FOREIGN KEY (`subcategory_id`) REFERENCES `z_forum_subcategories` (`id`) ON DELETE CASCADE,
  CONSTRAINT `z_forum_topics_player_fk` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  CONSTRAINT `z_forum_posts_topic_fk` FOREIGN KEY (`topic_id`) REFERENCES `z_forum_topics` (`id`) ON DELETE CASCADE,
  CONSTRAINT `z_forum_posts_player_fk` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cele 4 categorii de top-level. Golite deliberat de subcategorii - adauga-le manual cand stii
-- ce subcategorii vrei in fiecare (ex: INSERT INTO z_forum_subcategories (category_id, name, slug, description, sort_order) VALUES (1, 'General', 'suggestions-general', '...', 1);).
INSERT INTO `z_forum_categories` (`name`, `slug`, `description`, `sort_order`) VALUES
('Suggestions', 'suggestions', 'Ideas and proposals for the server', 1),
('Complaints',  'complaints',  'Complaints about other players or in-game situations', 2),
('Bugs',        'bugs',        'Bugs and issues found in the game or in the UCP', 3),
('Rules',       'rules',       'The server''s official rules', 4);
