// ============================================================
//  CONFIGURARE / CONEXIUNE BAZA DE DATE (MySQL)
// ============================================================
// Declaratiile pentru conexiunea MySQL, separate de gamemode.
// Necesita ca <a_mysql> sa fie deja inclus inainte de acest fisier.

#if !defined _INC_mysql_config
#define _INC_mysql_config

// Credentiale conexiune
#define MYSQL_HOST  "127.0.0.1"
#define MYSQL_USER  "root"
#define MYSQL_PASS  ""
#define MYSQL_DB    "rpg1"

// Handle-ul global al conexiunii, folosit in tot gamemode-ul
new MySQL:g_SQL;

#endif // _INC_mysql_config
