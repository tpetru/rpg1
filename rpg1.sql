-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Aug 06, 2026 at 10:02 AM
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
-- Table structure for table `ammunations`
--

CREATE TABLE `ammunations` (
  `amoID` int(11) NOT NULL,
  `amoLocX` float DEFAULT 0,
  `amoLocY` float DEFAULT 0,
  `amoLocZ` float DEFAULT 0,
  `amoName` varchar(32) NOT NULL DEFAULT '',
  `amoInteriorId` int(11) DEFAULT 0,
  `amoVwId` int(11) DEFAULT 0,
  `amoInteriorX` float DEFAULT 0,
  `amoInteriorY` float DEFAULT 0,
  `amoInteriorZ` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ammunations`
--

INSERT INTO `ammunations` (`amoID`, `amoLocX`, `amoLocY`, `amoLocZ`, `amoName`, `amoInteriorId`, `amoVwId`, `amoInteriorX`, `amoInteriorY`, `amoInteriorZ`) VALUES
(1, 1791.4, -1164.8, 23.8281, 'Downtown AmmuNation', 7, 1, 315.24, -140.88, 999.6),
(2, 2400.4, -1981.05, 13.5469, 'WillowField AmmuNation', 6, 2, 297.14, -109.87, 1001.51),
(3, 1081.5, -1698.15, 13.5469, 'Verona AmmuNation', 7, 3, 315.24, -140.88, 999.6),
(4, 1366.61, -1279.79, 13.5469, '', 7, 4, 315.24, -140.88, 999.6);

-- --------------------------------------------------------

--
-- Table structure for table `arm_equipment`
--

CREATE TABLE `arm_equipment` (
  `id` int(11) NOT NULL,
  `arm_id` int(11) NOT NULL,
  `model` int(11) NOT NULL,
  `uses` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `atms`
--

CREATE TABLE `atms` (
  `atmID` int(11) NOT NULL,
  `atmType` int(11) DEFAULT 0,
  `atmLocX` float DEFAULT 0,
  `atmLocY` float DEFAULT 0,
  `atmLocZ` float DEFAULT 0,
  `atmBankOwner` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `atms`
--

INSERT INTO `atms` (`atmID`, `atmType`, `atmLocX`, `atmLocY`, `atmLocZ`, `atmBankOwner`) VALUES
(1, 0, 1103.2, -1428.12, 15.7969, 19),
(2, 0, 926.094, -1206.86, 17.0702, 19),
(3, 0, 813.001, -1805.49, 13.0234, 19),
(4, 0, 1507.5, -1659.58, 13.7969, 19),
(5, 0, 1921.77, -1765.05, 13.5469, 20),
(6, 0, 1954.9, -2178.92, 13.5469, 20),
(7, 0, 2404.7, -1983.24, 13.5469, 20),
(8, 0, 2352.43, -1467.11, 24, 20),
(9, 0, 1089.54, -923.213, 43.3906, 19),
(10, 0, 1085.31, -1802.91, 13.5992, 19);

-- --------------------------------------------------------

--
-- Table structure for table `bans`
--

CREATE TABLE `bans` (
  `banID` int(11) NOT NULL,
  `username` varchar(24) NOT NULL DEFAULT '',
  `ip` varchar(46) NOT NULL DEFAULT '',
  `reason` varchar(128) NOT NULL DEFAULT '',
  `banned_by` varchar(24) NOT NULL DEFAULT '',
  `ban_date` int(11) DEFAULT 0,
  `expire` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
(0, 2290.7, -1541.14, 28.9852),
(1, 2290.51, -1514.78, 28.9852),
(2, 2316.86, -1514.8, 27.3852),
(3, 2317.01, -1541.15, 27.3852);

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
(1, 1, 1, 2290.57, -1533.48, 26.875, 0, 0, 182.19),
(3, 1, 2, 2295.02, -1535.68, 26.875, 0, 0, 137.069),
(4, 1, 3, 2288.42, -1538.38, 26.875, 0, 0, 210.703),
(5, 1, 4, 2281.82, -1536.6, 26.875, 0, 0, 238.904),
(6, 2, 1, 2290.5, -1521.82, 26.875, 0, 0, 2.648),
(7, 2, 2, 2288.29, -1519.56, 26.875, 0, 0, 2.648),
(8, 2, 3, 2282.08, -1517.55, 26.875, 0, 0, 292.461),
(9, 2, 4, 2299.31, -1514.72, 26.875, 0, 0, 91.3222),
(10, 3, 1, 2326.32, -1526.65, 25.3438, 0, 0, 30.5582),
(11, 3, 2, 2321.73, -1524.01, 25.3438, 0, 0, 35.5716),
(12, 3, 3, 2314.59, -1522.75, 25.3438, 0, 0, 80.5716),
(13, 3, 4, 2308.64, -1516.8, 25.3438, 0, 0, 203.52),
(14, 4, 1, 2307.76, -1531.79, 25.3438, 0, 0, 225.117),
(15, 4, 2, 2308.12, -1535.54, 25.3438, 0, 0, 225.43),
(16, 4, 3, 2314.74, -1536, 25.3438, 0, 0, 180.429),
(17, 4, 4, 2319.22, -1536.38, 25.3438, 0, 0, 135.43),
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
-- Table structure for table `bin`
--

CREATE TABLE `bin` (
  `id` int(11) NOT NULL,
  `type` int(11) DEFAULT 1,
  `status_current` int(11) DEFAULT 0,
  `status_max` int(11) DEFAULT 10,
  `locX` float DEFAULT 0,
  `locY` float DEFAULT 0,
  `locZ` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `bin`
--

INSERT INTO `bin` (`id`, `type`, `status_current`, `status_max`, `locX`, `locY`, `locZ`) VALUES
(1, 1, 10, 10, 1337.8, -1774.6, 13.5),
(2, 1, 10, 10, 1919.76, -2088.33, 13.5),
(3, 1, 10, 10, 2382.3, -1940.17, 13.5),
(4, 1, 10, 10, 1420.46, -1846.38, 13.5469),
(5, 1, 9, 10, 1516.62, -1849.3, 13.5469),
(6, 1, 10, 10, 1461.48, -1488.45, 13.5469);

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
  `name` varchar(32) DEFAULT 'Business',
  `is_for_sale` tinyint(4) DEFAULT 0,
  `anaf` tinyint(4) DEFAULT 0,
  `anaf_docs` tinyint(4) DEFAULT 0,
  `default_price` int(11) DEFAULT 50000
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `businesses`
--

INSERT INTO `businesses` (`id`, `owned`, `owner`, `owner_id`, `price`, `bank`, `loc_x`, `loc_y`, `loc_z`, `name`, `is_for_sale`, `anaf`, `anaf_docs`, `default_price`) VALUES
(1, 0, '', 0, 3000000, 105, 830.194, -2047.81, 12.8672, 'Rent Mountain Bike LS', 1, 0, 0, 3000000),
(2, 0, '', 0, 3000000, 599, 341.339, -1500.45, 36.0391, 'DMV - B Category', 1, 0, 0, 3000000),
(3, 0, '', 0, 3000000, 90, 1109.79, -1796.64, 16.5938, 'Rent Car LosSantos', 1, 0, 0, 3000000),
(4, 0, '', 0, 3000000, 1000, 336.535, -1505.59, 36.0391, 'DMV - C Category', 1, 0, 0, 3000000),
(5, 0, '', 0, 3000000, 200, 347.328, -1496.08, 36.0391, 'DMV - A Category', 1, 0, 0, 3000000),
(6, 0, '', 0, 3000000, 120, 452.839, -1796.46, 5.5469, 'Plane and Heli Lic', 1, 0, 0, 3000000),
(7, 0, '', 0, 3000000, 800, 331.728, -1510.81, 36.0391, 'DMV - D Category', 1, 0, 0, 3000000),
(8, 0, '', 0, 3000000, 10, 2131.66, -1150.23, 24.1786, 'Sport Car Dealership', 1, 0, 0, 3000000),
(9, 0, '', 0, 3000000, 1500, 2794.19, -1087.24, 30.7188, 'MedKit Seller', 1, 0, 0, 3000000),
(10, 0, '', 0, 3000000, 500, 2851.76, -1532.58, 11.0938, 'Extinctor Seller', 1, 0, 0, 3000000),
(11, 0, '', 0, 3000000, 0, 1676.3, -1634.62, 14.2266, 'Insurance Company', 1, 0, 0, 3000000),
(12, 0, '', 0, 3000000, 0, 1032.16, -946.005, 42.6399, 'FastFood Restaurant', 1, 0, 0, 3000000),
(13, 0, '', 0, 3000000, 255, 2350.67, -1412.17, 23.9924, 'Home Furnitures', 1, 0, 0, 3000000),
(14, 0, '', 0, 3000000, 360, 1095.79, -1437.42, 22.7631, 'Supermarket Carifura', 1, 0, 0, 3000000),
(15, 0, '', 0, 3000000, 30, 1045.71, -324.804, 73.9922, 'Hidden Harbor Lodge', 1, 0, 0, 3000000),
(16, 0, '', 0, 3000000, 0, 988.774, -1366.03, 13.5488, 'Glovo Co.', 1, 0, 0, 3000000),
(17, 0, '', 0, 3000000, 0, 2485.36, -1957.92, 13.5881, 'Bikers Dealership', 1, 0, 0, 3000000),
(18, 0, '', 0, 3000000, 0, 2046.89, -1918.25, 13.5469, 'SUV Dealership', 1, 0, 0, 3000000),
(19, 0, '', 0, 3000000, 0, 1464.81, -1012.59, 26.8438, 'Swiss Bank', 1, 0, 0, 3000000),
(20, 0, '', 0, 3000000, 41, 2232.58, -1332.84, 23.9815, 'Jew\' Bank', 1, 0, 0, 3000000),
(21, 0, '', 0, 3000000, 810, 1471.9, -1263.4, 14.5625, 'Hello? Phones', 1, 0, 0, 3000000),
(22, 0, '', 0, 3000000, 130, 1546.69, -1270.5, 17.4063, 'Eujenia Network', 1, 0, 0, 3000000);

-- --------------------------------------------------------

--
-- Table structure for table `clothstores`
--

CREATE TABLE `clothstores` (
  `csID` int(11) NOT NULL,
  `csLocX` float DEFAULT 0,
  `csLocY` float DEFAULT 0,
  `csLocZ` float DEFAULT 0,
  `clsName` varchar(32) NOT NULL DEFAULT '',
  `clsInteriorId` int(11) DEFAULT 0,
  `clsVwId` int(11) DEFAULT 0,
  `clsInteriorX` float DEFAULT 0,
  `clsInteriorY` float DEFAULT 0,
  `clsInteriorZ` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `clothstores`
--

INSERT INTO `clothstores` (`csID`, `csLocX`, `csLocY`, `csLocZ`, `clsName`, `clsInteriorId`, `clsVwId`, `clsInteriorX`, `clsInteriorY`, `clsInteriorZ`) VALUES
(1, 2244.4, -1664.22, 15.4766, '', 15, 1, 207.52, -109.74, 1005.13),
(2, 459.84, -1501.17, 31.0387, '', 1, 2, 204.11, -46.8, 1001.8);

-- --------------------------------------------------------

--
-- Table structure for table `cs_locations`
--

CREATE TABLE `cs_locations` (
  `csID` int(11) NOT NULL,
  `csType` int(11) NOT NULL DEFAULT 1,
  `csName` varchar(32) NOT NULL DEFAULT '',
  `csLocX` float NOT NULL DEFAULT 0,
  `csLocY` float NOT NULL DEFAULT 0,
  `csLocZ` float NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
  `hq_z` float DEFAULT 0,
  `interior_x` float DEFAULT 0,
  `interior_y` float DEFAULT 0,
  `interior_z` float DEFAULT 0,
  `interior` int(11) DEFAULT 0,
  `vw` int(11) DEFAULT 0,
  `seif_herbs` int(11) DEFAULT 0,
  `seif_drugs` int(11) DEFAULT 0,
  `skin` int(11) DEFAULT 0,
  `skin1` int(11) DEFAULT 0,
  `skin2` int(11) DEFAULT 0,
  `skin3` int(11) DEFAULT 0,
  `smuggle_cooldown_day` int(11) DEFAULT 0,
  `max_members` int(11) NOT NULL DEFAULT 6,
  `application_on` tinyint(1) NOT NULL DEFAULT 1,
  `interior_a` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `factions`
--

INSERT INTO `factions` (`id`, `name`, `members`, `lead`, `bank`, `pickup_id`, `mapicon_id`, `hq_x`, `hq_y`, `hq_z`, `interior_x`, `interior_y`, `interior_z`, `interior`, `vw`, `seif_herbs`, `seif_drugs`, `skin`, `skin1`, `skin2`, `skin3`, `smuggle_cooldown_day`, `max_members`, `application_on`, `interior_a`) VALUES
(1, 'Politia Romana', 0, '', 12000, 1247, 30, 1554.2, -1675.9, 16.25, 247.2, 63.4, 1003.7, 6, 0, 0, 0, 0, 266, 281, 265, 0, 6, 1, 0),
(2, 'Registrul Auto Roman', 0, 'Punctulet', 2850, 1581, 55, 918.405, -1252.19, 16.2109, 246.06, 108.97, 1003.3, 10, 2, 0, 0, 0, 268, 304, 302, 0, 6, 1, 0),
(3, 'SMURD', 1, '', 250, 11738, 22, 1172.71, -1323.21, 15.4017, 2267.75, 1647.55, 1084.23, 1, 3, 0, 0, 0, 276, 277, 274, 0, 6, 1, 270.473),
(4, 'Mafia Europeana', 0, '', 318600, 1314, 58, 1872.64, -2020.46, 13.5469, 2569.41, -1301.77, 1044.12, 2, 4, 684, 5, 0, 114, 115, 116, 0, 6, 1, 0),
(5, 'Mafia Americana', 1, '', 35700, 1314, 59, 1905.89, -1115.16, 25.9538, 2569.41, -1301.77, 1044.12, 2, 5, 0, 0, 0, 102, 103, 104, 0, 6, 1, 0),
(6, 'Mafia Africana', 1, '', 36000, 1314, 62, 2495.4, -1688.71, 13.9735, 2569.41, -1301.77, 1044.12, 2, 6, 0, 0, 0, 105, 106, 107, 0, 6, 1, 0),
(7, 'Mafia Asiatica', 0, '', 38100, 1314, 60, 2231.89, -1159.81, 25.8906, 2569.41, -1301.77, 1044.12, 2, 7, 0, 0, 0, 108, 109, 110, 0, 6, 1, 0),
(8, 'News Reporters', 0, '', 750, 1318, 34, 733.452, -1350.27, 13.5, 322.5, 303.7, 999.2, 5, 8, 0, 0, 0, 273, 48, 46, 0, 6, 1, 0);

-- --------------------------------------------------------

--
-- Table structure for table `farms`
--

CREATE TABLE `farms` (
  `id` int(11) NOT NULL,
  `x` float DEFAULT 0,
  `y` float DEFAULT 0,
  `z` float DEFAULT 0,
  `range` float DEFAULT 0,
  `tractors` int(11) DEFAULT 0,
  `combines` int(11) DEFAULT 0,
  `dozers` int(11) DEFAULT 0,
  `trucks` int(11) DEFAULT 0,
  `trailers` int(11) DEFAULT 0,
  `nextStep` varchar(16) NOT NULL DEFAULT 'Plow',
  `lastWorkingDate` date DEFAULT NULL,
  `isPlowed` tinyint(1) DEFAULT 0,
  `isLeveled` tinyint(1) DEFAULT 0,
  `isSeeded` tinyint(1) DEFAULT 0,
  `isFertilized` tinyint(1) DEFAULT 0,
  `isReadyToHarvest` tinyint(1) DEFAULT 0,
  `owner` varchar(24) NOT NULL DEFAULT '',
  `isOwned` tinyint(1) DEFAULT 0,
  `price` int(11) DEFAULT 100000,
  `farmBank` int(11) DEFAULT 0,
  `farmRecolta` int(11) DEFAULT 0,
  `owner_id` int(11) DEFAULT 0,
  `is_for_sale` tinyint(1) DEFAULT 0,
  `name` varchar(32) NOT NULL DEFAULT 'Farm',
  `default_price` int(11) DEFAULT 100000
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `farms`
--

INSERT INTO `farms` (`id`, `x`, `y`, `z`, `range`, `tractors`, `combines`, `dozers`, `trucks`, `trailers`, `nextStep`, `lastWorkingDate`, `isPlowed`, `isLeveled`, `isSeeded`, `isFertilized`, `isReadyToHarvest`, `owner`, `isOwned`, `price`, `farmBank`, `farmRecolta`, `owner_id`, `is_for_sale`, `name`, `default_price`) VALUES
(1, -270.554, -1505.49, 4.9108, 30, 1, 0, 3, 0, 0, 'Level', '2026-07-14', 1, 0, 0, 0, 0, 'Punctulet', 1, 10000000, 4250, 0, 1, 0, 'Farm', 100000),
(2, -231.335, -1373.21, 8.6156, 40, 0, 0, 0, 0, 0, 'Plow', NULL, 0, 0, 0, 0, 0, '', 0, 10000000, 0, 0, 0, 1, 'Farm', 100000),
(3, -485.929, -1352.04, 26.1991, 30, 0, 0, 0, 0, 0, 'Plow', NULL, 0, 0, 0, 0, 0, '', 0, 10000000, 0, 0, 0, 1, 'Farm', 100000),
(4, -10.3494, -67.8247, 2.8443, 12, 0, 0, 0, 0, 0, 'Plow', NULL, 0, 0, 0, 0, 0, '', 0, 10000000, 0, 0, 0, 1, 'Farm #4', 10000000),
(5, -146.858, 143.017, 3.6296, 24, 0, 0, 0, 0, 0, 'Plow', NULL, 0, 0, 0, 0, 0, '', 0, 10000000, 0, 0, 0, 1, 'Farm #5', 10000000),
(6, -197.994, -27.9473, 2.8443, 44, 0, 0, 0, 0, 0, 'Plow', NULL, 0, 0, 0, 0, 0, '', 0, 10000000, 0, 0, 0, 1, 'Farm #6', 10000000),
(11, 1961.66, 206.988, 29.8273, 28, 0, 0, 0, 0, 0, 'Plow', NULL, 0, 0, 0, 0, 0, '', 0, 10000000, 0, 0, 0, 1, 'last one', 10000000);

-- --------------------------------------------------------

--
-- Table structure for table `farm_equipment`
--

CREATE TABLE `farm_equipment` (
  `id` int(11) NOT NULL,
  `farm_id` int(11) NOT NULL,
  `model` int(11) NOT NULL,
  `uses` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `farm_equipment`
--

INSERT INTO `farm_equipment` (`id`, `farm_id`, `model`, `uses`) VALUES
(1, 1, 531, 16),
(3, 1, 486, 3),
(4, 1, 486, 1),
(5, 1, 532, 0),
(10, 1, 403, 0);

-- --------------------------------------------------------

--
-- Table structure for table `fastfood`
--

CREATE TABLE `fastfood` (
  `ffID` int(11) NOT NULL,
  `ffName` varchar(32) NOT NULL DEFAULT '',
  `ffType` int(11) DEFAULT 1,
  `ffLocX` float DEFAULT 0,
  `ffLocY` float DEFAULT 0,
  `ffLocZ` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `fastfood`
--

INSERT INTO `fastfood` (`ffID`, `ffName`, `ffType`, `ffLocX`, `ffLocY`, `ffLocZ`) VALUES
(1, 'Pizza Stack', 1, 2102.94, -1806.71, 13.5547),
(2, 'Burger Shot', 2, 1214.53, -905.507, 42.6478),
(3, 'Burger Shot', 2, 799.88, -1630.01, 13.1099),
(4, 'Cluckin Bell', 3, 925.618, -1352.81, 13.3766),
(5, 'Cluckin Bell', 3, 2409.52, -1487.22, 23.5552),
(6, 'Eat my Donut', 4, 1038.07, -1338.63, 13.7266),
(7, 'Cluck\'in', 3, 2397.76, -1897.59, 13.5469);

-- --------------------------------------------------------

--
-- Table structure for table `gta_interiors`
--

CREATE TABLE `gta_interiors` (
  `gtaIntID` int(11) NOT NULL,
  `gtaIntInterior` int(11) NOT NULL DEFAULT 0,
  `gtaIntName` varchar(64) NOT NULL DEFAULT '',
  `gtaIntLocX` float NOT NULL DEFAULT 0,
  `gtaIntLocZ` float NOT NULL DEFAULT 0,
  `gtaIntLocY` float NOT NULL DEFAULT 0,
  `gtaIntFor` varchar(24) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `gta_interiors`
--

INSERT INTO `gta_interiors` (`gtaIntID`, `gtaIntInterior`, `gtaIntName`, `gtaIntLocX`, `gtaIntLocZ`, `gtaIntLocY`, `gtaIntFor`) VALUES
(1, 17, '24/7 1', -25.72, 1003.54, -187.82, 'shop'),
(2, 10, '24/7 2', 6.08, 1003.54, -28.89, 'shop'),
(3, 18, '24/7 3', -30.98, 1003.54, -89.68, 'shop'),
(4, 16, '24/7 4', -26.18, 1003.54, -140.91, 'shop'),
(5, 4, '24/7 5', -27.84, 1003.55, -26.67, 'shop'),
(6, 6, '24/7 6', -26.83, 1003.54, -55.58, 'shop'),
(7, 2, 'Loco Low Co.', 611.35, 997.99, -77.55, 'garage'),
(8, 3, 'Wheel Arch Angels', 612.21, 997.99, -123.9, 'garage'),
(9, 1, 'TransFender', 621.45, 1000.92, -23.72, 'garage'),
(10, 10, 'Four Dragons', 2016.11, 996.87, 1017.15, 'casino'),
(11, 12, 'Casino Floor (Redsands West)', 1133.34, 1000.67, -7.84, 'casino'),
(12, 1, 'Caligula\'s Casino', 2233.93, 1011.63, 1711.8, 'casino'),
(13, 1, 'Caligula\'s Roof', 2268.51, 1084.23, 1647.76, 'casino'),
(14, 5, 'Victim', 225.03, 1002.21, -9.18, 'shop'),
(15, 1, 'Sub Urban', 204.11, 1001.8, -46.8, 'shop'),
(16, 18, 'Zip', 161.4, 1001.8, -94.24, 'shop'),
(17, 14, 'Didier Sachs', 204.16, 1000.52, -165.76, 'shop'),
(18, 15, 'Binco', 207.52, 1005.13, -109.74, 'shop'),
(19, 3, 'Pro-Laps', 206.46, 1003.09, -137.7, 'shop'),
(20, 5, 'Pizza Stack', 372.55, 1001.49, -131.36, 'restaurant'),
(21, 17, 'Rusty Brown\'s Donuts', 378.02, 1000.63, -190.51, 'restaurant'),
(22, 10, 'Burger Shot', 366.02, 1001.5, -73.34, 'restaurant'),
(23, 9, 'Cluckin\' Bell', 366, 1001.85, -9.43, 'restaurant'),
(24, 11, 'Bar', 501.95, 998.75, -70.56, 'bar'),
(25, 18, 'Lil\' Probe Inn', -227.57, 27.76, 1401.55, 'bar'),
(26, 12, 'Barber shop 1', 411.97, 1001.89, -51.92, 'barber'),
(27, 2, 'Barber shop 2', 414.29, 1001.8, -18.8, 'barber'),
(28, 3, 'Barber shop 3', 418.46, 1001.8, -80.45, 'barber'),
(29, 3, 'Tattoo sarlor', -201.22, 1002.27, -43.24, 'tattoo'),
(30, 3, 'Sex shop', -100.26, 1000.71, -22.93, 'shop'),
(31, 3, 'Burglary house 1', 234.6, 1080.25, 1187.81, 'house'),
(32, 2, 'Burglary house 2', 225.57, 1082.14, 1240.06, 'house'),
(33, 1, 'Burglary house 3', 224.28, 1082.14, 1289.19, 'house'),
(34, 5, 'Burglary house 4', 239.28, 1080.99, 1114.19, 'house'),
(35, 15, 'Burglary house 5', 295.13, 1080.25, 1473.37, 'house'),
(36, 2, 'Burglary house 6', 446.62, 1084.3, 1397.73, 'house'),
(37, 5, 'Burglary house 7', 227.75, 1080.99, 1114.38, 'house'),
(38, 4, 'Burglary house 8', 261.11, 1080.25, 1287.21, 'house'),
(39, 10, 'Burglary house 9', 24.37, 1084.37, 1341.18, 'house'),
(40, 4, 'Burglary house 10', 221.67, 1082.6, 1142.49, 'house'),
(41, 4, 'Burglary house 11', -262.17, 1084.36, 1456.61, 'house'),
(42, 5, 'Burglary house 12', 22.86, 1084.42, 1404.91, 'house'),
(43, 5, 'Burglary house 13', 140.36, 1083.86, 1367.88, 'house'),
(44, 6, 'Burglary house 14', 234.28, 1084.21, 1065.22, 'house'),
(45, 6, 'Burglary house 15', -68.51, 1080.21, 1353.84, 'house'),
(46, 15, 'Burglary house 16', -285.25, 1084.37, 1471.19, 'house'),
(47, 8, 'Burglary house 17', -42.52, 1084.42, 1408.22, 'house'),
(48, 9, 'Burglary house 18', 84.92, 1083.85, 1324.29, 'house'),
(49, 9, 'Burglary house 19', 260.74, 1084.25, 1238.22, 'house'),
(50, 15, 'Burglary house 20', 327.8, 1084.43, 1479.74, 'house'),
(51, 15, 'Burglary house 21', 295.46, 1080.26, 1474.69, 'house'),
(52, 8, 'Burglary house 22', -42.49, 1084.43, 1407.64, 'house'),
(53, 15, 'Burglary house 23', 375.57, 1081.33, 1417.44, 'house'),
(54, 7, 'Ammu-nation 1', 315.24, 999.6, -140.88, 'ammunation'),
(55, 1, 'Ammu-nation 2', 285.83, 1001.51, -39.01, 'ammunation'),
(56, 4, 'Ammu-nation 3', 291.76, 1001.51, -80.13, 'ammunation'),
(57, 6, 'Ammu-nation 4', 297.14, 1001.51, -109.87, 'ammunation'),
(58, 6, 'Ammu-nation 5', 316.5, 999.59, -167.62, 'ammunation'),
(59, 3, 'The Johnson house', 2496.05, 1014.74, -1695.17, 'house'),
(60, 2, 'Angel Pine trailer', 1.18, 999.42, -3.23, 'house'),
(61, 10, 'Abandoned AC tower', 419.89, 10, 2537.11, 'misc'),
(62, 14, 'Wardrobe/Changing room', 256.9, 1002.02, -41.65, 'wardrobe'),
(63, 1, 'The Camel\'s Toe safehouse', 2216.12, 1050.48, -1076.3, 'safehouse'),
(64, 8, 'Verdant Bluffs safehouse', 2365.1, 1050.87, -1133.07, 'safehouse'),
(65, 11, 'Willowfield safehouse', 2282.97, 1050.89, -1140.28, 'safehouse'),
(66, 5, 'Vank Hoff Hotel', 2233.69, 1050.88, -1112.81, 'hotel'),
(67, 9, 'Unknown safe house', 2319.12, 1050.21, -1023.95, 'safehouse'),
(68, 10, 'Safe House 1', 2262.83, 1050.63, -1137.71, 'safehouse'),
(69, 8, 'Safe House 2', 2365.24, 1050.88, -1134.3, 'safehouse'),
(70, 6, 'Safe House 3', 2333.03, 1049.1, -1073.96, 'safehouse'),
(71, 1, 'Safe House 4', 2216.54, 1050.5, -1076.29, 'safehouse'),
(72, 6, 'Safe House 5', 2194.29, 1049.1, -1204.02, 'safehouse'),
(73, 6, 'Safe House 6', 2308.87, 1049.1, -1210.78, 'safehouse'),
(74, 12, 'Safe House 7', 2324.38, 1050.71, -1148.48, 'safehouse'),
(75, 1, 'Denise\'s house', 245.23, 999.14, 304.76, 'house'),
(76, 3, 'Helena\'s barn', 290.62, 999.14, 309.06, 'house'),
(77, 5, 'Barbara\'s house', 322.5, 999.14, 303.69, 'house'),
(78, 2, 'Katie\'s house', 269.64, 999.14, 305.95, 'house'),
(79, 4, 'Michelle\'s house', 306.19, 1003.3, 307.81, 'house'),
(80, 3, 'Planning Department', 386.52, 1008.38, 173.63, 'government'),
(81, 6, 'Los Santos Police Department', 246.66, 1003.64, 65.8, 'police'),
(82, 3, 'Las Venturas Police Department', 288.47, 1007.17, 170.06, 'police'),
(83, 10, 'San Fierro Police Department', 246.06, 1003.21, 108.97, 'police'),
(84, 1, 'Oval Stadium', -1402.66, 1032.27, 106.38, 'stadium'),
(85, 16, 'Vice Stadium', -1401.06, 1039.86, 1265.37, 'stadium'),
(86, 15, 'Blood Bowl Stadium', -1417.89, 1041.53, 932.44, 'stadium'),
(87, 3, 'Bike school', 1494.85, 1093.29, 1306.47, 'school'),
(88, 3, 'Driving school', -2031.11, 1035.17, -115.82, 'school'),
(89, 5, 'Ganton Gym', 770.8, 1000.72, -0.7, 'gym'),
(90, 6, 'Cobra Gym', 773.88, 1000.58, -47.76, 'gym'),
(91, 7, 'Below The Belt Gym', 773.73, 1000.65, -74.69, 'gym'),
(92, 3, 'Brothel 1', 974.01, 1001.14, -9.59, 'brothel'),
(93, 3, 'Brothel 2', 961.93, 1001.11, -51.9, 'brothel'),
(94, 3, 'The Big Spread Ranch', 1212.14, 1000.95, -28.53, 'house'),
(95, 2, 'The Pig Pen', 1204.66, 1000.92, -13.54, 'house'),
(96, 17, 'Club', 493.14, 1000.67, -24.26, 'club'),
(97, 6, 'Fanny Batter\'s Whore House', 748.46, 1102.95, 1438.23, 'brothel'),
(98, 18, 'Warehouse 1', 1290.41, 1001.02, 1.95, 'warehouse'),
(99, 1, 'Warehouse 2', 1412.14, 1000.92, -2.28, 'warehouse'),
(100, 3, 'Inside Track Betting', 830.6, 1004.17, 5.94, 'betting'),
(101, 3, 'Blastin\' Fools Records', 1037.82, 1001.28, 0.39, 'shop'),
(102, 3, 'B Dup\'s Apartment', 1527.04, 1002.09, -12.02, 'house'),
(103, 2, 'B Dup\'s Crack Palace', 1523.5, 1002.26, -47.82, 'house'),
(104, 3, 'OG Loc\'s House', 512.92, 1001.56, -11.69, 'house'),
(105, 2, 'Ryder\'s house', 2447.87, 1013.5, -1704.45, 'house'),
(106, 1, 'Sweet\'s House', 2527.01, 1015.49, -1679.2, 'house'),
(107, 1, 'Wu-Zi Mu\'s', -2158.67, 1052.37, 642.09, 'restaurant'),
(108, 14, 'Los Santos Airport', -1864.94, 1055.52, 55.73, 'airport'),
(109, 10, 'Four Dragons\' Janitor\'s Office', 1893.07, 31.88, 1017.89, 'misc'),
(110, 15, 'Jefferson Motel', 2217.28, 1025.79, -1150.53, 'hotel'),
(111, 14, 'Kickstart Stadium', -1420.42, 1052.53, 1616.92, 'stadium'),
(112, 1, 'Liberty City', -741.84, 1371.97, 493, 'misc'),
(113, 14, 'Francis International Airport', -1813.21, 1058.96, -58.01, 'airport'),
(114, 3, 'The Pleasure Domes', -2638.82, 906.46, 1407.33, 'club'),
(115, 10, 'RC Battlefield', -1129.89, 1346.41, 1057.54, 'misc'),
(116, 1, 'San Fierro Garage', -2041.23, 28.84, 178.39, 'garage'),
(117, 1, 'The Welcome Pump', 681.62, -25.61, -451.89, 'bar'),
(118, 7, '8-Track Stadium', -1403.01, 1043.53, -250.45, 'stadium'),
(119, 4, 'Dirtbike Stadium', -1421.56, 1059.55, -663.82, 'stadium'),
(120, 5, 'Crack Den', 322.11, 1083.88, 1119.32, 'house'),
(121, 2, 'Big Smoke\'s Crack Palace', 2536.53, 1044.12, -1294.84, 'house'),
(122, 6, 'Zero\'s RC Shop', -2240.1, 1035.41, 136.97, 'shop'),
(123, 17, 'Sherman Dam', -944.24, 5, 1886.15, 'misc'),
(124, 2, 'Rosenberg\'s Office', 2182.2, 1043.87, 1628.58, 'office'),
(125, 6, 'Secret Valley Diner', 442.12, 999.71, -52.47, 'restaurant'),
(126, 1, 'World of Coq', 445.6, 1000.73, -6.98, 'restaurant'),
(127, 5, 'Jays Diner', 454.98, 999.43, -107.25, 'restaurant'),
(128, 5, 'Madd Dogg\'s Mansion', 1267.84, 1091.9, -776.95, 'house'),
(129, 8, 'Colonel Furhberger\'s', 2807.36, 1025.57, -1171.7, 'restaurant'),
(130, 5, 'Burning Desire Building', 2350.15, 1027.97, -1181.06, 'office'),
(131, 18, 'Atrium', 1727.28, 20.22, -1642.94, 'misc'),
(132, 1, 'Sindacco Abatoir', 963.05, 1011.03, 2159.75, 'misc'),
(133, 1, 'Jet Interior', 1.54, 1199.59, 23.31, 'vehicle'),
(134, 9, 'Andromada', 315.45, 1960.85, 976.59, 'vehicle'),
(135, 0, 'Palomino Bank', 2306.38, 26.74, -15.23, 'bank'),
(136, 0, 'Dillimore Gas Station', 663.05, 16.33, -573.62, 'gas_station'),
(137, 2, 'Random House', 2236.69, 1049.02, -1078.94, 'house'),
(138, 12, 'Budget Inn Motel Room', 446.32, 1001.41, 509.96, 'hotel');

-- --------------------------------------------------------

--
-- Table structure for table `hotels`
--

CREATE TABLE `hotels` (
  `id` int(11) NOT NULL,
  `name` varchar(32) DEFAULT 'Hotel',
  `owner` varchar(24) DEFAULT '',
  `owner_id` int(11) DEFAULT 0,
  `owned` tinyint(4) DEFAULT 0,
  `is_for_sale` tinyint(4) DEFAULT 0,
  `price` int(11) DEFAULT 50000,
  `loc_x` float DEFAULT 0,
  `loc_y` float DEFAULT 0,
  `loc_z` float DEFAULT 0,
  `bank` int(11) DEFAULT 0,
  `is_rentable` tinyint(4) DEFAULT 0,
  `rent_price` int(11) DEFAULT 0,
  `renter_id` int(11) DEFAULT 0,
  `capacity` int(11) DEFAULT 5
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `hotels`
--

INSERT INTO `hotels` (`id`, `name`, `owner`, `owner_id`, `owned`, `is_for_sale`, `price`, `loc_x`, `loc_y`, `loc_z`, `bank`, `is_rentable`, `rent_price`, `renter_id`, `capacity`) VALUES
(1, 'Hotel 1', 'Punctulet', 1, 1, 0, 50000, 1519.15, -1451.87, 14.2031, 100, 0, 0, 0, 2),
(2, 'Hotel 2', '', 0, 0, 1, 50000, 1332.36, -985.285, 33.8966, 0, 0, 0, 0, 5),
(3, 'Hotel 3', '', 0, 0, 1, 50000, 1023.82, -981.757, 42.6307, 0, 0, 0, 0, 5),
(4, 'Hotel 4', '', 0, 0, 1, 50000, 952.886, -911.671, 45.7656, 0, 0, 0, 0, 5),
(5, 'Hotel 5', '', 0, 0, 1, 50000, 609.042, -1459.49, 14.3925, 0, 0, 0, 0, 5),
(6, 'Hotel 6', '', 0, 0, 1, 50000, 867.5, -1797.06, 13.8064, 0, 0, 0, 0, 5),
(7, 'Hotel 7', '', 0, 0, 1, 50000, 1420.61, -1624.06, 13.5469, 0, 0, 0, 0, 5),
(8, 'Hotel 8', '', 0, 0, 1, 50000, 2379.09, -1197.2, 27.4223, 0, 0, 0, 0, 5),
(9, 'Hotel 9', '', 0, 0, 1, 50000, 2657.86, -1392.55, 30.4246, 0, 0, 0, 0, 5),
(10, 'Hotel 10', '', 0, 0, 1, 50000, 2752.48, -1962.53, 13.5469, 75, 0, 0, 0, 5),
(12, 'San Andreas Motel', '', 0, 0, 1, 50000, 2178.44, -1770.24, 13.5453, 0, 0, 0, 0, 5);

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
  `loc_z` float DEFAULT 0,
  `type` int(11) DEFAULT 1,
  `max_pets` int(11) DEFAULT 0,
  `pets` int(11) DEFAULT 0,
  `has_fridge` int(11) DEFAULT 0,
  `fridge_milk` int(11) DEFAULT 0,
  `fridge_banana` int(11) DEFAULT 0,
  `fridge_water` int(11) DEFAULT 0,
  `fridge_juice` int(11) DEFAULT 0,
  `fridge_beer` int(11) DEFAULT 0,
  `bank` int(11) DEFAULT 0,
  `is_for_sale` tinyint(4) DEFAULT 0,
  `sgr` int(11) DEFAULT 0,
  `trash` int(11) DEFAULT 0,
  `has_bed` int(11) DEFAULT 0,
  `fridge_expire` int(11) DEFAULT 0,
  `bed_expire` int(11) DEFAULT 0,
  `interior` int(11) DEFAULT 0,
  `int_x` float DEFAULT 0,
  `int_z` float DEFAULT 0,
  `int_y` float DEFAULT 0,
  `tree_id` int(11) DEFAULT 0,
  `default_price` int(11) DEFAULT 50000,
  `issue` int(11) DEFAULT 0,
  `is_rentable` tinyint(4) DEFAULT 0,
  `rent_price` int(11) DEFAULT 0,
  `renter_id` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `houses`
--

INSERT INTO `houses` (`id`, `name`, `owner`, `owner_id`, `owned`, `price`, `loc_x`, `loc_y`, `loc_z`, `type`, `max_pets`, `pets`, `has_fridge`, `fridge_milk`, `fridge_banana`, `fridge_water`, `fridge_juice`, `fridge_beer`, `bank`, `is_for_sale`, `sgr`, `trash`, `has_bed`, `fridge_expire`, `bed_expire`, `interior`, `int_x`, `int_z`, `int_y`, `tree_id`, `default_price`, `issue`, `is_rentable`, `rent_price`, `renter_id`) VALUES
(1, 'Gara', 'Punctulet', 1, 1, 2000000, 666.914, -1880.77, 5.46, 4, 5, 0, 1, 20, 10, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1787769497, 2, 225.57, 1082.14, 1240.06, 4, 2000000, 0, 1, 0, 0),
(2, 'Fort Carson Backroads #1', '', 0, 0, 2000000, 745.359, -555.508, 18.0129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(3, 'Fort Carson Backroads #2', '', 0, 0, 2000000, 768.306, -504.694, 18.0129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(4, 'Fort Carson Backroads #3', '', 0, 0, 2000000, 794.73, -507.133, 18.0129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(5, 'Tiera Rabada Ridgehouse #1', '', 0, 0, 2000000, 818.428, -510.284, 18.0129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(6, 'Tiera Rabada Ridgehouse #2', '', 0, 0, 2000000, 314.3, -121.157, 3.5354, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(7, 'Tiera Robada Ridgehouse #3', '', 0, 0, 2000000, 251.379, -92.3421, 3.5354, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(8, 'Tiera Robada Ridgehouse #4', '', 0, 0, 2000000, 2362.03, 141.95, 28.4453, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(9, 'Bone County #1', '', 0, 0, 2000000, 2325.58, 136.442, 28.4453, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(10, 'Bone County #2', '', 0, 0, 2000000, 2413.75, 60.2364, 28.4416, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(11, 'Mediterranean House #1', '', 0, 0, 2000000, 794.524, -1707.41, 14.0382, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(12, 'Mediterranean House #2', '', 0, 0, 2000000, 768.161, -1696.33, 5.1554, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(13, 'Mediterranean House #3', '', 0, 0, 2000000, 695.109, -1645.95, 4.0512, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(14, 'Mediterranean House #4', '', 0, 0, 2000000, 653.058, -1714.28, 14.7648, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(15, 'Beach house #1', '', 0, 0, 2000000, 316.218, -1770.34, 4.6583, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(16, 'Beach house #2', '', 0, 0, 2000000, 168.107, -1769.14, 4.4754, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(17, 'Beach house #3', '', 0, 0, 2000000, 207.245, -1770.62, 4.3305, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(18, 'Vinewood house #1', '', 0, 0, 2000000, 142.958, -1468.92, 25.2036, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(19, 'Vinewood house #2', '', 0, 0, 2000000, 255.26, -1366.15, 53.1094, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(20, 'Vinewood house #3', '', 0, 0, 2000000, 297.848, -1337.25, 53.4415, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(21, 'Vinewood house #4', '', 0, 0, 2000000, 190.46, -1308.48, 70.2665, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(22, 'Vinewood house #5', '', 0, 0, 2000000, 252.203, -1220.89, 75.758, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(23, 'Vinewood house #6', '', 0, 0, 2000000, 300.077, -1154.78, 81.2348, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(24, 'Vinewood house #7', '', 0, 0, 2000000, 698.804, -1059.31, 49.4217, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(25, 'Vinewood house #8', '', 0, 0, 2000000, 828.259, -858.827, 70.3308, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(26, 'Vinewood house #9', '', 0, 0, 2000000, 1111.49, -741.719, 100.133, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(27, 'Vinewood house #10', '', 0, 0, 2000000, 1331.22, -631.938, 109.135, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(28, 'Vinewood house #11', '', 0, 0, 2000000, 1496.77, -688.856, 95.2339, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(29, 'Vinewood house #12', '', 0, 0, 2000000, 1468.96, -904.904, 54.8359, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(30, 'Vinewood house #13', '', 0, 0, 2000000, 1421.92, -885.593, 50.663, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(31, 'PnS Appartment #1', '', 0, 0, 2000000, 1050.95, -1057.88, 34.7969, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(32, 'PnS Appartment #2', '', 0, 0, 2000000, 993.673, -1057.93, 33.7031, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(33, 'PnS Appartment #3', '', 0, 0, 2000000, 1118.1, -1023.43, 34.9922, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(34, 'Temple Appartment #1', '', 0, 0, 2000000, 1190.18, -1018.13, 32.5469, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(35, 'Temple Appartment #2', '', 0, 0, 2000000, 1195.13, -1010.47, 36.2267, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(36, 'Temple Appartment #3', '', 0, 0, 2000000, 1195.31, -1017.02, 36.2344, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(37, 'Temple Appartment #4', '', 0, 0, 2000000, 1227.62, -1017.43, 36.3359, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(38, 'Temple Appartment #5', '', 0, 0, 2000000, 1242.47, -1075.08, 31.5547, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(39, 'Temple Appartment #6', '', 0, 0, 2000000, 1242.5, -1077.82, 31.5547, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(40, 'Temple Appartment #7', '', 0, 0, 2000000, 1285, -1088.74, 28.2578, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(41, 'Temple Appartment #8', '', 0, 0, 2000000, 1320.45, -1082.16, 25.5954, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0),
(42, 'Temple Appartment #9', '', 0, 0, 2000000, 1326.84, -1098.43, 25.4001, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `houses_animals`
--

CREATE TABLE `houses_animals` (
  `aID` int(11) NOT NULL,
  `aType` int(11) DEFAULT 0,
  `aPlayerID` int(11) DEFAULT 0,
  `aHouseID` int(11) DEFAULT 0,
  `aName` varchar(32) NOT NULL DEFAULT 'Animal',
  `aDefaultName` varchar(32) NOT NULL DEFAULT 'Animal',
  `aAge` int(11) DEFAULT 0,
  `aDeceased` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `houses_animals`
--

INSERT INTO `houses_animals` (`aID`, `aType`, `aPlayerID`, `aHouseID`, `aName`, `aDefaultName`, `aAge`, `aDeceased`) VALUES
(1, 1609, 1, 1, 'Ronal', 'Turtle', 6, 0),
(2, 19833, 1, 1, 'Dinio', 'Cow', 6, 0);

-- --------------------------------------------------------

--
-- Table structure for table `houses_tree`
--

CREATE TABLE `houses_tree` (
  `treeId` int(11) NOT NULL,
  `treeHouseId` int(11) DEFAULT 0,
  `treeType` int(11) DEFAULT 0,
  `treeName` varchar(32) NOT NULL DEFAULT 'Tree',
  `treePlantedDate` int(11) DEFAULT 0,
  `treeFruitStatus` int(11) DEFAULT 0,
  `treeLocX` float DEFAULT 0,
  `treeLocY` float DEFAULT 0,
  `treeLocZ` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `houses_tree`
--

INSERT INTO `houses_tree` (`treeId`, `treeHouseId`, `treeType`, `treeName`, `treePlantedDate`, `treeFruitStatus`, `treeLocX`, `treeLocY`, `treeLocZ`) VALUES
(4, 1, 0, 'Tree', 1785263901, 21, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `locations_admin`
--

CREATE TABLE `locations_admin` (
  `locID` int(11) NOT NULL,
  `locName` varchar(32) NOT NULL DEFAULT '',
  `locX` float DEFAULT 0,
  `locY` float DEFAULT 0,
  `locZ` float DEFAULT 0,
  `locDescr` varchar(64) NOT NULL DEFAULT '',
  `interiorID` int(11) DEFAULT 0,
  `vwID` int(11) DEFAULT 0,
  `locForGPS` tinyint(1) DEFAULT 0,
  `locCategory` varchar(32) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `locations_admin`
--

INSERT INTO `locations_admin` (`locID`, `locName`, `locX`, `locY`, `locZ`, `locDescr`, `interiorID`, `vwID`, `locForGPS`, `locCategory`) VALUES
(1, 'examA', 2481.84, -1536.6, 24.0963, 'Examen A - start (/examA)', 0, 0, 1, 'Licence'),
(2, 'examB', 477.753, -1501.13, 20.5292, 'Examen B - start (/examB)', 0, 0, 1, 'Licence'),
(3, 'examC', 2381.53, -2072.59, 13.4935, 'Examen C - start (/examC)', 0, 0, 1, 'Licence'),
(4, 'examD', 1753.71, -1902.55, 13.5631, 'Examen D - start (/examD)', 0, 0, 1, 'Licence'),
(5, 'examP', 1525.5, -2433.17, 13.5547, 'Examen Licenta pilotaj Avioane (plane)', 0, 0, 1, 'Licence'),
(6, 'examH', 1606.38, -2433.17, 13.5547, 'Examen licenta pilotaj elicoptere (Helicopter)', 0, 0, 1, 'Licence'),
(7, 'Golf', 1407.91, 2788.75, 11, 'Terenul de Golf LV', 0, 0, 1, 'Fun'),
(8, 'Basket', 2298.31, -1501.99, 25.3047, '', 0, 0, 1, 'Fun'),
(9, 'lodge', -688.106, 949.078, 12.5, '', 0, 0, 1, 'Fun'),
(11, 'PR/duty', 256.123, 65.5168, 1003.64, 'PR - /duty', 6, 0, 0, ''),
(12, 'jail', 267.748, 77.754, 1001.1, 'Interior JAIL', 6, 0, 0, ''),
(13, 'PR/arrest-int', 268.416, 77.7611, 1001.04, 'Comanda /arrest la interior', 6, 0, 0, ''),
(14, 'PR/arrest-ext', 1568.48, -1691.7, 5.89, 'Comanda /arrest din exterior(garaj) JAIL', 0, 0, 0, ''),
(15, 'Vehicle Plate', 867.269, -1205.11, 16.9766, 'Change Vehicle Plate', 0, 0, 1, 'Vehicle'),
(16, 'Vehicle ITP', 831.053, -1205.11, 16.9766, 'Change Vehicle ITP', 0, 0, 1, 'Vehicle'),
(18, 'police_int_to_ext', 246.7, 63.4, 1003.64, 'Police Interior to Exterior', 6, 0, 0, ''),
(19, 'police_int_to_garage', 243.243, 66.3187, 1003.64, 'Police Interior to Garage', 6, 0, 0, ''),
(20, 'police_garage_to_int', 1525.42, -1677.74, 5.91, 'Police Garage to Interior', 0, 0, 0, ''),
(21, 'police_ext_to_int', 1554.2, -1675.9, 16.25, 'Police Exterior to Interior', 0, 0, 0, ''),
(22, 'Hospital', 1173.34, -1361.26, 13.9678, 'Spital - internare (/curedisease)', 0, 0, 1, 'Others'),
(23, 'Hospital2', 2033.96, -1403.3, 17.28, 'Spital 2 - internare (/curedisease)', 0, 0, 1, 'Others'),
(24, 'Hunting', -418.372, -1759.68, 6.2188, 'Hunt deer with /hunt', 0, 0, 1, 'Fun'),
(29, 'Church', 946.235, -1103.36, 24.2742, 'Biserica Los Santos', 0, 0, 1, 'Other'),
(30, 'Casino', 1022.57, -1122.42, 23.8713, 'Casino - Entrace', 0, 0, 1, 'Fun'),
(31, 'SGR', 2411.85, -1426.5, 23.7, 'Sell your SGR.', 0, 0, 1, 'Others'),
(32, 'Trash unload', 2122.97, -2015.28, 13.6, 'Trash unload point', 0, 0, 1, 'Others'),
(33, 'ANAF', 1765.24, -1343.33, 915.75, 'ANAF /biz givedocs', 0, 0, 1, 'ANAF'),
(40, 'examW', 1883.87, -1270.38, 13.54, 'Examen W - start (/examW)', 0, 0, 1, 'Licence'),
(50, 'ad W LS', 914.5, -1003.31, 38, 'Locatie pentru /ad West LS', 0, 0, 1, 'CNN'),
(51, 'ad S LS', 1448.95, -2286.96, 13.54, 'Locatie pentru /ad South LS', 0, 0, 1, 'CNN'),
(52, 'ad E LS', 1853.65, -1145.18, 23.85, 'Locatie /ad East LS', 0, 0, 0, 'CNN'),
(55, 'Arrest Me', 1798.31, -1578.39, 14.08, '/arrestme if wanted 2+, and no cops on-duty', 0, 0, 1, 'Other'),
(100, 'lspd_barrier', 1544.7, -1630.9, 13.24, 'Bariera LSPD (horn factiune 1)', 0, 0, 0, ''),
(101, 'Job Glovo Delivery', 2390, 1667, 11, 'Starting point of job Glovo Delivery', 0, 0, 1, 'Job'),
(102, 'Job Cement Truck Driver', 334.625, 871.524, 20.4063, 'Starting point of job Cement Truck Driver', 0, 0, 1, 'Job'),
(103, 'Job Gun Delivery', 2501.69, -2618.84, 13.7147, 'Starting point of job Gun Delivery', 0, 0, 1, 'Job'),
(104, 'Job Car Transportator', 1984.05, -2065.85, 14.0127, 'Starting point of job Car Transportator', 0, 0, 1, 'Job'),
(899, 'Cityhall', 1481.22, -1771.37, 18.7958, 'City Hall - exterior (intrare)', 0, 0, 1, 'Others'),
(900, 'cityhall_int', 386.52, 173.63, 1008.38, 'City Hall - interior', 0, 0, 0, ''),
(901, 'GetJob', 358.421, 182.193, 1008.38, 'Job Center - angajare (/getjob)', 0, 0, 0, ''),
(902, 'QuitJob', 359.265, 166.433, 1008.38, 'Job Center - demisie (/quitjob)', 0, 0, 0, ''),
(909, 'Job Uber', 1481.22, -1771.37, 18.7958, 'Starting point of job Uber', 0, 0, 1, 'Job'),
(910, 'Job Emergency Logistics Driver', 1110.27, -1225.35, 15.807, 'Starting point of job Emergency Logistics Driver', 0, 0, 1, 'Job'),
(911, 'Job Bus Driver', 1411.4, -2310.66, 13.6462, 'Starting point of job Bus Driver', 0, 0, 1, 'Job'),
(912, 'Job Electrician', 2692.75, -1961.36, 13.6393, 'Starting point of job Electrician', 0, 0, 1, 'Job'),
(913, 'Job Crop Duster Pilot', 1948.76, -2645.63, 14.9193, 'Crop Duster Pilot job depot', 0, 0, 1, 'Job');

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
  `house` int(11) DEFAULT 0,
  `spawn_type` int(11) DEFAULT 1,
  `faction_rank` int(11) DEFAULT 1,
  `key1` int(11) DEFAULT 0,
  `key2` int(11) DEFAULT 0,
  `key3` int(11) DEFAULT 0,
  `faction_join` date DEFAULT NULL,
  `business` int(11) DEFAULT 0,
  `driving_lic_a_exp` date DEFAULT NULL,
  `driving_lic_b_exp` date DEFAULT NULL,
  `driving_lic_c_exp` date DEFAULT NULL,
  `driving_lic_d_exp` date DEFAULT NULL,
  `diseased` tinyint(4) DEFAULT 0,
  `disease_paydays` int(11) DEFAULT 0,
  `caravan_key` int(11) DEFAULT 0,
  `is_president` tinyint(4) DEFAULT 0,
  `voted` tinyint(4) DEFAULT 0,
  `was_president` tinyint(4) DEFAULT 0,
  `job` int(11) DEFAULT 0,
  `phone_model` int(11) DEFAULT -1,
  `phone_number` int(11) DEFAULT 0,
  `medkits` int(11) DEFAULT 0,
  `extinguishers` int(11) DEFAULT 0,
  `mute_expire` int(11) DEFAULT 0,
  `airplane_lic_a_exp` date DEFAULT NULL,
  `airplane_lic_h_exp` date DEFAULT NULL,
  `wanted_level` int(11) DEFAULT 0,
  `jail_seconds` int(11) DEFAULT 0,
  `rob_points` int(11) DEFAULT 10,
  `skin` int(11) DEFAULT 7,
  `gas_can` int(11) DEFAULT -1,
  `watch_model` int(11) DEFAULT -1,
  `phone_expire` int(11) DEFAULT 0,
  `tired` int(11) DEFAULT 0,
  `hotel` int(11) DEFAULT 0,
  `rent_house` int(11) DEFAULT 0,
  `rent_hotel` int(11) DEFAULT 0,
  `warns` int(11) DEFAULT 0,
  `watch_expire` date DEFAULT NULL,
  `weapon_lic_w_exp` date DEFAULT NULL,
  `vip` tinyint(4) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `players`
--

INSERT INTO `players` (`id`, `username`, `password`, `email`, `level`, `money`, `bank`, `rp`, `admin_level`, `faction`, `house`, `spawn_type`, `faction_rank`, `key1`, `key2`, `key3`, `faction_join`, `business`, `driving_lic_a_exp`, `driving_lic_b_exp`, `driving_lic_c_exp`, `driving_lic_d_exp`, `diseased`, `disease_paydays`, `caravan_key`, `is_president`, `voted`, `was_president`, `job`, `phone_model`, `phone_number`, `medkits`, `extinguishers`, `mute_expire`, `airplane_lic_a_exp`, `airplane_lic_h_exp`, `wanted_level`, `jail_seconds`, `rob_points`, `skin`, `gas_can`, `watch_model`, `phone_expire`, `tired`, `hotel`, `rent_house`, `rent_hotel`, `warns`, `watch_expire`, `weapon_lic_w_exp`, `vip`) VALUES
(1, 'Punctulet', '112', '', 2, 517597, 27167268, 60, 6, 3, 1, 2, 5, 1, 2, 4, NULL, 0, '2030-12-31', '2030-12-31', '2030-12-31', '2030-12-31', 0, 2, 1, 0, 0, 0, 7, 3, 79640, 0, 0, 0, '2030-12-31', '2030-12-31', 0, 1429, 10, 302, -1, 3, 0, 100, 1, 0, 0, 0, NULL, '0000-00-00', 1),
(3, 'Punctulet2', '', '', 1, 3347738, 446669, 4, 6, 5, 0, 2, 5, 0, 0, 0, NULL, 0, '2026-06-30', '2026-06-30', '0000-00-00', '0000-00-00', 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, NULL, NULL, 0, 0, 10, 7, -1, -1, 0, 0, 0, 0, 0, 0, NULL, NULL, 0),
(28, 'Punctulet3', '112', '', 3, 3333, 3333, 3, 3, 6, 0, 1, 2, 0, 0, 0, '0000-00-00', 0, '2030-12-31', '2030-12-31', '2030-12-31', '2030-12-31', 0, 0, 0, 0, 0, 0, 0, 3, 3333, 0, 0, 0, '2030-12-31', '2030-12-31', 0, 0, 0, 199, -1, 3, 0, 0, 0, 0, 0, 0, '2026-09-04', NULL, 0),
(29, 'Punctulet4', '112', '', 4, 4444, 4444, 4, 4, 0, 0, 1, 1, 0, 0, 0, NULL, 0, '2030-12-31', '2030-12-31', '2030-12-31', '2030-12-31', 0, 0, 0, 0, 0, 0, 0, 2, 4444, 0, 0, 0, '2030-12-31', '2030-12-31', 0, 0, 0, 199, -1, 3, 0, 0, 0, 0, 0, 0, '2026-09-04', NULL, 0);

-- --------------------------------------------------------

--
-- Table structure for table `player_skins`
--

CREATE TABLE `player_skins` (
  `id` int(11) NOT NULL,
  `player_id` int(11) NOT NULL,
  `skin_id` int(11) NOT NULL,
  `qty` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `player_skins`
--

INSERT INTO `player_skins` (`id`, `player_id`, `skin_id`, `qty`) VALUES
(1, 1, 7, 15),
(2, 1, 302, 1);

-- --------------------------------------------------------

--
-- Table structure for table `president_votes`
--

CREATE TABLE `president_votes` (
  `vID` int(11) NOT NULL,
  `vVotant` varchar(24) NOT NULL DEFAULT '',
  `vVotantId` int(11) DEFAULT 0,
  `vVotatPe` varchar(24) NOT NULL DEFAULT '',
  `vVotatPeId` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `races`
--

CREATE TABLE `races` (
  `rID` int(11) NOT NULL,
  `rName` varchar(16) NOT NULL,
  `rVehModelID` int(11) NOT NULL,
  `rTimeRecord` float DEFAULT 999,
  `rPlayerName` varchar(24) DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `races`
--

INSERT INTO `races` (`rID`, `rName`, `rVehModelID`, `rTimeRecord`, `rPlayerName`) VALUES
(1, 'Lap1', 541, 999, ''),
(2, 'Lap2', 541, 999, ''),
(3, 'Lap3', 541, 999, ''),
(4, 'Lap1', 411, 999, ''),
(5, 'Lap2', 411, 999, ''),
(6, 'Lap3', 411, 999, ''),
(7, 'Lap1', 562, 48.64, 'Punctulet'),
(8, 'Lap2', 562, 999, ''),
(9, 'Lap3', 562, 999, ''),
(10, 'Lap1', 560, 999, ''),
(11, 'Lap2', 560, 999, ''),
(12, 'Lap3', 560, 999, ''),
(13, 'Lap1', 522, 999, ''),
(14, 'Lap2', 522, 106.84, 'Punctulet'),
(15, 'Lap3', 522, 999, ''),
(16, 'Lap1', 475, 999, ''),
(17, 'Lap2', 475, 999, ''),
(18, 'Lap3', 475, 999, '');

-- --------------------------------------------------------

--
-- Table structure for table `reports`
--

CREATE TABLE `reports` (
  `repID` int(11) NOT NULL,
  `playerName` varchar(24) NOT NULL DEFAULT '',
  `playerDbId` int(11) DEFAULT 0,
  `repText` varchar(160) NOT NULL DEFAULT '',
  `repDate` int(11) DEFAULT 0,
  `status` int(11) DEFAULT 0,
  `adminName` varchar(24) NOT NULL DEFAULT '',
  `reply` varchar(160) NOT NULL DEFAULT '',
  `replyDelivered` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
  `rType` int(11) DEFAULT 1,
  `rSize` float DEFAULT 6.49,
  `rWeight` int(11) DEFAULT 900,
  `rName` varchar(16) NOT NULL DEFAULT 'Small'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rulote_personale`
--

INSERT INTO `rulote_personale` (`rID`, `rOwned`, `rOwner`, `rPrice`, `rCamping`, `rCampingStartDate`, `rParkLocX`, `rParkLocY`, `rParkLocZ`, `rCampLocX`, `rCampLocY`, `rCampLocZ`, `parkRX`, `parkRY`, `parkRZ`, `campRX`, `campRY`, `campRZ`, `rType`, `rSize`, `rWeight`, `rName`) VALUES
(1, 1, 1, 0, 0, NULL, 807.597, -1348.06, 12.7711, 0, 0, 0, 0.0224, 0.1003, -244.847, 0, 0, 0, 1, 6.49, 900, 'Small');

-- --------------------------------------------------------

--
-- Table structure for table `server_setup`
--

CREATE TABLE `server_setup` (
  `ssId` int(11) NOT NULL,
  `ssSetare` varchar(40) DEFAULT NULL,
  `ssValue` varchar(24) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `server_setup`
--

INSERT INTO `server_setup` (`ssId`, `ssSetare`, `ssValue`) VALUES
(1, 'min_salary', '2500'),
(2, 'tax', '10'),
(3, 'cass', '10'),
(4, 'bank_interest', '0.05'),
(5, 'insurance_price', '500'),
(6, 'medkit_price', '500'),
(7, 'extinguisher_price', '500'),
(8, 'gascan_price', '500'),
(9, 'itp_price', '750'),
(10, 'plate_price', '250'),
(11, 'rent_bike_price', '15'),
(12, 'exam_a_price', '200'),
(13, 'exam_b_price', '300'),
(14, 'exam_c_price', '500'),
(15, 'exam_d_price', '400'),
(16, 'exam_p_price', '800'),
(17, 'exam_h_price', '900'),
(18, 'pizza_price', '50'),
(19, 'burger_price', '55'),
(20, 'meal_price', '60'),
(21, 'desert_price', '30'),
(22, 'farm_tractor_price', '10000'),
(23, 'farm_dozer_price', '15000'),
(24, 'farm_combine_price', '20000'),
(25, 'farm_truck_price', '12500'),
(26, 'farm_trailer_price', '10000'),
(27, 'shovel_price', '2500'),
(28, 'phone_sim_price', '250'),
(29, 'phone_price_1', '1000'),
(30, 'phone_price_2', '2000'),
(31, 'phone_price_3', '1600'),
(32, 'phone_price_4', '2200'),
(33, 'phone_price_5', '500'),
(34, 'watch_price_1', '300'),
(35, 'watch_price_2', '700'),
(36, 'watch_price_3', '1000'),
(37, 'watch_price_4', '10000'),
(64, 'weapon_colt45_price', '5000'),
(65, 'weapon_deagle_price', '7500'),
(66, 'weapon_shotgun_price', '50000'),
(67, 'weapon_mp5_price', '10000'),
(68, 'weapon_ak47_price', '25000'),
(69, 'weapon_m4_price', '20000'),
(70, 'weapon_uzi_price', '9000');

-- --------------------------------------------------------

--
-- Table structure for table `shops`
--

CREATE TABLE `shops` (
  `shopID` int(11) NOT NULL,
  `shopLocX` float DEFAULT 0,
  `shopLocY` float DEFAULT 0,
  `shopLocZ` float DEFAULT 0,
  `shopName` varchar(32) NOT NULL DEFAULT '24/7 Shop'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `shops`
--

INSERT INTO `shops` (`shopID`, `shopLocX`, `shopLocY`, `shopLocZ`, `shopName`) VALUES
(1, 1142.99, -1520.15, 15.7969, '24/7 Shop'),
(2, 822.054, -1758.33, 13.6484, '24/7 Shop'),
(3, 1352.3, -1758.31, 13.5078, '24/7 Shop'),
(4, 2163.22, -1744.15, 13.5469, '24/7 Shop'),
(5, 2423.07, -1742.42, 13.5469, '24/7 Shop'),
(6, 2362.68, -1339.17, 24.0078, '24/7 Shop'),
(7, 1315.33, -899.083, 39.5781, '24/7 Shop'),
(8, 2002.84, -1282.41, 23.9733, '24/7 Shop'),
(9, 994.824, -1297.04, 13.5469, '24/7 Shop'),
(10, 841.601, -2047.8, 12.8672, '24/7 Shop');

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
  `color` varchar(8) DEFAULT '000000FF',
  `label_z` float DEFAULT 15
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `turfs`
--

INSERT INTO `turfs` (`id`, `faction_id`, `name`, `x1`, `y1`, `x2`, `y2`, `attackable`, `color`, `label_z`) VALUES
(5, 4, '#5', -1156, 2248, -1041, 2411, 1, '3366CC88', 0),
(6, 5, '#4', -1250, 2251, -1037, 2409, 1, 'AA44AA88', 0),
(7, 6, '#7', -473, 2157, -312, 2295, 1, '44AA4488', 15),
(8, 7, '#8', 50, 2349, 225, 2305, 1, 'FFCC0088', 15),
(9, 4, '#9', -843, 2319, -697, 2517, 1, '3366CC88', 15),
(10, 5, '#10', 214, 2529, 345, 2704, 1, 'AA44AA88', 15),
(11, 6, '#11', 27, 2529, 214, 2663, 1, '44AA4488', 15),
(12, 7, '#12', 943, 918, 1178, 1186, 1, 'FFCC0088', 15);

-- --------------------------------------------------------

--
-- Table structure for table `ucp_factapplications`
--

CREATE TABLE `ucp_factapplications` (
  `id` int(11) NOT NULL,
  `playerId` int(11) NOT NULL,
  `factionsId` int(11) NOT NULL,
  `data_aplicarii` datetime NOT NULL,
  `status` enum('Open','Review','Accepted','Rejected') NOT NULL DEFAULT 'Open',
  `motiv` text NOT NULL,
  `lastFaction` int(11) NOT NULL DEFAULT 0,
  `reject_reason` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ucp_factapplications`
--

INSERT INTO `ucp_factapplications` (`id`, `playerId`, `factionsId`, `data_aplicarii`, `status`, `motiv`, `lastFaction`, `reject_reason`) VALUES
(1, 1, 1, '2026-07-31 09:53:15', 'Accepted', 'de aia vreau sa intru', 2, NULL);

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
  `color2` int(11) DEFAULT 1,
  `fuel` float DEFAULT 100
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `vehicles_faction`
--

INSERT INTO `vehicles_faction` (`id`, `faction_id`, `model_id`, `loc_x`, `loc_y`, `loc_z`, `rotation`, `color1`, `color2`, `fuel`) VALUES
(1, 3, 560, 1189.21, -1347, 13.2719, 0, 175, 1, 94.9),
(2, 3, 560, 1189.3, -1302.52, 13.2601, 180, 175, 1, 99.72),
(3, 3, 489, 1212.19, -1308.16, 13.6996, 180, 175, 1, 99.75),
(4, 3, 489, 1212.43, -1334.59, 13.7107, 0, 175, 1, 99.52),
(5, 3, 407, 1177.47, -1309.14, 14.0944, 270, 175, 1, 99.68),
(6, 3, 407, 1212.37, -1300.47, 13.7882, 0, 175, 1, 99.72),
(7, 3, 407, 1212.62, -1342.93, 13.807, 180, 175, 1, 99.58),
(8, 3, 407, 1178.87, -1339.81, 14.1021, 270, 175, 1, 99.64),
(9, 3, 416, 1184.63, -1329.13, 13.7163, 270, 175, 1, 99.72),
(10, 3, 416, 1184.49, -1334.09, 13.7204, 270, 175, 1, 99.77),
(11, 3, 416, 1184.5, -1317.24, 13.7193, 270, 175, 1, 99.74),
(12, 3, 416, 1184.58, -1313.15, 13.7142, 270, 175, 1, 99.13),
(13, 1, 523, 1542, -1685, 13.1224, 90, 1, 0, 100),
(14, 1, 523, 1542, -1689, 13.1232, 90, 1, 0, 100),
(15, 1, 523, 1542, -1693, 13.1185, 90, 1, 0, 100),
(16, 1, 523, 1542, -1665, 13.1255, 90, 1, 0, 100),
(17, 1, 523, 1542, -1661, 13.2355, 90, 1, 0, 100),
(18, 1, 523, 1542, -1657, 13.1082, 90, 1, 0, 100),
(19, 1, 596, 1536.07, -1677.92, 13.1305, 180, 1, 0, 100),
(20, 1, 596, 1536.01, -1666.99, 13.1303, 0, 1, 0, 100),
(21, 1, 596, 1546.44, -1676.17, 5.6366, 90, 1, 0, 100),
(22, 1, 596, 1546.59, -1684.52, 5.6356, 90, 1, 0, 100),
(23, 1, 596, 1528.01, -1684.03, 5.6344, 270, 1, 0, 100),
(24, 1, 427, 1538.66, -1644.44, 6.0275, 180, 1, 0, 100),
(25, 1, 427, 1530.75, -1644.61, 6.0176, 180, 1, 0, 100),
(26, 1, 599, 1546.38, -1667.78, 6.079, 90, 1, 0, 100),
(27, 1, 599, 1546.19, -1659, 6.0808, 90, 1, 0, 100),
(28, 2, 552, 886.718, -1270.78, 14.4037, 0, 155, 155, 100),
(29, 2, 552, 891.255, -1270.74, 14.411, 0, 155, 155, 100),
(30, 2, 552, 896.771, -1270.4, 14.4154, 0, 155, 155, 100),
(31, 2, 498, 905.663, -1237.73, 16.3328, 0, 155, 155, 100),
(32, 2, 525, 904.499, -1254.15, 14.9391, 90, 155, 155, 100),
(33, 2, 525, 904.514, -1247.1, 15.3917, 90, 155, 155, 96.22),
(34, 2, 525, 904.181, -1260.35, 14.738, 90, 155, 155, 100),
(35, 2, 443, 871.136, -1235.11, 15.9534, 270, 155, 155, 100),
(36, 2, 568, 862.295, -1245.45, 14.6699, 270, 155, 155, 100),
(37, 2, 568, 862.299, -1255.67, 14.6595, 270, 155, 155, 100),
(38, 4, 579, 1871.56, -2039.62, 13.4834, 250, 135, 6, 40.24),
(39, 4, 579, 1896.09, -2037.47, 13.4816, 120, 135, 6, 99.65),
(40, 4, 429, 1892.17, -2029.11, 13.2266, 150, 135, 6, 99.86),
(41, 4, 429, 1892.31, -2023.48, 13.2246, 150, 135, 6, 99.7),
(42, 4, 560, 1891.07, -2015.08, 13.2475, 150, 135, 6, 99.64),
(43, 4, 560, 1874.77, -2015.44, 13.2504, 220, 135, 6, 99.63),
(44, 4, 468, 1880.76, -2008, 13.216, 180, 135, 6, 99.49),
(45, 4, 468, 1878.94, -2008.05, 13.2154, 180, 135, 6, 99.82),
(46, 4, 468, 1877.12, -2008.01, 13.2161, 180, 135, 6, 99.78),
(47, 4, 521, 1885.4, -2008.23, 13.1173, 180, 135, 6, 99.78),
(48, 4, 521, 1887.36, -2008.1, 13.1178, 180, 135, 6, 99.83),
(49, 4, 521, 1889.29, -2008.09, 13.1197, 180, 135, 6, 99.81),
(50, 5, 468, 1894.84, -1115.77, 25.0939, 165.128, 147, 162, 99.85),
(51, 5, 468, 1892.4, -1114.81, 24.9426, 179.583, 147, 162, 99.76),
(52, 5, 468, 1895.05, -1119.77, 25.1616, 159.539, 147, 162, 99.85),
(53, 5, 521, 1908.38, -1114.43, 25.2329, 182.577, 147, 162, 99.65),
(54, 5, 521, 1910.36, -1114.13, 25.2353, 185.166, 147, 162, 99.79),
(55, 5, 521, 1912.38, -1114.14, 25.2372, 178.101, 147, 162, 99.86),
(56, 5, 579, 1899.4, -1118.83, 25.6155, 180.219, 147, 162, 99.28),
(57, 5, 579, 1902.92, -1118.91, 25.6529, 179.628, 147, 162, 99.63),
(58, 5, 560, 1917.94, -1129.2, 24.6339, 89.9113, 147, 162, 99.75),
(59, 5, 560, 1896.45, -1142.44, 24.0939, 270.36, 147, 162, 99.49),
(60, 5, 429, 1905.13, -1142.07, 24.29, 271.027, 147, 162, 99.72),
(61, 5, 429, 1918.15, -1142.27, 24.6144, 89.467, 147, 162, 99.67),
(62, 6, 468, 2497.26, -1687, 13.1508, 10.9462, 235, 235, 99.8),
(63, 6, 468, 2498.89, -1686.94, 13.1617, 13.4526, 235, 235, 99.75),
(64, 6, 468, 2500.73, -1686.72, 13.1727, 20.2733, 235, 235, 99.77),
(65, 6, 521, 2491.69, -1686.59, 13.0829, 5.2384, 235, 235, 76.62),
(66, 6, 521, 2489.48, -1686.59, 13.0821, 6.9277, 235, 235, 99.76),
(67, 6, 521, 2487.13, -1686.8, 13.0802, 2.2202, 235, 235, 99.69),
(68, 6, 579, 2507.45, -1678.25, 13.3983, 143.299, 235, 235, 99.82),
(69, 6, 579, 2516.83, -1672.81, 13.9253, 68.521, 235, 235, 99.69),
(70, 6, 429, 2476.58, -1693.17, 13.1947, 22.5667, 235, 235, 99.56),
(71, 6, 429, 2467.53, -1689.21, 13.193, 272.105, 235, 235, 99.74),
(72, 6, 560, 2499.47, -1655.96, 13.1076, 83.1457, 235, 235, 99.62),
(73, 6, 560, 2470.15, -1671.37, 13.0699, 9.1035, 235, 235, 99.55),
(74, 7, 429, 2217.2, -1171.3, 25.4062, 268.704, 228, 228, 99.77),
(75, 7, 429, 2205.49, -1173.07, 25.4076, 268.816, 228, 228, 99.84),
(76, 7, 521, 2204.26, -1152.22, 25.3195, 272.581, 228, 228, 99.23),
(77, 7, 521, 2204.25, -1155.08, 25.3111, 270.594, 228, 228, 99.71),
(78, 7, 521, 2204.27, -1157.8, 25.3125, 270.504, 228, 228, 99.79),
(79, 7, 468, 2231.95, -1155.12, 25.5448, 57.8942, 228, 228, 99.76),
(80, 7, 468, 2232.13, -1162.55, 25.5253, 70.3296, 228, 228, 99.74),
(81, 7, 468, 2232.35, -1164.54, 25.5421, 68.7971, 228, 228, 95.31),
(82, 7, 579, 2205.05, -1160.91, 25.6686, 271.836, 228, 228, 99.3),
(83, 7, 579, 2229.25, -1177.68, 25.6579, 89.4945, 228, 228, 99.63),
(84, 7, 560, 2216.38, -1166.99, 25.4318, 270.607, 228, 228, 99.83),
(85, 7, 560, 2229.59, -1169.94, 25.4557, 89.7645, 228, 228, 99.4),
(86, 8, 582, 736.195, -1345.41, 13.7, 270, 232, 232, 85.58),
(87, 8, 582, 735.926, -1337.21, 13.7, 270, 232, 232, 100),
(88, 8, 582, 743.625, -1333.87, 13.7, 220, 232, 232, 100),
(89, 8, 582, 752.155, -1333.65, 13.7, 220, 232, 232, 100),
(90, 8, 582, 760.693, -1333.82, 13.7, 220, 232, 232, 100),
(91, 8, 461, 749.066, -1358.03, 13.1, 0, 232, 232, 100),
(92, 8, 461, 751.331, -1358.28, 13.1, 0, 232, 232, 100),
(93, 8, 461, 753.932, -1358.23, 13.1, 0, 232, 232, 100),
(94, 1, 411, 1534.8, -1643.92, 5.6177, 179.226, 1, -1, 100),
(95, 1, 411, 1546.53, -1650.93, 5.6177, 90.4683, 1, -1, 100),
(96, 1, 411, 1527.59, -1688.73, 5.6177, 269.266, 1, -1, 100),
(97, 1, 411, 1546.92, -1680.32, 5.6471, 90.6085, 1, -1, 100),
(98, 8, 488, 774.192, -1371.66, 16.0085, 1.0298, -1, -1, 100),
(100, 4, 595, 0, -2480.75, 0.02, 180, 135, 6, 100),
(101, 5, 595, 2628.45, -2480.83, 0.05, 180, 135, 6, 100),
(102, 6, 595, 2619.47, -2480.44, 0.05, 180, 235, 235, 100),
(103, 7, 595, 2609.99, -2480.8, 0.05, 180, 228, 228, 100);

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
  `plate` varchar(24) DEFAULT NULL,
  `price` int(11) DEFAULT 0,
  `loc_x` float DEFAULT 0,
  `loc_y` float DEFAULT 0,
  `loc_z` float DEFAULT 0,
  `rotation` float DEFAULT 0,
  `insurance_exp` date DEFAULT NULL,
  `medkit_exp` date DEFAULT NULL,
  `extinguisher_exp` date DEFAULT NULL,
  `itp_exp` date DEFAULT NULL,
  `locked` tinyint(4) DEFAULT 0,
  `first_registration` date DEFAULT NULL,
  `from_biz` int(11) DEFAULT 0,
  `fuel` float DEFAULT 100,
  `is_confiscated` tinyint(4) DEFAULT 0,
  `is_for_sale` tinyint(4) DEFAULT 0,
  `dirty` int(11) DEFAULT 0,
  `count_owners` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `vehicles_personal`
--

INSERT INTO `vehicles_personal` (`id`, `owner_id`, `model_id`, `color1`, `color2`, `plate`, `price`, `loc_x`, `loc_y`, `loc_z`, `rotation`, `insurance_exp`, `medkit_exp`, `extinguisher_exp`, `itp_exp`, `locked`, `first_registration`, `from_biz`, `fuel`, `is_confiscated`, `is_for_sale`, `dirty`, `count_owners`) VALUES
(1, 1, 411, 1, 1, 'f', 8, 976.309, 2140.76, 10.5474, 272.362, '2026-06-18', '2026-06-17', '2026-06-18', '2026-08-15', 0, '2026-07-01', 0, 99.86, 0, 0, 100, 1),
(2, 1, 541, 1, 1, '123', 5000000, 968.921, 2158, 10.4452, 273.257, '2026-06-22', '2026-06-19', '2026-07-31', '2026-06-01', 0, '2026-06-01', 0, 100, 0, 0, 70, 1),
(4, 1, 411, 1, 1, '{FF2700}LS 01 XXX', 1000000, 896.047, -1238.04, 16.0275, 141.843, '2026-08-05', '2026-08-05', '2026-08-05', '2026-08-05', 0, '2026-07-29', 8, 98.39, 0, 1, 59, 1),
(5, 0, 411, 1, 1, 'LV 5', 1000000, 2147.41, -1143.31, 24.6911, 268.529, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.81, 0, 1, 43, 0),
(6, 0, 411, 1, 1, 'LV 6', 1000000, 2147.05, -1148.32, 24.1413, 269.025, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.77, 0, 1, 52, 0),
(7, 0, 541, 1, 1, 'LV 7', 900000, 2162.88, -1143.71, 24.4721, 91.1427, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.71, 0, 1, 56, 0),
(8, 0, 541, 1, 1, 'LV 8', 900000, 2162.9, -1148.22, 24.0128, 90.718, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.77, 0, 1, 47, 0),
(9, 0, 541, 0, 1, 'LV 9', 900000, 2163.02, -1153.01, 23.5528, 90.5515, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.74, 0, 1, 52, 0),
(10, 0, 560, 1, 1, 'LV 10', 750000, 2146.89, -1152.98, 23.6386, 267.32, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.7, 0, 1, 44, 0),
(11, 0, 560, 1, 1, 'LV 11', 750000, 2146.9, -1157.21, 23.551, 269.889, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.8, 0, 1, 55, 0),
(12, 0, 562, 1, 1, 'LV 12', 600000, 2162.94, -1157.96, 23.4997, 89.844, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.74, 0, 1, 48, 0),
(13, 0, 562, 1, 1, 'LV 13', 600000, 2162.88, -1163.12, 23.4766, 89.0513, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.77, 0, 1, 46, 0),
(14, 0, 451, 1, 1, 'LV 14', 650000, 2146.93, -1161.68, 23.5292, 268.965, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.72, 0, 1, 51, 0),
(15, 0, 451, 1, 1, 'LV 15', 650000, 2147.01, -1166.31, 23.5267, 269.909, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.78, 0, 1, 45, 0),
(16, 0, 522, 1, 1, 'LV 16', 1100000, 2474.79, -1954.59, 12.9858, 359.262, NULL, NULL, NULL, NULL, 0, NULL, 17, 95.26, 0, 1, 52, 0),
(17, 0, 522, 1, 1, 'LV 17', 1100000, 2477.97, -1954.74, 12.9844, 0.3759, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.82, 0, 1, 53, 0),
(18, 0, 522, 1, 1, 'LV 18', 1100000, 2476.42, -1954.83, 12.9819, 359.379, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.77, 0, 1, 52, 0),
(19, 0, 522, 1, 1, 'LV 19', 1100000, 2479.68, -1954.7, 12.986, 0.7223, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.8, 0, 1, 49, 0),
(20, 0, 581, 1, 1, 'LV 20', 700000, 2482.71, -1954.88, 13.0079, 0.427, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.77, 0, 1, 55, 0),
(21, 0, 581, 1, 1, 'LV 21', 700000, 2484.38, -1954.83, 13.0099, 1.1779, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.79, 0, 1, 49, 0),
(22, 0, 581, 1, 1, 'LV 22', 700000, 2486.14, -1954.9, 13.0087, 359.565, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.81, 0, 1, 53, 0),
(23, 0, 461, 1, 1, 'LV 23', 850000, 2489.17, -1954.84, 12.9971, 3.3526, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.77, 0, 1, 50, 0),
(24, 0, 461, 1, 1, 'LV 24', 850000, 2490.77, -1954.86, 12.9968, 356.616, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.73, 0, 1, 51, 0),
(25, 0, 461, 1, 1, 'LV 25', 850000, 2492.28, -1954.8, 12.9954, 3.0746, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.79, 0, 1, 48, 0),
(26, 0, 463, 1, 1, 'LV 26', 900000, 2495.4, -1954.72, 12.9542, 0.6371, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.69, 0, 1, 54, 0),
(27, 0, 463, 1, 1, 'LV 27', 900000, 2497.21, -1954.76, 12.954, 359.312, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.82, 0, 1, 54, 0),
(28, 0, 468, 1, 1, 'LV 28', 550000, 2500.38, -1954.98, 13.0808, 359.916, NULL, NULL, '0000-00-00', NULL, 0, NULL, 17, 99.69, 0, 1, 49, 0),
(29, 0, 468, 1, 1, 'LV 29', 550000, 2503.73, -1954.95, 13.0815, 358.399, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.73, 0, 1, 45, 0),
(30, 0, 489, 1, 1, 'LV 30', 600000, 2052.48, -1903.2, 13.6899, 179.254, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.58, 0, 1, 51, 0),
(31, 0, 489, 1, 1, 'LV 31', 600000, 2058.89, -1903.22, 13.6904, 179.418, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.69, 0, 1, 53, 0),
(32, 0, 579, 1, 1, 'LV 32', 500000, 2069.17, -1903.09, 13.4774, 181.767, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.7, 0, 1, 49, 0),
(33, 0, 579, 1, 1, 'LV 33', 500000, 2064.99, -1903.13, 13.4762, 179.539, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.74, 0, 1, 51, 0),
(34, 0, 400, 1, 1, 'LV 34', 350000, 2064.7, -1940.84, 13.4477, 90.1334, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.79, 0, 1, 52, 0),
(35, 0, 400, 1, 1, 'LV 35', 350000, 2056.66, -1941.04, 13.4516, 270.59, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.65, 0, 1, 46, 0),
(36, 0, 422, 1, 1, 'LV 36', 200000, 2038.12, -1941.11, 13.3505, 270.408, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.6, 0, 1, 55, 0),
(37, 0, 554, 1, 1, 'LV 37', 275000, 2048.47, -1940.82, 13.4383, 89.9542, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.65, 0, 1, 56, 0);

-- --------------------------------------------------------

--
-- Table structure for table `warns`
--

CREATE TABLE `warns` (
  `warnID` int(11) NOT NULL,
  `username` varchar(24) NOT NULL DEFAULT '',
  `reason` varchar(128) NOT NULL DEFAULT '',
  `warned_by` varchar(24) NOT NULL DEFAULT '',
  `warn_date` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `ammunations`
--
ALTER TABLE `ammunations`
  ADD PRIMARY KEY (`amoID`);

--
-- Indexes for table `arm_equipment`
--
ALTER TABLE `arm_equipment`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `atms`
--
ALTER TABLE `atms`
  ADD PRIMARY KEY (`atmID`);

--
-- Indexes for table `bans`
--
ALTER TABLE `bans`
  ADD PRIMARY KEY (`banID`);

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
-- Indexes for table `bin`
--
ALTER TABLE `bin`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `businesses`
--
ALTER TABLE `businesses`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `clothstores`
--
ALTER TABLE `clothstores`
  ADD PRIMARY KEY (`csID`);

--
-- Indexes for table `cs_locations`
--
ALTER TABLE `cs_locations`
  ADD PRIMARY KEY (`csID`);

--
-- Indexes for table `factions`
--
ALTER TABLE `factions`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `farms`
--
ALTER TABLE `farms`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `farm_equipment`
--
ALTER TABLE `farm_equipment`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `fastfood`
--
ALTER TABLE `fastfood`
  ADD PRIMARY KEY (`ffID`);

--
-- Indexes for table `gta_interiors`
--
ALTER TABLE `gta_interiors`
  ADD PRIMARY KEY (`gtaIntID`);

--
-- Indexes for table `hotels`
--
ALTER TABLE `hotels`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `houses`
--
ALTER TABLE `houses`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `houses_animals`
--
ALTER TABLE `houses_animals`
  ADD PRIMARY KEY (`aID`);

--
-- Indexes for table `houses_tree`
--
ALTER TABLE `houses_tree`
  ADD PRIMARY KEY (`treeId`);

--
-- Indexes for table `locations_admin`
--
ALTER TABLE `locations_admin`
  ADD PRIMARY KEY (`locID`),
  ADD UNIQUE KEY `uq_location_name` (`locName`);

--
-- Indexes for table `players`
--
ALTER TABLE `players`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- Indexes for table `player_skins`
--
ALTER TABLE `player_skins`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_player_skin` (`player_id`,`skin_id`);

--
-- Indexes for table `president_votes`
--
ALTER TABLE `president_votes`
  ADD PRIMARY KEY (`vID`);

--
-- Indexes for table `races`
--
ALTER TABLE `races`
  ADD PRIMARY KEY (`rID`);

--
-- Indexes for table `reports`
--
ALTER TABLE `reports`
  ADD PRIMARY KEY (`repID`);

--
-- Indexes for table `rulote_personale`
--
ALTER TABLE `rulote_personale`
  ADD PRIMARY KEY (`rID`);

--
-- Indexes for table `server_setup`
--
ALTER TABLE `server_setup`
  ADD PRIMARY KEY (`ssId`),
  ADD UNIQUE KEY `ssSetare` (`ssSetare`);

--
-- Indexes for table `shops`
--
ALTER TABLE `shops`
  ADD PRIMARY KEY (`shopID`);

--
-- Indexes for table `turfs`
--
ALTER TABLE `turfs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_turf_name` (`name`);

--
-- Indexes for table `ucp_factapplications`
--
ALTER TABLE `ucp_factapplications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_faction_status` (`factionsId`,`status`),
  ADD KEY `idx_player` (`playerId`);

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
  ADD UNIQUE KEY `plate_unique` (`plate`),
  ADD UNIQUE KEY `plate` (`plate`);

--
-- Indexes for table `warns`
--
ALTER TABLE `warns`
  ADD PRIMARY KEY (`warnID`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `ammunations`
--
ALTER TABLE `ammunations`
  MODIFY `amoID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `arm_equipment`
--
ALTER TABLE `arm_equipment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `atms`
--
ALTER TABLE `atms`
  MODIFY `atmID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `bans`
--
ALTER TABLE `bans`
  MODIFY `banID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `basket_spawns`
--
ALTER TABLE `basket_spawns`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=50;

--
-- AUTO_INCREMENT for table `bin`
--
ALTER TABLE `bin`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `businesses`
--
ALTER TABLE `businesses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT for table `clothstores`
--
ALTER TABLE `clothstores`
  MODIFY `csID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `cs_locations`
--
ALTER TABLE `cs_locations`
  MODIFY `csID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `farms`
--
ALTER TABLE `farms`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `farm_equipment`
--
ALTER TABLE `farm_equipment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `fastfood`
--
ALTER TABLE `fastfood`
  MODIFY `ffID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `gta_interiors`
--
ALTER TABLE `gta_interiors`
  MODIFY `gtaIntID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=139;

--
-- AUTO_INCREMENT for table `hotels`
--
ALTER TABLE `hotels`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `houses`
--
ALTER TABLE `houses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=46;

--
-- AUTO_INCREMENT for table `houses_animals`
--
ALTER TABLE `houses_animals`
  MODIFY `aID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `houses_tree`
--
ALTER TABLE `houses_tree`
  MODIFY `treeId` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `locations_admin`
--
ALTER TABLE `locations_admin`
  MODIFY `locID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=914;

--
-- AUTO_INCREMENT for table `players`
--
ALTER TABLE `players`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=38;

--
-- AUTO_INCREMENT for table `player_skins`
--
ALTER TABLE `player_skins`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT for table `president_votes`
--
ALTER TABLE `president_votes`
  MODIFY `vID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `races`
--
ALTER TABLE `races`
  MODIFY `rID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `reports`
--
ALTER TABLE `reports`
  MODIFY `repID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `rulote_personale`
--
ALTER TABLE `rulote_personale`
  MODIFY `rID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `server_setup`
--
ALTER TABLE `server_setup`
  MODIFY `ssId` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=71;

--
-- AUTO_INCREMENT for table `shops`
--
ALTER TABLE `shops`
  MODIFY `shopID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=54;

--
-- AUTO_INCREMENT for table `turfs`
--
ALTER TABLE `turfs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=155;

--
-- AUTO_INCREMENT for table `ucp_factapplications`
--
ALTER TABLE `ucp_factapplications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `vehicles_faction`
--
ALTER TABLE `vehicles_faction`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=104;

--
-- AUTO_INCREMENT for table `vehicles_personal`
--
ALTER TABLE `vehicles_personal`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=38;

--
-- AUTO_INCREMENT for table `warns`
--
ALTER TABLE `warns`
  MODIFY `warnID` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
