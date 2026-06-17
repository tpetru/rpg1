// ============================================================
//  DB.INC - Conexiune MySQL si Schema
// ============================================================
#if defined _db_included
    #endinput
#endif
#define _db_included

new MySQL:g_SQL;

// ============================================================
//  INITIALIZARE
// ============================================================

stock DB_Init()
{
    new MySQLOpt:opt = mysql_init_options();
    mysql_set_option(opt, AUTO_RECONNECT, true);
    g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB, opt);

    if(g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
    {
        print("[DB] EROARE: Nu s-a putut conecta la MySQL!");
        SendRconCommand("exit");
        return 0;
    }
    print("[DB] Conectat la MySQL cu succes!");
    DB_CreateTables();
    return 1;
}

stock DB_Close()
{
    mysql_close(g_SQL);
}

// ============================================================
//  CREARE TABELE
// ============================================================

stock DB_CreateTables()
{
    // Playeri
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `players` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `username` VARCHAR(24) NOT NULL UNIQUE, \
        `password` VARCHAR(64) NOT NULL, \
        `email` VARCHAR(64) DEFAULT '', \
        `level` INT DEFAULT 1, \
        `xp` INT DEFAULT 0, \
        `money` BIGINT DEFAULT 500, \
        `bank` BIGINT DEFAULT 0, \
        `rp` INT DEFAULT 0, \
        `health` FLOAT DEFAULT 100.0, \
        `armour` FLOAT DEFAULT 0.0, \
        `skin` INT DEFAULT 0, \
        `faction` INT DEFAULT 0, \
        `faction_rank` INT DEFAULT 0, \
        `job` INT DEFAULT 0, \
        `pos_x` FLOAT DEFAULT 1958.33, \
        `pos_y` FLOAT DEFAULT 1343.12, \
        `pos_z` FLOAT DEFAULT 15.36, \
        `interior` INT DEFAULT 0, \
        `vw` INT DEFAULT 0, \
        `wanted` INT DEFAULT 0, \
        `jailed` TINYINT DEFAULT 0, \
        `jail_time` INT DEFAULT 0, \
        `fines` BIGINT DEFAULT 0, \
        `is_sick` TINYINT DEFAULT 0, \
        `disease_name` VARCHAR(32) DEFAULT '', \
        `last_voted_president` DATE DEFAULT NULL, \
        `voted_candidate` INT DEFAULT 0, \
        `last_president_term` DATE DEFAULT NULL, \
        `is_president` TINYINT DEFAULT 0, \
        `kills` INT DEFAULT 0, \
        `deaths` INT DEFAULT 0, \
        `play_hours` INT DEFAULT 0, \
        `registered_at` DATETIME DEFAULT NOW(), \
        `last_login` DATETIME DEFAULT NOW() \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "", "", 0
    );

    // Vehicule personale
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `vehicles` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `owner_id` INT NOT NULL, \
        `model` INT NOT NULL, \
        `plate` VARCHAR(8) DEFAULT 'NORPG', \
        `color1` INT DEFAULT 1, \
        `color2` INT DEFAULT 1, \
        `pos_x` FLOAT DEFAULT 0.0, \
        `pos_y` FLOAT DEFAULT 0.0, \
        `pos_z` FLOAT DEFAULT 0.0, \
        `angle` FLOAT DEFAULT 0.0, \
        `fuel` FLOAT DEFAULT 100.0, \
        `mileage` INT DEFAULT 0, \
        `locked` TINYINT DEFAULT 0, \
        `insurance` TINYINT DEFAULT 0, \
        `insurance_exp` DATE DEFAULT NULL, \
        `rovigneta` TINYINT DEFAULT 0, \
        `rovigneta_exp` DATE DEFAULT NULL, \
        `itp` TINYINT DEFAULT 0, \
        `itp_exp` DATE DEFAULT NULL, \
        `registered` TINYINT DEFAULT 0, \
        `trusa` TINYINT DEFAULT 0, \
        `stingator` TINYINT DEFAULT 0, \
        `vesta` TINYINT DEFAULT 0 \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Case
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `houses` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `owner_id` INT DEFAULT 0, \
        `address` VARCHAR(64) DEFAULT 'Necunoscut', \
        `price` BIGINT DEFAULT 50000, \
        `interior` INT DEFAULT 1, \
        `pos_x` FLOAT, \
        `pos_y` FLOAT, \
        `pos_z` FLOAT, \
        `in_x` FLOAT DEFAULT 2233.0, \
        `in_y` FLOAT DEFAULT -1115.0, \
        `in_z` FLOAT DEFAULT 26.5, \
        `locked` TINYINT DEFAULT 1, \
        `for_sale` TINYINT DEFAULT 1, \
        `has_pets` TINYINT DEFAULT 0, \
        `max_pets` INT DEFAULT 2, \
        `rent_price` BIGINT DEFAULT 0, \
        `taxes` BIGINT DEFAULT 0 \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Afaceri
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `businesses` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `owner_id` INT DEFAULT 0, \
        `name` VARCHAR(32) DEFAULT 'Afacere', \
        `type` INT DEFAULT 1, \
        `price` BIGINT DEFAULT 100000, \
        `pos_x` FLOAT, \
        `pos_y` FLOAT, \
        `pos_z` FLOAT, \
        `for_sale` TINYINT DEFAULT 1, \
        `income` BIGINT DEFAULT 1000, \
        `taxes` BIGINT DEFAULT 0 \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Animale companie
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `pets` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `owner_id` INT NOT NULL, \
        `name` VARCHAR(24) DEFAULT 'Fido', \
        `type` INT DEFAULT 0, \
        `model` INT DEFAULT 0, \
        `health` FLOAT DEFAULT 100.0, \
        `hunger` INT DEFAULT 100, \
        `happiness` INT DEFAULT 100, \
        `house_id` INT DEFAULT 0, \
        `is_out` TINYINT DEFAULT 1, \
        `pos_x` FLOAT DEFAULT 0.0, \
        `pos_y` FLOAT DEFAULT 0.0, \
        `pos_z` FLOAT DEFAULT 0.0 \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Ziare
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `newspapers` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `reporter_id` INT NOT NULL, \
        `title` VARCHAR(64) DEFAULT 'Ziar', \
        `category` VARCHAR(32) DEFAULT 'General', \
        `content` TEXT, \
        `price` BIGINT DEFAULT 100, \
        `created_at` DATETIME DEFAULT NOW() \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Presedinte
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `president` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `player_id` INT NOT NULL, \
        `income_tax` INT DEFAULT 10, \
        `cass` INT DEFAULT 5, \
        `elected_at` DATETIME DEFAULT NOW(), \
        `term_end` DATETIME, \
        `active` TINYINT DEFAULT 0 \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Voturi
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `votes` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `voter_id` INT NOT NULL, \
        `candidate_id` INT NOT NULL, \
        `voted_at` DATETIME DEFAULT NOW() \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Mafia
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `mafia_finance` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `faction_id` INT NOT NULL UNIQUE, \
        `bank` BIGINT DEFAULT 0, \
        `gold` FLOAT DEFAULT 0.0, \
        `drugs` FLOAT DEFAULT 0.0, \
        `materials` INT DEFAULT 0 \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Teritorii
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `territories` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `name` VARCHAR(32), \
        `owner_faction` INT DEFAULT 0, \
        `income` BIGINT DEFAULT 5000, \
        `pos_x` FLOAT, \
        `pos_y` FLOAT, \
        `pos_z` FLOAT, \
        `radius` FLOAT DEFAULT 100.0, \
        `capture_cooldown` DATETIME DEFAULT NULL \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Boli
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `diseases` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `name` VARCHAR(32), \
        `description` VARCHAR(128), \
        `created_by` INT, \
        `active` TINYINT DEFAULT 1, \
        `created_at` DATETIME DEFAULT NOW() \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Trade
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `trades` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `sender_id` INT NOT NULL, \
        `receiver_id` INT NOT NULL, \
        `type` VARCHAR(16), \
        `item_id` INT DEFAULT 0, \
        `price` BIGINT DEFAULT 0, \
        `status` VARCHAR(12) DEFAULT 'pending', \
        `created_at` DATETIME DEFAULT NOW() \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Tururi
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `tours` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `leader_id` INT NOT NULL, \
        `type` INT DEFAULT 1, \
        `name` VARCHAR(64), \
        `active` TINYINT DEFAULT 1, \
        `started_at` DATETIME DEFAULT NOW() \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);


    // Fines log
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `fines_log` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY, \
        `officer_id` INT, \
        `player_id` INT, \
        `reason` VARCHAR(64), \
        `amount` BIGINT, \
        `created_at` DATETIME DEFAULT NOW() \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
    "", "", 0);

    print("[DB] Tabele verificate/create cu succes.");
}
