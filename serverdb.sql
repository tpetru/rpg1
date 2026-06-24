-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Jun 22, 2026 at 03:37 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `rpg1`
--

-- --------------------------------------------------------

--
-- Table structure for table `basket_hoops`
--

CREATE TABLE `basket_hoops` (
  `id` int(11) NOT NULL,
  `x` float DEFAULT 0,
  `y` float DEFAULT 0,
  `z` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `basket_hoops`
--

INSERT INTO `basket_hoops` (`id`, `x`, `y`, `z`) VALUES
(1, 2480.35, 1297.5, 13),
(2, 2480.13, 1286.42, 13),
(3, 2514.9, 1297.55, 13),
(4, 2514.7, 1286.5, 13),
(5, 2514.9, 1277.55, 13),
(6, 2514.7, 1266.49, 13),
(7, 2480.1, 1266.44, 13),
(8, 2480.28, 1277.49, 13);

-- --------------------------------------------------------

--
-- Table structure for table `basket_spawns`
--

CREATE TABLE `basket_spawns` (
  `id` int(11) NOT NULL,
  `hoop_id` int(11) NOT NULL,
  `spawn_id` int(11) NOT NULL,
  `x` float DEFAULT 0,
  `y` float DEFAULT 0,
  `z` float DEFAULT 0,
  `rx` float DEFAULT 0,
  `ry` float DEFAULT 0,
  `rz` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `basket_spawns`
--

INSERT INTO `basket_spawns` (`id`, `hoop_id`, `spawn_id`, `x`, `y`, `z`, `rx`, `ry`, `rz`) VALUES
(1, 1, 1, 2484.89, 1297.31, 10.8125, 0, 0, 0),
(3, 1, 2, 2484.89, 1297.31, 10.8125, 0, 0, 0),
(4, 1, 3, 2482.77, 1295.51, 10.8125, 0, 0, 0),
(5, 1, 4, 2486.51, 1298.12, 10.8125, 0, 0, 0),
(6, 2, 1, 2487.7, 1287.6, 10.8125, 0, 0, 0),
(7, 2, 2, 2484.7, 1285.53, 10.8125, 0, 0, 0),
(8, 2, 3, 2481.94, 1291.18, 10.8125, 0, 0, 0),
(9, 2, 4, 2485.87, 1283.32, 10.8125, 0, 0, 0),
(10, 3, 1, 2514.95, 1302.45, 10.8125, 0, 0, 0),
(11, 3, 2, 2511.51, 1301.29, 10.8125, 0, 0, 0),
(12, 3, 3, 2511.06, 1293.46, 10.8125, 0, 0, 0),
(13, 3, 4, 2514.68, 1291.23, 10.8125, 0, 0, 0),
(14, 4, 1, 2513, 1287.26, 10.8125, 0, 0, 0),
(15, 4, 2, 2512.34, 1284.18, 10.8125, 0, 0, 0),
(16, 4, 3, 2506.52, 1286.56, 10.8125, 0, 0, 0),
(17, 4, 4, 2510.38, 1284.47, 10.8125, 0, 0, 0),
(18, 5, 1, 2510.78, 1277.4, 10.8125, 0, 0, 0),
(19, 5, 2, 2512.49, 1275.49, 10.8125, 0, 0, 0),
(20, 5, 3, 2512.48, 1279.31, 10.8125, 0, 0, 0),
(21, 5, 4, 2508.29, 1277.57, 10.8125, 0, 0, 0),
(22, 6, 1, 2514.22, 1274.26, 10.8125, 0, 0, 0),
(23, 6, 2, 2509.24, 1267.96, 10.8125, 0, 0, 0),
(24, 6, 3, 2510.24, 1263.91, 10.8125, 0, 0, 0),
(25, 6, 4, 2512.01, 1266.92, 10.8125, 0, 0, 0),
(26, 7, 1, 2485.41, 1265.55, 10.8125, 0, 0, 0),
(27, 7, 2, 2483.26, 1267.32, 10.8125, 0, 0, 0),
(28, 7, 3, 2481.79, 1263.59, 10.8125, 0, 0, 0),
(29, 7, 4, 2486.58, 1273.09, 10.8125, 0, 0, 0),
(30, 8, 1, 2485.01, 1274.33, 10.8125, 0, 0, 0),
(31, 8, 2, 2487.35, 1278.49, 10.8125, 0, 0, 0),
(32, 8, 3, 2483.35, 1279.17, 10.8125, 0, 0, 0),
(33, 8, 4, 2481.4, 1282.06, 10.8125, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `businesses`
--

CREATE TABLE `businesses` (
  `id` int(11) NOT NULL,
  `owned` tinyint(4) DEFAULT 0,
  `owner` varchar(24) DEFAULT '',
  `owner_id` int(11) DEFAULT 0,
  `price` int(11) DEFAULT 50000,
  `bank` int(11) DEFAULT 0,
  `loc_x` float DEFAULT 0,
  `loc_y` float DEFAULT 0,
  `loc_z` float DEFAULT 0,
  `name` varchar(32) DEFAULT 'Business'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `businesses`
--

INSERT INTO `businesses` (`id`, `owned`, `owner`, `owner_id`, `price`, `bank`, `loc_x`, `loc_y`, `loc_z`, `name`) VALUES
(1, 0, '', 0, 50000, 60, 2840.52, 1283.11, 11.3906, 'Rent Mountain Bike LV'),
(2, 0, '', 0, 50000, 300, 2238.13, 1294.79, 10.8203, 'DMV - B Category'),
(3, 0, '', 0, 50000, 30, 2178.33, 1288.23, 10.8203, 'Rent Car - Pyramid'),
(4, 0, '', 0, 50000, 1000, 1375.26, 1058.07, 10.8203, 'DMV - C Category'),
(5, 0, '', 0, 50000, 200, -36.0398, 2349.37, 24.3026, 'DMV - A Category'),
(6, 0, '', 0, 50000, 40, -22.3867, 2322.64, 24.1406, 'Rent Bikes - Desert'),
(7, 0, '', 0, 50000, 400, 1887.15, 2585.1, 10.8203, 'DMV - D Category'),
(8, 0, '', 0, 50000, 0, 2225.88, 1840.23, 10.8203, 'Moonstar Dealership'),
(9, 0, '', 0, 50000, 0, 2861.52, 2430.52, 11.069, 'MedKit Seller'),
(10, 0, '', 0, 50000, 0, 2846.29, 2415.08, 11.069, 'Extinctor Seller'),
(11, 0, '', 0, 50000, 0, 1457.71, 2773.42, 10.8203, 'Insurance Company'),
(12, 0, '', 0, 50000, 0, 2763.63, 2468.81, 11.0625, 'Pizza Restaurant'),
(13, 0, '', 0, 50000, 0, 2778.56, 2452.71, 11.0625, 'Burger Restaurant');

-- --------------------------------------------------------

--
-- Table structure for table `factions`
--

CREATE TABLE `factions` (
  `id` int(11) NOT NULL,
  `name` varchar(32) NOT NULL DEFAULT '',
  `members` int(11) DEFAULT 0,
  `lead` varchar(24) DEFAULT '',
  `bank` bigint(20) DEFAULT 0,
  `pickup_id` int(11) DEFAULT -1,
  `mapicon_id` int(11) DEFAULT -1,
  `hq_x` float DEFAULT 0,
  `hq_y` float DEFAULT 0,
  `hq_z` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `factions`
--

INSERT INTO `factions` (`id`, `name`, `members`, `lead`, `bank`, `pickup_id`, `mapicon_id`, `hq_x`, `hq_y`, `hq_z`) VALUES
(1, 'Politia Romana', 0, '', 0, 1247, 30, 2290.04, 2430.87, 10.8203),
(2, 'Registrul Auto Roman', 1, 'Punctulet', 2100, 1581, 55, 967.618, 2153.73, 10.8203),
(3, 'SMURD', 0, '', 250, 11738, 22, 1607.26, 1817.65, 10.5),
(4, 'Mafia Europeana', 0, '', 0, 1314, 58, -254.306, 2603.18, 62.8582),
(5, 'Mafia Americana', 1, 'Punctulet2', 0, 1314, 59, -1390.28, 2637.81, 55.9844),
(6, 'Mafia Africana', 0, '', 0, 1314, 62, -828.418, 1440.03, 13.9761),
(7, 'Mafia Asiatica', 0, '', 0, 1314, 60, 77.4821, 1163.53, 18.6641);

-- --------------------------------------------------------

--
-- Table structure for table `houses`
--

CREATE TABLE `houses` (
  `id` int(11) NOT NULL,
  `name` varchar(32) DEFAULT 'Casa',
  `owner` varchar(24) DEFAULT '',
  `owner_id` int(11) DEFAULT 0,
  `owned` tinyint(4) DEFAULT 0,
  `price` int(11) DEFAULT 50000,
  `loc_x` float DEFAULT 0,
  `loc_y` float DEFAULT 0,
  `loc_z` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `houses`
--

INSERT INTO `houses` (`id`, `name`, `owner`, `owner_id`, `owned`, `price`, `loc_x`, `loc_y`, `loc_z`) VALUES
(1, 'Gara', 'Punctulet', 1, 1, 1, 2843.43, 1294.67, 11.3906);

-- --------------------------------------------------------

--
-- Table structure for table `locations_admin`
--

CREATE TABLE `locations_admin` (
  `locID` int(11) NOT NULL,
  `locName` varchar(32) NOT NULL DEFAULT '',
  `locX` float DEFAULT 0,
  `locY` float DEFAULT 0,
  `locZ` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `locations_admin`
--

INSERT INTO `locations_admin` (`locID`, `locName`, `locX`, `locY`, `locZ`) VALUES
(1, 'examA', -13.0385, 2346.39, 24.1406),
(2, 'examB', 2236.21, 1285.57, 10.8203),
(3, 'examC', 1375.23, 1019.83, 10.8203),
(4, 'examD', 1896.16, 2586.31, 11.0234),
(5, 'vplate', 930, 2074, 12.5),
(6, 'vitp', 930, 2067, 12.5),
(7, 'Golf', 1407.91, 2788.75, 11),
(8, 'Basket', 2460.83, 1325.01, 11),
(49, 'hospital', 1582.56, 1769.12, 10.8203);

-- --------------------------------------------------------

--
-- Table structure for table `locations_gps`
--

CREATE TABLE `locations_gps` (
  `glID` int(11) NOT NULL,
  `glCategory` varchar(32) NOT NULL DEFAULT '',
  `glName` varchar(32) NOT NULL DEFAULT '',
  `glLocX` float DEFAULT 0,
  `glLocY` float DEFAULT 0,
  `glLocZ` float DEFAULT 0,
  `glCategoryName` varchar(32) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `locations_gps`
--

INSERT INTO `locations_gps` (`glID`, `glCategory`, `glName`, `glLocX`, `glLocY`, `glLocZ`, `glCategoryName`) VALUES
(1, '1', 'DMV - A Category', -13.0385, 2346.39, 24.1406, 'DMV Locations'),
(2, '1', 'DMV - B Category', 2236.21, 1285.57, 10.8203, 'DMV Locations'),
(3, '1', 'DMV - C Category', 1375.23, 1019.83, 10.8203, 'DMV Locations'),
(4, '1', 'DMV - D Category', 1896.16, 2586.31, 11.0234, 'DMV Locations'),
(5, '4', 'Hospitalization', 1582.56, 1769.12, 10.8203, 'Others'),
(6, '4', 'Business Center', 2834.38, 2388.83, 10.8203, 'Others'),
(7, '4', 'Golf Tournament', 1407.91, 2788.75, 11, 'Others'),
(8, '4', 'Basket Game', 2460.83, 1325.01, 10.8203, 'Others'),
(10, '5', 'Medical Shop 1', 1536.33, 1044.93, 10.8203, 'Shops'),
(11, '5', 'Medical Shop 2', 2194.03, 1990.98, 12.2969, 'Shops'),
(12, '5', 'Medical Shop 3', 1920.27, 2447.38, 11.1782, 'Shops'),
(13, '5', 'Medical Shop 4', 1378.3, 2355.35, 10.8203, 'Shops'),
(14, '5', 'Medical Shop 5', 662.297, 1717.19, 7.1875, 'Shops'),
(15, '5', 'Medical Shop 6', -87.791, 1378.04, 10.2734, 'Shops'),
(89, '5', 'Pizza 1', 2393.14, 2042.61, 10.8203, 'Shops'),
(90, '5', 'Pizza 2', 2638.14, 1849.69, 11.0234, 'Shops'),
(91, '5', 'Pizza 3', 173.198, 1176.23, 14.7645, 'Shops'),
(92, '5', 'Burger 1', 2163.96, 2795.48, 10.8203, 'Shops'),
(93, '5', 'Burger 2', 2366.24, 2071.17, 10.8203, 'Shops'),
(94, '5', 'Burger 3', 2478.7, 2034.23, 11.0625, 'Shops'),
(95, '5', 'Burger 4', 1158.25, 2072.09, 11.0625, 'Shops'),
(96, '5', 'Burger 5', 1873.18, 2071.59, 11.0625, 'Shops');

-- --------------------------------------------------------

--
-- Table structure for table `payday_setup`
--

CREATE TABLE `payday_setup` (
  `id` int(11) NOT NULL DEFAULT 1,
  `min_salary` int(11) DEFAULT 5000,
  `tax` int(11) DEFAULT 10,
  `cass` int(11) DEFAULT 10,
  `bank_interest` float DEFAULT 0.25,
  `insurance_price` int(11) DEFAULT 500,
  `medkit_price` int(11) DEFAULT 500,
  `extinguisher_price` int(11) DEFAULT 500,
  `itp_price` int(11) DEFAULT 750,
  `plate_price` int(11) DEFAULT 250,
  `rent_bike_price` int(11) DEFAULT 15,
  `exam_b_price` int(11) DEFAULT 300,
  `rent_car_desert_price` int(11) DEFAULT 20,
  `exam_a_price` int(11) DEFAULT 200,
  `exam_c_price` int(11) DEFAULT 500,
  `exam_d_price` int(11) DEFAULT 400,
  `pizza_price` int(11) DEFAULT 50,
  `burger_price` int(11) DEFAULT 55
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payday_setup`
--

INSERT INTO `payday_setup` (`id`, `min_salary`, `tax`, `cass`, `bank_interest`, `insurance_price`, `medkit_price`, `extinguisher_price`, `itp_price`, `plate_price`, `rent_bike_price`, `exam_b_price`, `rent_car_desert_price`, `exam_a_price`, `exam_c_price`, `exam_d_price`, `pizza_price`, `burger_price`) VALUES
(1, 5000, 10, 10, 0.25, 500, 500, 500, 750, 250, 15, 300, 20, 200, 500, 400, 50, 55);

-- --------------------------------------------------------

--
-- Table structure for table `players`
--

CREATE TABLE `players` (
  `id` int(11) NOT NULL,
  `username` varchar(24) NOT NULL,
  `password` varchar(64) NOT NULL,
  `email` varchar(64) DEFAULT '',
  `level` int(11) DEFAULT 1,
  `money` int(11) DEFAULT 0,
  `bank` int(11) DEFAULT 0,
  `rp` int(11) DEFAULT 0,
  `admin_level` int(11) DEFAULT 0,
  `faction` int(11) DEFAULT 0,
  `house` int(11) DEFAULT 999,
  `spawn_type` int(11) DEFAULT 1,
  `faction_rank` int(11) DEFAULT 1,
  `key1` int(11) DEFAULT 0,
  `key2` int(11) DEFAULT 0,
  `key3` int(11) DEFAULT 0,
  `faction_join` date DEFAULT NULL,
  `business` int(11) DEFAULT 999,
  `driving_lic_a_exp` date DEFAULT NULL,
  `driving_lic_b_exp` date DEFAULT NULL,
  `driving_lic_c_exp` date DEFAULT NULL,
  `driving_lic_d_exp` date DEFAULT NULL,
  `diseased` tinyint(4) DEFAULT 0,
  `disease_paydays` int(11) DEFAULT 0,
  `caravan_key` int(11) DEFAULT 0,
  `caravan_x` float DEFAULT 0,
  `caravan_y` float DEFAULT 0,
  `caravan_z` float DEFAULT 0,
  `caravan_rotation` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `players`
--

INSERT INTO `players` (`id`, `username`, `password`, `email`, `level`, `money`, `bank`, `rp`, `admin_level`, `faction`, `house`, `spawn_type`, `faction_rank`, `key1`, `key2`, `key3`, `faction_join`, `business`, `driving_lic_a_exp`, `driving_lic_b_exp`, `driving_lic_c_exp`, `driving_lic_d_exp`, `diseased`, `disease_paydays`, `caravan_key`, `caravan_x`, `caravan_y`, `caravan_z`, `caravan_rotation`) VALUES
(1, 'Punctulet', '112', '', 2, 1077804, 22727250, 17, 6, 2, 1, 2, 5, 1, 2, 0, NULL, 999, '2026-06-30', '2026-06-30', '2026-07-08', '2026-07-04', 0, 0, 1, 0, 0, 0, 0),
(3, 'Punctulet2', '', '', 1, 3347738, 446669, 4, 6, 5, 999, 2, 5, 0, 0, 0, NULL, 999, '2026-06-30', '2026-06-30', '0000-00-00', '0000-00-00', 0, 0, 0, 0, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `rulote_personale`
--

CREATE TABLE `rulote_personale` (
  `rID` int(11) NOT NULL,
  `rOwned` tinyint(4) DEFAULT 0,
  `rOwner` int(11) DEFAULT 0,
  `rPrice` int(11) DEFAULT 0,
  `rCamping` tinyint(4) DEFAULT 0,
  `rCampingStartDate` datetime DEFAULT NULL,
  `rParkLocX` float DEFAULT 0,
  `rParkLocY` float DEFAULT 0,
  `rParkLocZ` float DEFAULT 0,
  `rCampLocX` float DEFAULT 0,
  `rCampLocY` float DEFAULT 0,
  `rCampLocZ` float DEFAULT 0,
  `parkRX` float DEFAULT 0,
  `parkRY` float DEFAULT 0,
  `parkRZ` float DEFAULT 0,
  `campRX` float DEFAULT 0,
  `campRY` float DEFAULT 0,
  `campRZ` float DEFAULT 0,
  `rType` int(11) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rulote_personale`
--

INSERT INTO `rulote_personale` (`rID`, `rOwned`, `rOwner`, `rPrice`, `rCamping`, `rCampingStartDate`, `rParkLocX`, `rParkLocY`, `rParkLocZ`, `rCampLocX`, `rCampLocY`, `rCampLocZ`, `parkRX`, `parkRY`, `parkRZ`, `campRX`, `campRY`, `campRZ`, `rType`) VALUES
(1, 1, 1, 0, 0, NULL, 910.426, 2194.09, 9.9823, 0, 0, 0, 1.2847, 0.6423, -97.7814, 0, 0, 0, 1);

-- --------------------------------------------------------

--
-- Table structure for table `turfs`
--

CREATE TABLE `turfs` (
  `id` int(11) NOT NULL,
  `faction_id` int(11) DEFAULT 0,
  `name` varchar(32) NOT NULL DEFAULT '',
  `x1` float DEFAULT 0,
  `y1` float DEFAULT 0,
  `x2` float DEFAULT 0,
  `y2` float DEFAULT 0,
  `attackable` tinyint(1) DEFAULT 1,
  `color` varchar(8) DEFAULT '000000FF'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `turfs`
--

INSERT INTO `turfs` (`id`, `faction_id`, `name`, `x1`, `y1`, `x2`, `y2`, `attackable`, `color`) VALUES
(1, 4, 'HQ Mafia Europeana', -375, 2561.5, -124, 2813.5, 0, '3366CC88'),
(2, 5, 'HQ Mafia Americana ', -1624, 2538.5, -1361, 2716.5, 0, 'AA44AA88'),
(3, 6, 'HQ Mafia Africana', -842, 1411.5, -698, 1645.5, 0, '44AA4488'),
(4, 7, 'HQ Mafia Asiatica', -382, 977.5, 137, 1207.5, 0, 'FFCC0088');

-- --------------------------------------------------------

--
-- Table structure for table `vehicles_faction`
--

CREATE TABLE `vehicles_faction` (
  `id` int(11) NOT NULL,
  `faction_id` int(11) NOT NULL,
  `model_id` int(11) NOT NULL,
  `loc_x` float DEFAULT 0,
  `loc_y` float DEFAULT 0,
  `loc_z` float DEFAULT 0,
  `rotation` float DEFAULT 0,
  `color1` int(11) DEFAULT 1,
  `color2` int(11) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `vehicles_faction`
--

INSERT INTO `vehicles_faction` (`id`, `faction_id`, `model_id`, `loc_x`, `loc_y`, `loc_z`, `rotation`, `color1`, `color2`) VALUES
(1, 3, 560, 1596, 1832.5, 11.1, 180, 175, 1),
(2, 3, 560, 1614.82, 1832.5, 11.1, 180, 175, 1),
(3, 3, 489, 1602, 1832.5, 11.1, 180, 175, 1),
(4, 3, 489, 1608.54, 1832.5, 11.1, 180, 175, 1),
(5, 3, 407, 1590.39, 1854, 11.1, 180, 175, 1),
(6, 3, 407, 1594.64, 1854, 11.1, 180, 175, 1),
(7, 3, 407, 1620.36, 1854, 11.1, 180, 175, 1),
(8, 3, 407, 1615.9, 1854, 11.1, 180, 175, 1),
(9, 3, 416, 1613, 1840, 11, 0, 175, 1),
(10, 3, 416, 1608, 1840, 11, 0, 175, 1),
(11, 3, 416, 1598, 1840, 11, 0, 175, 1),
(12, 3, 416, 1602, 1840, 11, 0, 175, 1),
(13, 1, 523, 2273, 2425, 10.5, 180, 1, 0),
(14, 1, 523, 2276, 2425, 10.5, 180, 1, 0),
(15, 1, 523, 2279, 2425, 10.5, 180, 1, 0),
(16, 1, 523, 2300, 2431, 10.5, 180, 1, 0),
(17, 1, 523, 2297, 2431, 10.5, 180, 1, 0),
(18, 1, 523, 2294, 2431, 10.5, 180, 1, 0),
(19, 1, 598, 2252, 2442.5, 10.5, 0, 1, 0),
(20, 1, 598, 2260.5, 2442.5, 10.5, 0, 1, 0),
(21, 1, 598, 2260, 2477, 10.7, 180, 1, 0),
(22, 1, 598, 2278, 2478, 11.1, 180, 1, 0),
(23, 1, 598, 2282, 2443, 11.1, 0, 1, 0),
(24, 1, 427, 2290, 2443, 11.1, 0, 1, 0),
(25, 1, 427, 2295, 2443, 11.1, 0, 1, 0),
(26, 1, 599, 2290, 2478, 11.2, 180, 1, 0),
(27, 1, 599, 2295, 2478, 11.2, 180, 1, 0),
(28, 2, 552, 970, 2178, 10.8, 180, 198, 1),
(29, 2, 552, 975, 2178, 10.8, 180, 198, 1),
(30, 2, 552, 980, 2178, 10.6, 180, 198, 1),
(31, 2, 498, 985, 2178, 10.8, 180, 198, 1),
(32, 2, 525, 993, 2171, 10.8, 120, 198, 1),
(33, 2, 525, 993, 2164, 10.8, 120, 198, 1),
(34, 2, 525, 993, 2157, 10.8, 120, 198, 1),
(35, 2, 443, 970, 2110, 11.6, 360, 198, 1),
(36, 2, 568, 993, 2151, 10.8, 120, 198, 1),
(37, 2, 568, 993, 2146, 10.9, 120, 198, 1),
(38, 4, 579, -237, 2594.68, 62.6291, 360, 135, 6),
(39, 4, 579, -237, 2609.29, 62.6357, 180, 135, 6),
(40, 4, 429, -231.48, 2609, 62.3828, 180, 135, 6),
(41, 4, 429, -228.107, 2609, 62.3828, 180, 135, 6),
(42, 4, 560, -225.745, 2594, 62.4084, 0, 135, 6),
(43, 4, 560, -229.233, 2594, 62.4084, 0, 135, 6),
(44, 4, 468, -257.027, 2607, 62.5271, 0, 135, 6),
(45, 4, 468, -258.851, 2607, 62.5271, 360, 135, 6),
(46, 4, 468, -260.626, 2607, 62.527, 360, 135, 6),
(47, 4, 521, -262.527, 2607, 62.4269, 0, 135, 6),
(48, 4, 521, -263.759, 2607, 62.43, 0, 135, 6),
(49, 4, 521, -265.41, 2607, 62.43, 0, 135, 6),
(50, 5, 468, -1390, 2627.83, 55.8, 90, 147, 162),
(51, 5, 468, -1390, 2630.06, 55.8, 90, 147, 162),
(52, 5, 468, -1390, 2631.86, 55.8, 90, 147, 162),
(53, 5, 521, -1393, 2645.24, 55.6, 90, 147, 162),
(54, 5, 521, -1393, 2643.55, 55.6, 90, 147, 162),
(55, 5, 521, -1393, 2642, 55.6, 90, 147, 162),
(56, 5, 579, -1400, 2630, 55.8, 90, 147, 162),
(57, 5, 579, -1400, 2635, 55.8, 90, 147, 162),
(58, 5, 560, -1400, 2640, 55.5, 90, 147, 162),
(59, 5, 560, -1400, 2645, 55.5, 90, 147, 162),
(60, 5, 429, -1400, 2650, 55.5, 90, 147, 162),
(61, 5, 429, -1400, 2655, 55.5, 90, 147, 162),
(62, 6, 468, -824, 1420, 13.5414, 5.9297, 235, 235),
(63, 6, 468, -826, 1420, 13.5444, 354.911, 235, 235),
(64, 6, 468, -828, 1420, 13.546, 4.02, 235, 235),
(65, 6, 521, -830, 1420, 13.4451, 1.8511, 235, 235),
(66, 6, 521, -832, 1420, 13.4437, 1.4139, 235, 235),
(67, 6, 521, -834, 1420, 13.4351, 358.073, 235, 235),
(68, 6, 579, -821.66, 1443.35, 13.7222, 180.962, 235, 235),
(69, 6, 579, -817.817, 1443.62, 13.7203, 180.991, 235, 235),
(70, 6, 429, -807.948, 1445.33, 13.4687, 164.327, 235, 235),
(71, 6, 429, -807.902, 1428.55, 13.4687, 19.1117, 235, 235),
(72, 6, 560, -821.867, 1427.83, 13.4942, 9.8804, 235, 235),
(73, 6, 560, -817.114, 1429.64, 13.4942, 10.5811, 235, 235),
(74, 7, 429, 88.3973, 1164, 18.3362, 0, 228, 228),
(75, 7, 429, 66.3377, 1164, 18.3437, 0, 228, 228),
(76, 7, 521, 70.9498, 1164, 18.227, 0, 228, 228),
(77, 7, 521, 72.8612, 1164, 18.2356, 0, 228, 228),
(78, 7, 521, 74.1014, 1164, 18.2358, 0, 228, 228),
(79, 7, 468, 83.1051, 1164, 18.3256, 0, 228, 228),
(80, 7, 468, 81.9492, 1164, 18.3252, 0, 228, 228),
(81, 7, 468, 80.792, 1164, 18.3255, 0, 228, 228),
(82, 7, 579, 92.0217, 1177.92, 18.5944, 90, 228, 228),
(83, 7, 579, 94.797, 1176.5, 18.5957, 90, 228, 228),
(84, 7, 560, 69.3112, 1179, 18.3694, 225, 228, 228),
(85, 7, 560, 63.8412, 1179, 18.3692, 225, 228, 228);

-- --------------------------------------------------------

--
-- Table structure for table `vehicles_personal`
--

CREATE TABLE `vehicles_personal` (
  `id` int(11) NOT NULL,
  `owner_id` int(11) DEFAULT 0,
  `model_id` int(11) NOT NULL,
  `color1` int(11) DEFAULT 1,
  `color2` int(11) DEFAULT 1,
  `plate` varchar(16) DEFAULT NULL,
  `price` int(11) DEFAULT 0,
  `loc_x` float DEFAULT 0,
  `loc_y` float DEFAULT 0,
  `loc_z` float DEFAULT 0,
  `rotation` float DEFAULT 0,
  `insurance_exp` date DEFAULT NULL,
  `medkit_exp` date DEFAULT NULL,
  `extinguisher_exp` date DEFAULT NULL,
  `itp_exp` date DEFAULT NULL,
  `locked` tinyint(4) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `vehicles_personal`
--

INSERT INTO `vehicles_personal` (`id`, `owner_id`, `model_id`, `color1`, `color2`, `plate`, `price`, `loc_x`, `loc_y`, `loc_z`, `rotation`, `insurance_exp`, `medkit_exp`, `extinguisher_exp`, `itp_exp`, `locked`) VALUES
(1, 1, 411, 1, 1, 'f', 2, 976.309, 2140.76, 10.5474, 272.362, '2026-06-18', '2026-06-17', '2026-06-18', '2026-06-17', 0),
(2, 1, 541, 1, 1, '123', 6, 968.921, 2158, 10.4452, 273.257, '2026-06-22', '2026-06-19', '2026-06-17', '2026-06-01', 0),
(4, 0, 411, 1, 1, 'LV 4', 1000000, 2200.13, 1855, 10.5474, 0, NULL, NULL, NULL, NULL, 0),
(5, 0, 411, 1, 1, 'LV 5', 1000000, 2196.26, 1855, 10.5474, 0, NULL, NULL, NULL, NULL, 0),
(6, 0, 411, 1, 1, 'LV 6', 1000000, 2192.57, 1855, 10.5474, 0, NULL, NULL, NULL, NULL, 0),
(7, 0, 541, 1, 1, 'LV 7', 900000, 2188.77, 1855, 10.4452, 0, NULL, NULL, NULL, NULL, 0),
(8, 0, 541, 1, 1, 'LV 8', 900000, 2185.14, 1855, 10.4453, 0, NULL, NULL, NULL, NULL, 0),
(9, 0, 541, 0, 1, 'LV 9', 900000, 2181.26, 1855, 10.4452, 0, NULL, NULL, NULL, NULL, 0),
(10, 0, 560, 1, 1, 'LV 10', 750000, 2206.34, 1880, 10.5253, 180, NULL, NULL, NULL, NULL, 0),
(11, 0, 560, 1, 1, 'LV 11', 750000, 2202.52, 1880, 10.5252, 180, NULL, NULL, NULL, NULL, 0),
(12, 0, 562, 1, 1, 'LV 12', 600000, 2195.03, 1880, 10.4792, 180, NULL, NULL, NULL, NULL, 0),
(13, 0, 562, 1, 1, 'LV 13', 600000, 2191.43, 1880, 10.4791, 180, NULL, NULL, NULL, NULL, 0),
(14, 0, 451, 1, 1, 'LV 14', 650000, 2179.88, 1880, 10.5268, 180, NULL, NULL, NULL, NULL, 0),
(15, 0, 451, 1, 1, 'LV 15', 650000, 2183.73, 1880, 10.527, 180, NULL, NULL, NULL, NULL, 0);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `basket_hoops`
--
ALTER TABLE `basket_hoops`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `basket_spawns`
--
ALTER TABLE `basket_spawns`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_hoop_spawn` (`hoop_id`,`spawn_id`);

--
-- Indexes for table `businesses`
--
ALTER TABLE `businesses`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `factions`
--
ALTER TABLE `factions`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `houses`
--
ALTER TABLE `houses`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `locations_admin`
--
ALTER TABLE `locations_admin`
  ADD PRIMARY KEY (`locID`),
  ADD UNIQUE KEY `uq_location_name` (`locName`);

--
-- Indexes for table `locations_gps`
--
ALTER TABLE `locations_gps`
  ADD PRIMARY KEY (`glID`),
  ADD UNIQUE KEY `uq_gps_name` (`glName`);

--
-- Indexes for table `payday_setup`
--
ALTER TABLE `payday_setup`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `players`
--
ALTER TABLE `players`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- Indexes for table `rulote_personale`
--
ALTER TABLE `rulote_personale`
  ADD PRIMARY KEY (`rID`);

--
-- Indexes for table `turfs`
--
ALTER TABLE `turfs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_turf_name` (`name`);

--
-- Indexes for table `vehicles_faction`
--
ALTER TABLE `vehicles_faction`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `vehicles_personal`
--
ALTER TABLE `vehicles_personal`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `plate_unique` (`plate`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `basket_spawns`
--
ALTER TABLE `basket_spawns`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT for table `businesses`
--
ALTER TABLE `businesses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `houses`
--
ALTER TABLE `houses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `locations_admin`
--
ALTER TABLE `locations_admin`
  MODIFY `locID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=572;

--
-- AUTO_INCREMENT for table `locations_gps`
--
ALTER TABLE `locations_gps`
  MODIFY `glID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=976;

--
-- AUTO_INCREMENT for table `players`
--
ALTER TABLE `players`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `rulote_personale`
--
ALTER TABLE `rulote_personale`
  MODIFY `rID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `turfs`
--
ALTER TABLE `turfs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `vehicles_faction`
--
ALTER TABLE `vehicles_faction`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=86;

--
-- AUTO_INCREMENT for table `vehicles_personal`
--
ALTER TABLE `vehicles_personal`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
