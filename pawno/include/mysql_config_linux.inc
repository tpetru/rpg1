// ============================================================
//  CONFIGURARE / CONEXIUNE BAZA DE DATE (MySQL) - server Linux
// ============================================================
// Declaratiile pentru conexiunea MySQL, separate de gamemode.
// Necesita ca <a_mysql> sa fie deja inclus inainte de acest fisier.

#if !defined _INC_mysql_config_linux
#define _INC_mysql_config_linux

// Credentiale conexiune (server local, port implicit 3306)
#define MYSQL_HOST  "localhost"
#define MYSQL_PORT  3306
#define MYSQL_USER  "rpg_user"
#define MYSQL_PASS  "parola123"
#define MYSQL_DB    "rpg1"

// Handle-ul global al conexiunii, folosit in tot gamemode-ul
new MySQL:g_SQL;

#endif // _INC_mysql_config_linux
