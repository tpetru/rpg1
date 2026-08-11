// ============================================================
//  CONFIGURARE / CONEXIUNE BAZA DE DATE (MySQL) - server Linux
// ============================================================
// Declaratiile pentru conexiunea MySQL, separate de gamemode.
// Necesita ca <a_mysql> sa fie deja inclus inainte de acest fisier.

#if !defined _INC_mysql_config_linux
#define _INC_mysql_config_linux

// Credentiale conexiune - definite in afara repo-ului git, ca parola sa nu fie comisa in istoric.
// Fisierul defineste MYSQL_HOST/MYSQL_PORT/MYSQL_USER/MYSQL_PASS/MYSQL_DB. Daca schimbi masina de
// dezvoltare, creeaza acelasi fisier la calea de mai jos (vezi continutul lui in notele proiectului).
#include "C:/xampp/rpg1_secrets/mysql_credentials.inc"

// Handle-ul global al conexiunii, folosit in tot gamemode-ul
new MySQL:g_SQL;

#endif // _INC_mysql_config_linux
