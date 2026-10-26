-- Name chosen by the owner. NULL = show the name of the hex on the map (which clients translate).
ALTER TABLE settlements ADD COLUMN custom_name VARCHAR(30) NULL AFTER name;
