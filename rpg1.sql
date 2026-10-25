-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Sep 08, 2026 at 02:21 PM
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
(1, 1791.4, -1164.8, 23.8281, 'Downtown AmmuNation', 6, 1, 316.5, -167.62, 999.59),
(2, 2400.4, -1981.05, 13.5469, 'WillowField AmmuNation', 6, 2, 297.14, -109.87, 1001.51),
(3, 1081.5, -1698.15, 13.5469, 'Verona AmmuNation', 7, 3, 315.24, -140.88, 999.6),
(4, 1366.61, -1279.79, 13.5469, '', 7, 4, 315.24, -140.88, 999.6),
(5, 2335.03, 62.1586, 26.4833, '', 6, 5, 316.5, -167.62, 999.59),
(6, 241.46, -178.406, 1.5781, 'Blueberry Weapons', 4, 6, 291.76, -80.13, 1001.51);

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
(10, 0, 1085.31, -1802.91, 13.5992, 19),
(11, 0, 660.649, -569.996, 16.3359, 19);

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
-- Table structure for table `bars`
--

CREATE TABLE `bars` (
  `id` int(11) NOT NULL,
  `name` varchar(32) DEFAULT 'Bar',
  `type` tinyint(4) DEFAULT 1,
  `gta_interior_id` int(11) DEFAULT 0,
  `vw_id` int(11) DEFAULT 0,
  `loc_x` float DEFAULT 0,
  `loc_y` float DEFAULT 0,
  `loc_z` float DEFAULT 0,
  `stock_max` int(11) DEFAULT 100,
  `stock_curr` int(11) DEFAULT 100,
  `terrace` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `bars`
--

INSERT INTO `bars` (`id`, `name`, `type`, `gta_interior_id`, `vw_id`, `loc_x`, `loc_y`, `loc_z`, `stock_max`, `stock_curr`, `terrace`) VALUES
(1, 'Bar', 1, 24, 1, 2309.83, -1645.09, 14.827, 100, 99, 0),
(2, 'Rock\'n\'Beer', 1, 25, 2, 816.298, -1387.44, 13.6115, 100, 99, 0),
(3, 'FPD cock-tails', 1, 117, 3, 1786.25, -1722.31, 13.5469, 100, 98, 0),
(4, 'Bar', 3, 25, 4, 278.072, -1433.98, 13.9196, 100, 99, 1),
(5, 'Bar', 1, 117, 5, 2152.95, -1013.82, 62.8815, 100, 100, 0),
(6, 'Bar', 2, 24, 6, 2349.25, -1373.74, 24.3984, 100, 100, 0),
(7, 'Bar', 3, 25, 7, 513.828, -1487.4, 14.4909, 100, 99, 1);

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
-- Table structure for table `billboards`
--

CREATE TABLE `billboards` (
  `bbID` int(11) NOT NULL,
  `bbObjectId` int(11) DEFAULT 19325,
  `bbRented` tinyint(1) DEFAULT 0,
  `bbText` varchar(128) DEFAULT '==========',
  `bbTextColor` varchar(9) DEFAULT '#FFFFFFFF',
  `bbTextBackground` varchar(9) DEFAULT '#000000FF',
  `bbRentLeft` int(11) DEFAULT 0,
  `bbRentPrice24H` int(11) DEFAULT 5000,
  `bbClean` tinyint(4) DEFAULT 2,
  `bbLocX` float DEFAULT 0,
  `bbLocY` float DEFAULT 0,
  `bbLocZ` float DEFAULT 0,
  `bbObjectPosX` float DEFAULT 0,
  `bbObjectPosY` float DEFAULT 0,
  `bbObjectPosZ` float DEFAULT 0,
  `bbObjectPosRX` float DEFAULT 0,
  `bbObjectPosRY` float DEFAULT 0,
  `bbObjectPosRZ` float DEFAULT 0,
  `bbFontSize` int(11) DEFAULT 40,
  `bbOwnerId` int(11) DEFAULT 0,
  `bbOwner` varchar(24) DEFAULT '',
  `bbIsForSale` tinyint(1) DEFAULT 1,
  `bbDefaultPrice` int(11) DEFAULT 15000000,
  `bbPrice` int(11) DEFAULT 15000000,
  `bbBank` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `billboards`
--

INSERT INTO `billboards` (`bbID`, `bbObjectId`, `bbRented`, `bbText`, `bbTextColor`, `bbTextBackground`, `bbRentLeft`, `bbRentPrice24H`, `bbClean`, `bbLocX`, `bbLocY`, `bbLocZ`, `bbObjectPosX`, `bbObjectPosY`, `bbObjectPosZ`, `bbObjectPosRX`, `bbObjectPosRY`, `bbObjectPosRZ`, `bbFontSize`, `bbOwnerId`, `bbOwner`, `bbIsForSale`, `bbDefaultPrice`, `bbPrice`, `bbBank`) VALUES
(1, 8330, 0, 'Police Departament\nis watching you...', '#77CF7CFF', '#000000FF', 0, 5000, 0, 1538.28, -1608.6, 13.5469, 1538.8, -1610.6, 25.5469, 0, 0, 269, 20, 0, '', 1, 15000000, 15000000, 7500),
(2, 8330, 0, 'Welcome to Nostalgia: LosSantos\n\nLeave your worries aside;\n Enjoy some quality time.', '#77CF7CFF', '#000000FF', 0, 5000, 2, 848.633, -1818.3, 12.1949, 853.333, -1817.32, 20, 0, 0, -5.855, 15, 0, '', 1, 15000000, 15000000, 0);

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
(5, 1, 10, 10, 1516.62, -1849.3, 13.5469),
(6, 1, 10, 10, 1461.48, -1488.45, 13.5469),
(7, 1, 10, 10, 1521.25, -1014.7, 23.9765),
(8, 1, 10, 10, 1829.58, -1143.87, 23.8811),
(9, 1, 10, 10, 1829.54, -1113.74, 23.8766),
(10, 1, 10, 10, 1786.19, -1147.13, 23.8787);

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
  `default_price` int(11) DEFAULT 50000,
  `coffee_maker` tinyint(1) DEFAULT 0,
  `coffee_maker_exp` int(11) DEFAULT 20
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `businesses`
--

INSERT INTO `businesses` (`id`, `owned`, `owner`, `owner_id`, `price`, `bank`, `loc_x`, `loc_y`, `loc_z`, `name`, `is_for_sale`, `anaf`, `anaf_docs`, `default_price`, `coffee_maker`, `coffee_maker_exp`) VALUES
(1, 0, '', 0, 3000000, 120, 830.194, -2047.81, 12.8672, 'Rent Mountain Bike LS', 1, 0, 0, 3000000, 0, 20),
(2, 0, '', 0, 3000000, 974, 341.339, -1500.45, 36.0391, 'Driving Licenses', 1, 0, 0, 3000000, 0, 20),
(3, 0, '', 0, 3000000, 90, 1109.79, -1796.64, 16.5938, 'Rent Car LosSantos', 1, 0, 0, 3000000, 0, 20),
(4, 0, '', 0, 3000000, 1000, 336.535, -1505.59, 36.0391, 'empty', 1, 0, 0, 3000000, 0, 20),
(5, 0, '', 0, 3000000, 200, 327.807, -1515.54, 36.0391, 'empty', 1, 0, 0, 3000000, 0, 20),
(6, 0, '', 0, 3000000, 120, 346.521, -1496.1, 36.0391, 'Flying Licenses', 1, 0, 0, 3000000, 0, 20),
(7, 0, '', 0, 3000000, 800, 331.728, -1510.81, 36.0391, 'empty', 1, 0, 0, 3000000, 0, 20),
(8, 0, '', 0, 3000000, 10, 2131.66, -1150.23, 24.1786, 'Sport Car Dealership', 1, 0, 0, 3000000, 0, 20),
(9, 0, '', 0, 3000000, 1500, 2794.19, -1087.24, 30.7188, 'Vehicle Safety Kits', 1, 0, 0, 3000000, 0, 20),
(10, 0, '', 0, 3000000, 500, 2851.76, -1532.58, 11.0938, 'Bar Suppliers', 1, 0, 0, 3000000, 0, 20),
(11, 0, '', 0, 3000000, 0, 1676.3, -1634.62, 14.2266, 'Insurance Company', 1, 0, 0, 3000000, 0, 20),
(12, 0, '', 0, 3000000, 0, 1032.16, -946.005, 42.6399, 'FastFood Restaurant', 1, 0, 0, 3000000, 0, 20),
(13, 0, '', 0, 3000000, 605, 2350.67, -1412.17, 23.9924, 'Home Furnitures', 1, 0, 0, 3000000, 0, 20),
(14, 0, '', 0, 3000000, 560, 1095.79, -1437.42, 22.7631, 'Supermarket Carifura', 1, 0, 0, 3000000, 0, 20),
(15, 0, '', 0, 3000000, 30, 1045.71, -324.804, 73.9922, 'Hidden Harbor Lodge', 1, 0, 0, 3000000, 0, 20),
(16, 0, '', 0, 3000000, 10, 988.774, -1366.03, 13.5488, 'Food Dlivery Business', 1, 0, 0, 3000000, 0, 20),
(17, 0, '', 0, 3000000, 0, 2485.36, -1957.92, 13.5881, 'Bikers Dealership', 1, 0, 0, 3000000, 0, 20),
(18, 0, '', 0, 3000000, 0, 2046.89, -1918.25, 13.5469, 'SUV Dealership', 1, 0, 0, 3000000, 0, 20),
(19, 0, '', 0, 3000000, 14, 1464.81, -1012.59, 26.8438, 'Swiss Bank', 1, 0, 0, 3000000, 0, 20),
(20, 0, '', 0, 3000000, 41, 1935.81, -2086.7, 13.5727, 'Jew\' Bank', 1, 0, 0, 3000000, 0, 20),
(21, 0, '', 0, 3000000, 810, 1471.9, -1263.4, 14.5625, 'Electronics Producer', 1, 0, 0, 3000000, 0, 20),
(22, 0, '', 0, 3000000, 130, 1546.69, -1270.5, 17.4063, 'Cellular netowork', 1, 0, 0, 3000000, 0, 20),
(23, 0, '', 0, 10000000, 26, 2617.82, -2195.04, 13.5469, 'Fuel Company', 1, 0, 0, 10000000, 0, 20);

-- --------------------------------------------------------

--
-- Table structure for table `clothstores`
--

CREATE TABLE `clothstores` (
  `id` int(11) NOT NULL,
  `locX` float DEFAULT 0,
  `locY` float DEFAULT 0,
  `locZ` float DEFAULT 0,
  `name` varchar(32) NOT NULL DEFAULT '',
  `intId` int(11) DEFAULT 0,
  `vwId` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `clothstores`
--

INSERT INTO `clothstores` (`id`, `locX`, `locY`, `locZ`, `name`, `intId`, `vwId`) VALUES
(1, 2244.4, -1664.22, 15.4766, 'ZaraZara', 14, 1),
(2, 459.84, -1501.17, 31.0387, 'M and H', 15, 2),
(3, 500.439, -1358.41, 16.1774, 'Naic', 16, 3),
(4, 1457.78, -1140.07, 24.0683, 'Abibas', 17, 4);

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
-- Table structure for table `event_attachments`
--

CREATE TABLE `event_attachments` (
  `id` int(11) NOT NULL,
  `quest_key` varchar(32) NOT NULL DEFAULT '',
  `model` int(11) NOT NULL DEFAULT 0,
  `slot` int(11) NOT NULL DEFAULT 6,
  `bone` int(11) NOT NULL DEFAULT 6,
  `x` float DEFAULT 0,
  `y` float DEFAULT 0,
  `z` float DEFAULT 0,
  `rx` float DEFAULT 0,
  `ry` float DEFAULT 0,
  `rz` float DEFAULT 0,
  `sx` float DEFAULT 1,
  `sy` float DEFAULT 1,
  `sz` float DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `event_checkpoints`
--

CREATE TABLE `event_checkpoints` (
  `id` int(11) NOT NULL,
  `quest_key` varchar(32) NOT NULL DEFAULT '',
  `cp_index` int(11) NOT NULL DEFAULT 0,
  `x` float DEFAULT 0,
  `y` float DEFAULT 0,
  `z` float DEFAULT 0,
  `size` float DEFAULT 3,
  `interior` int(11) DEFAULT 0,
  `world` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `event_config`
--

CREATE TABLE `event_config` (
  `id` tinyint(4) NOT NULL,
  `name` varchar(48) NOT NULL DEFAULT 'Holiday',
  `state` tinyint(4) NOT NULL DEFAULT 0,
  `updated_by` varchar(24) NOT NULL DEFAULT '',
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_config`
--

INSERT INTO `event_config` (`id`, `name`, `state`, `updated_by`, `updated_at`) VALUES
(1, 'Test', 3, 'Punctulet', '2026-09-08 13:51:40');

-- --------------------------------------------------------

--
-- Table structure for table `event_facts`
--

CREATE TABLE `event_facts` (
  `id` int(11) NOT NULL,
  `holiday` varchar(48) NOT NULL DEFAULT '',
  `country` varchar(32) NOT NULL DEFAULT '',
  `fact_en` varchar(160) NOT NULL DEFAULT '',
  `fact_ro` varchar(160) NOT NULL DEFAULT '',
  `enabled` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_facts`
--

INSERT INTO `event_facts` (`id`, `holiday`, `country`, `fact_en`, `fact_ro`, `enabled`) VALUES
(1, 'Dragobete', 'Romania', 'The Romanian day of love, on 24 February. Girls used to wash their face with snow water, believing it kept them beautiful all year.', 'Ziua indragostitilor la romani, pe 24 februarie. Fetele se spalau pe fata cu apa din zapada, crezand ca asa raman frumoase tot anul.', 1),
(2, 'Martisor', 'Romania', 'On 1 March you give a red and white string charm for luck. UNESCO listed the custom in 2017, shared with Bulgaria, Moldova and North Macedonia.', 'Pe 1 martie daruiesti un snur alb-rosu, de noroc. UNESCO a inscris obiceiul in 2017, impreuna cu Bulgaria, Moldova si Macedonia de Nord.', 1),
(3, 'Boboteaza', 'Romania', 'On 6 January a priest throws a cross into icy water and men dive after it. Whoever brings it back is said to have luck all year.', 'Pe 6 ianuarie preotul arunca crucea in apa inghetata si barbatii se arunca dupa ea. Cine o aduce inapoi se zice ca are noroc tot anul.', 1),
(4, 'Sfantul Andrei', 'Romania', 'On the night of 29 November garlic is hung on doors and windows. Folklore says it keeps the strigoi, the restless dead, outside.', 'In noaptea de 29 noiembrie se pune usturoi la usi si la ferestre. Se zice ca tine strigoii afara.', 1),
(5, 'Ziua Nationala', 'Romania', 'On 1 December Romania marks the 1918 Great Union at Alba Iulia. The main parade passes under the Arcul de Triumf in Bucharest.', 'Pe 1 decembrie se sarbatoreste Marea Unire de la Alba Iulia, din 1918. Parada principala trece pe sub Arcul de Triumf, in Bucuresti.', 1),
(6, 'Sanziene', 'Romania', 'On 24 June girls wear wreaths of yellow sanziene flowers, then throw them onto the roof. Where the wreath sticks, the fortune is good.', 'Pe 24 iunie fetele poarta cununi de sanziene galbene, apoi le arunca pe casa. Daca se prinde cununa pe acoperis, e semn bun.', 1),
(7, 'Ignatul', 'Romania', 'On 20 December the household pig is slaughtered for Christmas. The whole village used to help, and the day ended with pomana porcului.', 'Pe 20 decembrie se taie porcul pentru Craciun. Se ajuta tot satul, iar ziua se incheia cu pomana porcului.', 1),
(8, 'Sfantul Nicolae', 'Romania', 'On the night of 5 December children leave their boots by the door. Good ones find sweets, the naughty ones a nuielusa - a wooden switch.', 'In noaptea de 5 decembrie copiii isi lasa ghetutele la usa. Cei cuminti gasesc dulciuri, cei obraznici o nuielusa.', 1),
(9, 'Pastele', 'Romania', 'Red-dyed eggs are tapped against each other with the words Hristos a inviat. The one whose egg does not crack wins the round.', 'Se ciocnesc oua rosii, spunand Hristos a inviat. Castiga cel al carui ou nu se sparge.', 1),
(10, 'Craciunul', 'Romania', 'Carollers go door to door from Christmas Eve. Hosts give them nuts, apples and colaci - and turning them away is considered bad luck.', 'Colindatorii merg din casa in casa din Ajun. Gazdele le dau nuci, mere si colaci - iar sa ii refuzi e semn rau.', 1),
(11, 'Plugusorul', 'Romania', 'On New Year\'s Eve boys go house to house with a decorated plough and a buhai, a friction drum that growls like a bull, wishing a rich harvest.', 'In seara de Anul Nou baietii merg din casa in casa cu plugul impodobit si cu buhaiul, care mugeste ca un taur, urand recolta bogata.', 1),
(12, 'Ziua Unirii Principatelor', 'Romania', 'On 24 January 1859 Moldavia and Wallachia chose the same ruler. Today people join hands in the street and dance the Hora Unirii.', 'Pe 24 ianuarie 1859 Moldova si Tara Romaneasca l-au ales pe acelasi domnitor. Azi lumea se prinde in strada in Hora Unirii.', 1),
(13, 'Armindeni', 'Romania', 'On 1 May a green branch was tied at the gate to guard the household. These days the country mostly spends it outdoors, with mici and beer.', 'Pe 1 mai se punea o ramura verde la poarta, ca sa apere casa. Azi tara o petrece mai ales afara, cu mici si bere.', 1),
(14, 'Rusaliile', 'Romania', 'The Calusari dance a ritual said to heal those taken by the fairies. UNESCO put the Calus ritual on its heritage list in 2008.', 'Calusarii joaca un ritual despre care se spune ca vindeca pe cei luati din Calus. UNESCO a inscris ritualul Calusului in 2008.', 1),
(15, 'Ziua Iei', 'Romania', 'On 24 June the Romanian blouse is celebrated worldwide. The day was started in 2013 by an online community, not by the state.', 'Pe 24 iunie se sarbatoreste ia romaneasca in toata lumea. Ziua a fost pornita in 2013 de o comunitate online, nu de stat.', 1),
(16, 'La Tomatina', 'Spain', 'On the last Wednesday of August the town of Bunol throws about 150 tons of tomatoes at itself. The fight lasts exactly one hour.', 'In ultima miercuri din august, orasul Bunol arunca cu vreo 150 de tone de rosii. Bataia dureaza exact o ora.', 1),
(17, 'Oktoberfest', 'Germany', 'Munich\'s beer festival began in 1810 as a royal wedding party. Despite the name, most of it now happens in September.', 'Festivalul berii din Munchen a inceput in 1810, ca petrecere de nunta regala. In ciuda numelui, azi se tine mai mult in septembrie.', 1),
(18, 'Bastille Day', 'France', 'On 14 July, the Champs-Elysees hosts the oldest regular military parade in Europe, running since 1880.', 'Pe 14 iulie, pe Champs-Elysees are loc cea mai veche parada militara regulata din Europa, tinuta din 1880.', 1),
(19, 'St Patrick\'s Day', 'Ireland', 'On 17 March the world goes green for Ireland\'s patron saint. Chicago has been dyeing its river green for the day since 1962.', 'Pe 17 martie lumea se face verde pentru sfantul patron al Irlandei. Chicago isi vopseste raul in verde de ziua asta din 1962.', 1),
(20, 'Sinterklaas', 'Netherlands', 'On 5 December children leave a shoe by the fireplace, with a carrot in it for the saint\'s horse, and find a present in the morning.', 'Pe 5 decembrie copiii isi lasa un pantof langa semineu, cu un morcov in el pentru calul sfantului, si dimineata gasesc un cadou.', 1),
(21, 'Midsommar', 'Sweden', 'A flower-covered maypole is raised and danced around. Tradition says seven kinds of flowers under your pillow show you your future spouse.', 'Se ridica un stalp acoperit cu flori si se danseaza in jurul lui. Se zice ca sapte feluri de flori sub perna iti arata viitorul sot.', 1),
(22, 'Carnevale di Venezia', 'Italy', 'Venice\'s masked carnival ends on Shrove Tuesday. Its best known mask, the long-beaked plague doctor, was originally medical gear.', 'Carnavalul mascat al Venetiei se termina in Martea Grasa. Cea mai cunoscuta masca, doctorul de ciuma cu cioc lung, era la inceput un echipament medical.', 1),
(23, 'Las Fallas', 'Spain', 'Valencia spends all year building giant papier-mache figures, then burns nearly every one of them in a single night, on 19 March.', 'Valencia construieste tot anul figuri uriase din papier-mache, apoi le arde aproape pe toate intr-o singura noapte, pe 19 martie.', 1),
(24, 'Krampusnacht', 'Austria', 'On 5 December, Krampus - a horned companion of St Nicholas - parades through Alpine towns to frighten the children who misbehaved.', 'Pe 5 decembrie, Krampus - insotitorul cu coarne al Sfantului Nicolae - defileaza prin orasele alpine ca sa sperie copiii neascultatori.', 1),
(25, 'Guy Fawkes Night', 'United Kingdom', 'On 5 November Britain lights bonfires and fireworks to mark the 1605 plot to blow up Parliament - which failed.', 'Pe 5 noiembrie britanicii aprind focuri si artificii pentru complotul din 1605 de a arunca in aer Parlamentul - care a esuat.', 1),
(26, 'San Fermin', 'Spain', 'Pamplona\'s running of the bulls covers 875 metres through the old town. The whole thing is usually over in two to three minutes.', 'Alergarea cu taurii din Pamplona are 875 de metri prin orasul vechi. Totul se termina de obicei in doua-trei minute.', 1),
(27, 'Santa Lucia', 'Sweden', 'On 13 December a girl in a crown of candles leads a procession of singers. The date was the longest night under the old calendar.', 'Pe 13 decembrie o fata cu o coroana de lumanari conduce o procesiune de cantareti. Data era cea mai lunga noapte in vechiul calendar.', 1),
(28, 'La Befana', 'Italy', 'On the night of 5 January an old woman flies in on a broom, leaving sweets for good children and a lump of coal for the rest.', 'In noaptea de 5 ianuarie vine o batrana pe o matura, lasand dulciuri copiilor cuminti si o bucata de carbune celorlalti.', 1),
(29, 'Koningsdag', 'Netherlands', 'On 27 April the whole country dresses in orange and turns into one enormous flea market, where anyone may sell anything, tax free.', 'Pe 27 aprilie toata tara se imbraca in portocaliu si se transforma intr-un urias targ de vechituri, unde oricine poate vinde orice, fara taxe.', 1),
(30, 'Up Helly Aa', 'Scotland', 'On the last Tuesday of January, Lerwick in Shetland marches a replica Viking longship through town and then sets it on fire.', 'In ultima marti din ianuarie, Lerwick din Shetland plimba prin oras o replica de corabie vikinga si apoi ii da foc.', 1);

-- --------------------------------------------------------

--
-- Table structure for table `event_npcs`
--

CREATE TABLE `event_npcs` (
  `id` int(11) NOT NULL,
  `quest_key` varchar(32) NOT NULL DEFAULT '',
  `behaviour` tinyint(4) NOT NULL DEFAULT -1,
  `skin` int(11) NOT NULL DEFAULT 0,
  `health` float DEFAULT 100,
  `x` float DEFAULT 0,
  `y` float DEFAULT 0,
  `z` float DEFAULT 0,
  `angle` float DEFAULT 0,
  `interior` int(11) DEFAULT 0,
  `world` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_npcs`
--

INSERT INTO `event_npcs` (`id`, `quest_key`, `behaviour`, `skin`, `health`, `x`, `y`, `z`, `angle`, `interior`, `world`) VALUES
(2, 'zombie_hunt', -1, 162, 100, 1809.68, -1166.74, 24.2266, 164.302, 0, 0),
(3, 'zombie_hunt', -1, 162, 100, 2286.77, -1355.58, 30.5625, 352.805, 0, 0),
(4, 'zombie_hunt', -1, 162, 100, 2364.98, -1941.15, 13.5469, 325.139, 0, 0),
(5, 'zombie_hunt', -1, 162, 100, 2787.07, -1952.5, 13.5469, 87.4724, 0, 0),
(6, 'zombie_hunt', -1, 162, 100, 2684.78, -1552.05, 23.3962, 79.1676, 0, 0),
(7, 'zombie_hunt', -1, 162, 100, 2676.34, -1539.24, 25.7588, 175.023, 0, 0),
(8, 'zombie_hunt', -1, 162, 100, 2245.21, -2270.67, 14.3751, 323.954, 0, 0),
(9, 'zombie_hunt', -1, 162, 100, 1393.98, -2600.3, 13.5469, 86.0654, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `event_npc_talks`
--

CREATE TABLE `event_npc_talks` (
  `pID` int(11) NOT NULL,
  `npc_id` int(11) NOT NULL,
  `taken_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_npc_talks`
--

INSERT INTO `event_npc_talks` (`pID`, `npc_id`, `taken_at`) VALUES
(1, 9, '2026-09-08 15:12:02');

-- --------------------------------------------------------

--
-- Table structure for table `event_objects`
--

CREATE TABLE `event_objects` (
  `id` int(11) NOT NULL,
  `quest_key` varchar(32) NOT NULL DEFAULT '',
  `model` int(11) NOT NULL DEFAULT 0,
  `x` float DEFAULT 0,
  `y` float DEFAULT 0,
  `z` float DEFAULT 0,
  `rx` float DEFAULT 0,
  `ry` float DEFAULT 0,
  `rz` float DEFAULT 0,
  `interior` int(11) DEFAULT 0,
  `world` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_objects`
--

INSERT INTO `event_objects` (`id`, `quest_key`, `model`, `x`, `y`, `z`, `rx`, `ry`, `rz`, `interior`, `world`) VALUES
(2, 'pumpkin_hunt', 19320, 654.673, -472.297, 16.3359, 0, 0, 131.064, 0, 0),
(3, 'pumpkin_hunt', 19320, 656.399, -813.506, 86.8189, 0, 0, 19.2257, 0, 0),
(4, 'pumpkin_hunt', 19320, 1462.22, -1016.15, 61.1703, 0, 0, 179.364, 0, 0),
(5, 'pumpkin_hunt', 19320, 1954.13, -1372.12, 19.6484, 0, 0, 11.1982, 0, 0),
(6, 'pumpkin_hunt', 19320, 2426.97, -1220.83, 25.4977, 0, 0, 180.786, 0, 0),
(7, 'pumpkin_hunt', 19320, 715.425, -1639.31, 2.4297, 0, 0, 182.332, 0, 0),
(8, 'pumpkin_hunt', 19320, 389.687, -2032.19, 7.8359, 0, 0, 353.837, 0, 0),
(9, 'pumpkin_hunt', 19320, 238.04, -1093.16, 87.0245, 0, 0, 334.994, 0, 0),
(10, 'pumpkin_hunt', 19320, 811.167, -1098.23, 25.9063, 0, 0, 186.107, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `event_pickups`
--

CREATE TABLE `event_pickups` (
  `pID` int(11) NOT NULL,
  `object_id` int(11) NOT NULL,
  `taken_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_pickups`
--

INSERT INTO `event_pickups` (`pID`, `object_id`, `taken_at`) VALUES
(1, 7, '2026-09-08 11:36:18');

-- --------------------------------------------------------

--
-- Table structure for table `event_progress`
--

CREATE TABLE `event_progress` (
  `id` int(11) NOT NULL,
  `pID` int(11) NOT NULL,
  `quest_key` varchar(32) NOT NULL,
  `progress` int(11) DEFAULT 0,
  `claimed` tinyint(1) DEFAULT 0,
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_progress`
--

INSERT INTO `event_progress` (`id`, `pID`, `quest_key`, `progress`, `claimed`, `updated_at`) VALUES
(1, 1, 'pumpkin_hunt', 10, 1, '2026-09-08 11:36:18'),
(18, 1, 'zombie_hunt', 1, 0, '2026-09-08 15:12:02');

-- --------------------------------------------------------

--
-- Table structure for table `event_quests`
--

CREATE TABLE `event_quests` (
  `id` int(11) NOT NULL,
  `quest_key` varchar(32) NOT NULL,
  `type` tinyint(4) NOT NULL DEFAULT 1,
  `name` varchar(48) NOT NULL DEFAULT '',
  `description` varchar(128) NOT NULL DEFAULT '',
  `target` int(11) NOT NULL DEFAULT 1,
  `reward_money` int(11) NOT NULL DEFAULT 0,
  `enabled` tinyint(1) DEFAULT 1,
  `state` tinyint(4) NOT NULL DEFAULT 3,
  `sort_order` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_quests`
--

INSERT INTO `event_quests` (`id`, `quest_key`, `type`, `name`, `description`, `target`, `reward_money`, `enabled`, `state`, `sort_order`) VALUES
(4, 'pumpkin_hunt', 1, 'Pumpkin Hunt', '', 10, 25000, 1, 3, 0),
(5, 'zombie_hunt', 1, 'Interact with zombies', 'Find and interact with 6 zombies around Los Santos.', 6, 30000, 1, 3, 0);

-- --------------------------------------------------------

--
-- Table structure for table `event_skins`
--

CREATE TABLE `event_skins` (
  `id` int(11) NOT NULL,
  `skin` int(11) NOT NULL DEFAULT 0,
  `label` varchar(32) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `event_zones`
--

CREATE TABLE `event_zones` (
  `id` int(11) NOT NULL,
  `quest_key` varchar(32) NOT NULL DEFAULT '',
  `x` float DEFAULT 0,
  `y` float DEFAULT 0,
  `z` float DEFAULT 0,
  `radius` float DEFAULT 50,
  `interior` int(11) DEFAULT 0,
  `world` int(11) DEFAULT 0
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
  `max_members` int(11) NOT NULL DEFAULT 5,
  `application_on` tinyint(1) NOT NULL DEFAULT 1,
  `interior_a` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `factions`
--

INSERT INTO `factions` (`id`, `name`, `members`, `lead`, `bank`, `pickup_id`, `mapicon_id`, `hq_x`, `hq_y`, `hq_z`, `interior_x`, `interior_y`, `interior_z`, `interior`, `vw`, `seif_herbs`, `seif_drugs`, `skin`, `skin1`, `skin2`, `skin3`, `smuggle_cooldown_day`, `max_members`, `application_on`, `interior_a`) VALUES
(1, 'Police Department', 0, '', 12000, 1247, 30, 1554.2, -1675.9, 16.25, 246.812, 63.5707, 1003.64, 6, 0, 0, 0, 0, 266, 281, 265, 0, 6, 1, 0),
(2, 'Department of Motor Vehicles', 0, '', 2850, 1581, 55, 918.405, -1252.19, 16.2109, 246.06, 108.97, 1003.3, 10, 2, 0, 0, 0, 268, 304, 302, 0, 6, 1, 0),
(3, 'SMURD', 0, '', 250, 11738, 22, 1172.71, -1323.21, 15.4017, 2267.75, 1647.55, 1084.23, 1, 3, 0, 0, 0, 276, 277, 274, 0, 6, 1, 270.473),
(4, 'European Mafia', 0, '', 351100, 1314, 58, 1872.64, -2020.46, 13.5469, 2569.41, -1301.77, 1044.12, 2, 4, 684, 5, 0, 114, 115, 116, 0, 6, 1, 0),
(5, 'American Mafia', 0, '', 68200, 1314, 59, 1905.89, -1115.16, 25.9538, 2569.41, -1301.77, 1044.12, 2, 5, 0, 0, 0, 102, 103, 104, 0, 6, 1, 0),
(6, 'African Mafia', 0, '', 62800, 1314, 62, 2495.4, -1688.71, 13.9735, 2569.41, -1301.77, 1044.12, 2, 6, 0, 0, 0, 105, 106, 107, 0, 6, 1, 0),
(7, 'Asian Mafia', 0, '', 64900, 1314, 60, 2231.89, -1159.81, 25.8906, 2569.41, -1301.77, 1044.12, 2, 7, 0, 0, 0, 108, 109, 110, 0, 6, 1, 0),
(8, 'News Reporters', 0, '', 885, 1318, 34, 733.452, -1350.27, 13.5, 322.5, 303.7, 999.2, 5, 8, 0, 0, 0, 273, 48, 46, 0, 6, 1, 0),
(9, 'Loco Outlaw Customs', 1, 'Punctulet', 0, 1314, 27, 681.533, -474.676, 16.5363, 611.35, -77.55, 997.99, 2, 9, 0, 0, 0, 292, 299, 42, 0, 6, 1, 0);

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
(1, 'Pizzeria Montgomery', 1, 2102.94, -1806.71, 13.5547),
(2, 'Burger House', 2, 1214.53, -905.507, 42.6478),
(3, 'Burger Shooooot', 2, 799.88, -1630.01, 13.1099),
(4, 'FatChicken', 3, 925.618, -1352.81, 13.3766),
(5, 'Chicken 20CM', 3, 2409.52, -1487.22, 23.5552),
(6, 'Eat my Donut', 4, 1038.07, -1338.63, 13.7266),
(7, 'CFK RO', 3, 2397.76, -1897.59, 13.5469),
(8, 'Pizza Stack', 1, 1366, 248.928, 19.5669);

-- --------------------------------------------------------

--
-- Table structure for table `forests`
--

CREATE TABLE `forests` (
  `id` int(11) NOT NULL,
  `ownerId` int(11) NOT NULL DEFAULT 0,
  `owner` varchar(24) NOT NULL DEFAULT '',
  `isForSale` tinyint(1) NOT NULL DEFAULT 0,
  `defaultPrice` int(11) NOT NULL DEFAULT 100000,
  `price` int(11) NOT NULL DEFAULT 100000,
  `size` float NOT NULL DEFAULT 0,
  `locX` float NOT NULL DEFAULT 0,
  `locY` float NOT NULL DEFAULT 0,
  `locZ` float NOT NULL DEFAULT 0,
  `maxTree` int(11) NOT NULL DEFAULT 0,
  `currentTree` int(11) NOT NULL DEFAULT 0,
  `saplings` int(11) NOT NULL DEFAULT 0,
  `plantedSaplings` int(11) NOT NULL DEFAULT 0,
  `bank` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `forests`
--

INSERT INTO `forests` (`id`, `ownerId`, `owner`, `isForSale`, `defaultPrice`, `price`, `size`, `locX`, `locY`, `locZ`, `maxTree`, `currentTree`, `saplings`, `plantedSaplings`, `bank`) VALUES
(1, 0, '', 1, 100000, 100000, 0, -145.476, -1572.88, 7.9526, 0, 0, 0, 0, 0),
(2, 0, '', 1, 100000, 100000, 20, 2042.08, -771.581, 122.224, 100, 100, 0, 0, 11100),
(3, 0, '', 1, 100000, 100000, 20, 2389.27, -621.584, 124.388, 100, 100, 0, 0, 11100),
(4, 0, '', 1, 100000, 100000, 20, 2569.52, -135.412, 48.231, 100, 100, 0, 0, 11100),
(5, 0, '', 1, 100000, 100000, 20, 2504.95, 222.788, 42.2102, 100, 100, 0, 0, 11100),
(6, 0, '', 1, 100000, 100000, 20, 989.863, -75.184, 77.2386, 100, 100, 0, 0, 11100),
(7, 0, '', 1, 100000, 100000, 20, 627.107, -362.152, 25.8346, 100, 100, 0, 0, 11100),
(8, 0, '', 1, 100000, 100000, 20, 134.859, -741.701, 39.339, 100, 100, 0, 0, 11100),
(9, 0, '', 1, 5000000, 5000000, 20, 916.11, -495.117, 40.4847, 100, 100, 0, 0, 11100);

-- --------------------------------------------------------

--
-- Table structure for table `fuelstations`
--

CREATE TABLE `fuelstations` (
  `id` int(11) NOT NULL,
  `name` varchar(32) DEFAULT 'Gas Station',
  `locX` float DEFAULT 0,
  `locY` float DEFAULT 0,
  `locZ` float DEFAULT 0,
  `fuelLevel_max` int(11) DEFAULT 5000,
  `fuelLevel_curr` int(11) DEFAULT 4000
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `fuelstations`
--

INSERT INTO `fuelstations` (`id`, `name`, `locX`, `locY`, `locZ`, `fuelLevel_max`, `fuelLevel_curr`) VALUES
(1, 'Gas Station', 1944.05, -1772.49, 13.39, 5000, 4000),
(2, 'Gas Station', 1004.63, -940.135, 42.17, 5000, 4000),
(3, 'Gas Station', 654.976, -564.464, 16.33, 5000, 4000),
(4, 'Gas Station', -91.691, -1168.75, 2.44, 5000, 4000),
(5, 'Gas Station', 1462.64, -670.524, 94.75, 5000, 3947);

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
  `capacity` int(11) DEFAULT 5,
  `items` int(11) DEFAULT 200
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `hotels`
--

INSERT INTO `hotels` (`id`, `name`, `owner`, `owner_id`, `owned`, `is_for_sale`, `price`, `loc_x`, `loc_y`, `loc_z`, `bank`, `is_rentable`, `rent_price`, `renter_id`, `capacity`, `items`) VALUES
(1, 'Hotel 1', 'Punctulet', 1, 1, 0, 50000, 1519.15, -1451.87, 14.2031, 100, 0, 0, 0, 2, 200),
(2, 'Hotel 2', '', 0, 0, 1, 50000, 1332.36, -985.285, 33.8966, 0, 0, 0, 0, 5, 200),
(3, 'Hotel 3', '', 0, 0, 1, 50000, 1023.82, -981.757, 42.6307, 0, 0, 0, 0, 5, 200),
(4, 'Hotel 4', '', 0, 0, 1, 50000, 952.886, -911.671, 45.7656, 0, 0, 0, 0, 5, 200),
(5, 'Hotel 5', '', 0, 0, 1, 50000, 609.042, -1459.49, 14.3925, 0, 0, 0, 0, 5, 200),
(6, 'Hotel 6', '', 0, 0, 1, 50000, 867.5, -1797.06, 13.8064, 0, 0, 0, 0, 5, 200),
(7, 'Hotel 7', '', 0, 0, 1, 50000, 1420.61, -1624.06, 13.5469, 0, 0, 0, 0, 5, 200),
(8, 'Hotel 8', '', 0, 0, 1, 50000, 2379.09, -1197.2, 27.4223, 0, 0, 0, 0, 5, 200),
(9, 'Hotel 9', '', 0, 0, 1, 50000, 2657.86, -1392.55, 30.4246, 0, 0, 0, 0, 5, 200),
(10, 'Hotel 10', '', 0, 0, 1, 50000, 2752.48, -1962.53, 13.5469, 75, 0, 0, 0, 5, 200),
(12, 'San Andreas Motel', '', 0, 0, 1, 50000, 2178.44, -1770.24, 13.5453, 0, 0, 0, 0, 5, 200);

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
  `interior` int(11) DEFAULT 0,
  `int_x` float DEFAULT 0,
  `int_z` float DEFAULT 0,
  `int_y` float DEFAULT 0,
  `tree_id` int(11) DEFAULT 0,
  `default_price` int(11) DEFAULT 50000,
  `issue` int(11) DEFAULT 0,
  `is_rentable` tinyint(4) DEFAULT 0,
  `rent_price` int(11) DEFAULT 0,
  `renter_id` int(11) DEFAULT 0,
  `bed_Exp` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `houses`
--

INSERT INTO `houses` (`id`, `name`, `owner`, `owner_id`, `owned`, `price`, `loc_x`, `loc_y`, `loc_z`, `type`, `max_pets`, `pets`, `has_fridge`, `fridge_milk`, `fridge_banana`, `fridge_water`, `fridge_juice`, `fridge_beer`, `bank`, `is_for_sale`, `sgr`, `trash`, `has_bed`, `fridge_expire`, `interior`, `int_x`, `int_z`, `int_y`, `tree_id`, `default_price`, `issue`, `is_rentable`, `rent_price`, `renter_id`, `bed_Exp`) VALUES
(1, 'Gara', '', 0, 0, 2000000, 666.914, -1880.77, 5.46, 4, 5, 0, 1, 20, 10, 0, 0, 0, 0, 1, 0, 0, 1, 0, 2, 225.57, 1082.14, 1240.06, 4, 2000000, 0, 1, 0, 0, '2026-08-26'),
(2, 'Fort Carson Backroads #1', '', 0, 0, 2000000, 745.359, -555.508, 18.0129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(3, 'Fort Carson Backroads #2', '', 0, 0, 2000000, 768.306, -504.694, 18.0129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(4, 'Fort Carson Backroads #3', '', 0, 0, 2000000, 794.73, -507.133, 18.0129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(5, 'Tiera Rabada Ridgehouse #1', '', 0, 0, 2000000, 818.428, -510.284, 18.0129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(6, 'Tiera Rabada Ridgehouse #2', '', 0, 0, 2000000, 314.3, -121.157, 3.5354, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(7, 'Tiera Robada Ridgehouse #3', '', 0, 0, 2000000, 251.379, -92.3421, 3.5354, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(8, 'Tiera Robada Ridgehouse #4', '', 0, 0, 2000000, 2362.03, 141.95, 28.4453, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(9, 'Bone County #1', '', 0, 0, 2000000, 2325.58, 136.442, 28.4453, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(10, 'Bone County #2', '', 0, 0, 2000000, 2413.75, 60.2364, 28.4416, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(11, 'Mediterranean House #1', '', 0, 0, 2000000, 794.524, -1707.41, 14.0382, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(12, 'Mediterranean House #2', '', 0, 0, 2000000, 768.161, -1696.33, 5.1554, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(13, 'Mediterranean House #3', '', 0, 0, 2000000, 695.109, -1645.95, 4.0512, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(14, 'Mediterranean House #4', '', 0, 0, 2000000, 653.058, -1714.28, 14.7648, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(15, 'Beach house #1', '', 0, 0, 2000000, 316.218, -1770.34, 4.6583, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(16, 'Beach house #2', '', 0, 0, 2000000, 168.107, -1769.14, 4.4754, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(17, 'Beach house #3', '', 0, 0, 2000000, 207.245, -1770.62, 4.3305, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(18, 'Vinewood house #1', '', 0, 0, 2000000, 142.958, -1468.92, 25.2036, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(19, 'Vinewood house #2', '', 0, 0, 2000000, 255.26, -1366.15, 53.1094, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(20, 'Vinewood house #3', '', 0, 0, 2000000, 297.848, -1337.25, 53.4415, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(21, 'Vinewood house #4', '', 0, 0, 2000000, 190.46, -1308.48, 70.2665, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(22, 'Vinewood house #5', '', 0, 0, 2000000, 252.203, -1220.89, 75.758, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(23, 'Vinewood house #6', '', 0, 0, 2000000, 300.077, -1154.78, 81.2348, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(24, 'Vinewood house #7', '', 0, 0, 2000000, 698.804, -1059.31, 49.4217, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(25, 'Vinewood house #8', '', 0, 0, 2000000, 828.259, -858.827, 70.3308, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(26, 'Vinewood house #9', '', 0, 0, 2000000, 1111.49, -741.719, 100.133, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(27, 'Vinewood house #10', '', 0, 0, 2000000, 1331.22, -631.938, 109.135, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(28, 'Vinewood house #11', '', 0, 0, 2000000, 1527.47, -773.235, 80.5781, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(29, 'Vinewood house #12', '', 0, 0, 2000000, 1468.96, -904.904, 54.8359, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(30, 'Vinewood house #13', '', 0, 0, 2000000, 1421.92, -885.593, 50.663, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(31, 'PnS Appartment #1', '', 0, 0, 2000000, 1050.95, -1057.88, 34.7969, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(32, 'PnS Appartment #2', '', 0, 0, 2000000, 993.673, -1057.93, 33.7031, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(33, 'PnS Appartment #3', '', 0, 0, 2000000, 1118.1, -1023.43, 34.9922, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(34, 'Temple Appartment #1', '', 0, 0, 2000000, 1190.18, -1018.13, 32.5469, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(35, 'Temple Appartment #2', '', 0, 0, 2000000, 1195.13, -1010.47, 36.2267, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(36, 'Temple Appartment #3', '', 0, 0, 2000000, 1195.31, -1017.02, 36.2344, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(37, 'Temple Appartment #4', '', 0, 0, 2000000, 1227.62, -1017.43, 36.3359, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(38, 'Temple Appartment #5', '', 0, 0, 2000000, 1242.47, -1075.08, 31.5547, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(39, 'Temple Appartment #6', '', 0, 0, 2000000, 1242.5, -1077.82, 31.5547, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(40, 'Temple Appartment #7', '', 0, 0, 2000000, 1285, -1088.74, 28.2578, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(41, 'Temple Appartment #8', '', 0, 0, 2000000, 1320.45, -1082.16, 25.5954, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(42, 'Temple Appartment #9', '', 0, 0, 2000000, 1326.84, -1098.43, 25.4001, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000000, 0, 0, 0, 0, NULL),
(43, 'Admin House', 'Punctulet', 1, 1, 2000000, 2066.12, -1703.5, 14.1484, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1790449003, 6, 234.28, 1084.21, 1065.22, 0, 2000000, 0, 0, 0, 0, NULL);

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
  `aDeceased` tinyint(1) DEFAULT 0,
  `isOnPlayer` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `houses_animals`
--

INSERT INTO `houses_animals` (`aID`, `aType`, `aPlayerID`, `aHouseID`, `aName`, `aDefaultName`, `aAge`, `aDeceased`, `isOnPlayer`) VALUES
(1, 1609, 1, 1, 'Ronal', 'Turtle', 86, 0, 0),
(2, 19078, 1, 1, 'Parrot', 'Parrot', 18, 0, 0),
(3, 19078, 1, 1, 'Parrot', 'Parrot', 16, 0, 0);

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
(4, 1, 0, 'Tree', 1785263901, 30, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `ips`
--

CREATE TABLE `ips` (
  `id` int(11) NOT NULL,
  `ip` varchar(45) NOT NULL,
  `isOnline` tinyint(1) DEFAULT 0,
  `playerName` varchar(24) NOT NULL,
  `lastLogin` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ips`
--

INSERT INTO `ips` (`id`, `ip`, `isOnline`, `playerName`, `lastLogin`) VALUES
(1, '127.0.0.1', 0, 'Punctulet6', '2026-08-14 10:37:12'),
(3, '127.0.0.1', 0, 'Punctulet', '2026-09-08 14:58:59');

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
(2, 'examB', 407.63, -1805.96, 7.82, 'Examen B - start (/examB)', 0, 0, 1, 'Licence'),
(3, 'examC', 2381.53, -2072.59, 13.4935, 'Examen C - start (/examC)', 0, 0, 1, 'Licence'),
(4, 'examD', 1753.71, -1902.55, 13.5631, 'Examen D - start (/examD)', 0, 0, 1, 'Licence'),
(5, 'examP', 1525.5, -2433.17, 13.5547, 'Examen Licenta pilotaj Avioane (plane)', 0, 0, 1, 'Licence'),
(6, 'examH', 1606.38, -2433.17, 13.5547, 'Examen licenta pilotaj elicoptere (Helicopter)', 0, 0, 1, 'Licence'),
(7, 'Golf', 1407.91, 2788.75, 11, 'Terenul de Golf LV', 0, 0, 1, 'Fun'),
(8, 'Basket', 2298.31, -1501.99, 25.3047, '', 0, 0, 1, 'Fun'),
(9, 'lodge', -688.106, 949.078, 12.5, '', 0, 0, 1, 'Fun'),
(11, 'PR/duty', 256.123, 65.5168, 1003.64, 'PR - /duty', 6, 0, 0, ''),
(12, 'jail', 263.748, 77.754, 1001.04, 'Interior JAIL', 6, 0, 0, ''),
(13, 'PR/arrest-left', 1754.33, -1594.06, 13.537, 'Comanda /arrest din stanga', 0, 0, 0, ''),
(14, 'PR/arrest-right', 1825.95, -1538.12, 13.5469, 'Comanda /arrest din dreapta', 0, 0, 0, ''),
(15, 'Vehicle Plate', 867.269, -1205.11, 16.9766, 'Change Vehicle Plate', 0, 0, 1, 'Vehicle'),
(16, 'Vehicle ITP', 831.053, -1205.11, 16.9766, 'Change Vehicle ITP', 0, 0, 1, 'Vehicle'),
(18, 'police_int_to_ext', 246.7, 63.4, 1003.64, 'Police Interior to Exterior', 6, 0, 0, ''),
(19, 'police_int_to_garage', 243.243, 66.3187, 1003.64, 'Police Interior to Garage', 6, 0, 0, ''),
(20, 'police_garage_to_int', 1525.42, -1677.74, 5.91, 'Police Garage to Interior', 0, 0, 0, ''),
(21, 'police_ext_to_int', 1554.2, -1675.9, 16.25, 'Police Exterior to Interior', 0, 0, 0, ''),
(22, 'Hospital', 1173.34, -1361.26, 13.9678, 'Spital - internare (/curedisease)', 0, 0, 1, 'Others'),
(23, 'Hospital2', 2033.96, -1403.3, 17.28, 'Spital 2 - internare (/curedisease)', 0, 0, 1, 'Others'),
(24, 'Hunting', -418.372, -1759.68, 6.2188, 'Hunt deer with /hunt', 0, 0, 1, 'Fun'),
(25, 'Gondola Vinewwood', 1527.34, -682.25, 94.75, '', 0, 0, 1, 'Fun'),
(29, 'Cemitery', 946.235, -1103.36, 24.2742, 'Biserica Los Santos', 0, 0, 1, 'Others'),
(30, 'Casino', 1022.57, -1122.42, 23.8713, 'Casino - Entrace', 0, 0, 1, 'Fun'),
(31, 'S.G.R.', 2411.85, -1426.5, 23.7, 'Sell your SGR.', 0, 0, 1, 'Others'),
(32, 'Trash unload', 2122.97, -2015.28, 13.6, 'Trash unload point', 0, 0, 1, 'Others'),
(33, 'ANAF', 1765.24, -1343.33, 915.75, 'ANAF /biz givedocs', 0, 0, 1, 'ANAF'),
(40, 'examW', 1883.87, -1270.38, 13.54, 'Examen W - start (/examW)', 0, 0, 1, 'Licence'),
(45, 'LOC\'s Garage #1', 711.36, -448.54, 16.2, 'LOC\'s Garage #1 - tuning point', 0, 0, 1, 'Vehicle'),
(46, 'LOC\'s Garage #2', 2520.3, -1483.03, 24, 'LOC\'s Garage #2 - tuning point', 0, 0, 1, 'Vehicle'),
(47, 'LOC\'s Garage #3', 2445.76, -1975.75, 13.54, 'LOC\'s Garage #3 - tuning point', 0, 0, 1, 'Vehicle'),
(50, 'ad W LS', 914.5, -1003.31, 38, 'Locatie pentru /ad West LS', 0, 0, 1, 'CNN'),
(51, 'ad S LS', 1448.95, -2286.96, 13.54, 'Locatie pentru /ad South LS', 0, 0, 1, 'CNN'),
(52, 'ad E LS', 1853.65, -1145.18, 23.85, 'Locatie pentru /ad East LS', 0, 0, 1, 'CNN'),
(55, 'Arrest Me', 1798.31, -1578.39, 14.08, '/arrestme if wanted 2+, and no cops on-duty', 0, 0, 1, 'Others'),
(56, 'Market', 2793.99, -1828.49, 9.86, 'Vehicles Market', 0, 0, 1, 'Vehicle'),
(60, 'W LosSantos Station', 824.527, -1361.05, -0.5078, 'West Los Santos Train Station', 0, 0, 1, 'Public Transport'),
(61, 'S LosSantos Station', 1738.98, -1950.01, 14.1172, 'South Los Santos Train Station', 0, 0, 1, 'Public Transport'),
(62, 'E LosSantos Station', 2261.17, -1507.29, 21.5038, 'East Los Santos Train Station', 0, 0, 1, 'Public Transport'),
(65, 'Church: Ascendant Spire', 1772.15, -1655.65, 14.4246, 'The Ascendants - church', 0, 0, 1, 'Others'),
(66, 'Church: Holy Order Chapel', 1719.92, -1740.49, 13.5469, 'The Holy Order - church', 0, 0, 1, 'Others'),
(67, 'Church: Santa Luz Chapel', 2232.75, -1333.13, 23.9815, 'The Divine Blessing (Santa Luz) - church', 0, 0, 1, 'Others'),
(70, 'West Santos Car Wash', 767.412, -1432.36, 13.2602, '/v wash - west los santos', 0, 0, 1, 'Vehicle'),
(71, 'East Santos Car Wash', 2454.02, -1460.95, 24, '/v wash East Los Santos', 0, 0, 1, 'Vehicle'),
(72, 'North Santos Car Wash', 1017.75, -917.807, 41.7341, '/v wash North Los Santos', 0, 0, 1, 'Vehicle'),
(73, 'South Santos Car Wash', 1911.19, -1776.52, 13.3828, '/v wash South Los Santos', 0, 0, 1, 'Vehicle'),
(100, 'lspd_barrier', 1544.7, -1630.9, 13.24, 'Bariera LSPD (horn factiune 1)', 0, 0, 0, ''),
(101, 'Job Glovo Delivery', 1013.5, -1366.97, 13.36, 'Job 1 - Glovo Delivery', 0, 0, 1, 'Job'),
(102, 'Job Cement Truck Driver', 334.62, 871.524, 20.4, 'Job 2 - Cement Truck Driver', 0, 0, 1, 'Job'),
(103, 'Job Gun Delivery', 2501.69, -2618.84, 13.71, 'Job 3 - Gun Delivery', 0, 0, 1, 'Job'),
(104, 'Job Car Transportator', 1984.05, -2065.85, 14.01, 'Job 4 - Car Transportator', 0, 0, 1, 'Job'),
(106, 'Job Emergency Logistics Driver', 1112.39, -1232.44, 15.82, 'Job 6 - Emergency Logistics Driver', 0, 0, 1, 'Job'),
(107, 'Job Bus Driver', 1425.45, -2325.27, 13.54, 'Job 7 - Bus Driver', 0, 0, 1, 'Job'),
(108, 'Job Electrician', 2700.15, -1954.21, 13.55, 'Job 8 - Electrician', 0, 0, 1, 'Job'),
(109, 'Job Crop Duster Pilot', 1959.8, -2638.24, 13.54, 'Job 9 - Crop Duster Pilot', 0, 0, 1, 'Job'),
(110, 'Job Water Hauler', 1632.35, -1888.13, 13.55, 'Job 10 - Water Hauler', 0, 0, 1, 'Job'),
(111, 'Job Fish 1', 383.61, -2086.89, 7.83, 'Fish zone 1', 0, 0, 1, 'Job'),
(113, 'Job Fuel carrier', 2439.75, -2244.22, 15.56, 'Job 13 - Fuel carrier', 0, 0, 1, 'Job'),
(114, 'Job Truck Driver', 2802.66, -1541.75, 12, 'Job 13 - Truck driver', 0, 0, 1, 'Job'),
(115, 'Job Currency Transportation', 1655.85, -1695.39, 20.6, 'Job 15 - Job Currency Transportation Service', 0, 0, 1, 'Job'),
(116, 'Beach groomer', 322.96, -1828.51, 4, 'Job 16 - Beach groomer', 0, 0, 1, 'Job'),
(146, 'Job Fish 3', 2938.01, -2051.49, 3.27, 'Fish zone 2', 0, 0, 1, 'Job'),
(147, 'Job Fish 2', 820.32, -1952.68, 12.86, 'Fish zone 3', 0, 0, 1, 'Job'),
(148, 'taxi-civil', 836.131, -2023.8, 12.8672, '/taxi - Spawn Civil (cood vechi)', 0, 0, 1, 'Public Transport'),
(149, 'taxi-jail', 1807.82, -1599.42, 13.5469, '/taxi - Spawn Jail (coord noi adaugate)', 0, 0, 1, 'Public Transport'),
(150, 'Taxi Market', 2816.53, -1838.46, 11.11, 'Taxi Market location', 0, 0, 1, 'Public Transport'),
(899, 'Cityhall', 1481.22, -1771.37, 18.7958, 'City Hall - exterior (intrare)', 0, 0, 1, 'Others'),
(900, 'cityhall_int', 386.52, 173.63, 1008.38, 'City Hall - interior', 0, 0, 0, ''),
(901, 'GetJob', 358.421, 182.193, 1008.38, 'Job Center - angajare (/getjob)', 0, 0, 0, ''),
(902, 'QuitJob', 359.265, 166.433, 1008.38, 'Job Center - demisie (/quitjob)', 0, 0, 0, ''),
(909, 'Job Uber', 1481.22, -1771.37, 18.7958, 'Starting point of job Uber', 0, 0, 1, 'Job');

-- --------------------------------------------------------

--
-- Table structure for table `market`
--

CREATE TABLE `market` (
  `id` int(11) NOT NULL,
  `loc_x` float DEFAULT 0,
  `loc_y` float DEFAULT 0,
  `loc_z` float DEFAULT 0,
  `rotation` float DEFAULT 0,
  `status` tinyint(4) DEFAULT 0,
  `pID` int(11) DEFAULT 0,
  `date` date DEFAULT NULL,
  `vID` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `market`
--

INSERT INTO `market` (`id`, `loc_x`, `loc_y`, `loc_z`, `rotation`, `status`, `pID`, `date`, `vID`) VALUES
(1, 2858.5, -1873, 10.8649, 10, 1, 0, NULL, 0),
(2, 2859, -1863, 10.8532, 10, 1, 1, '2026-08-28', 0),
(3, 2859.5, -1853, 10.8507, 10, 0, 0, NULL, 0),
(4, 2860, -1843, 10.8357, 10, 0, 0, NULL, 0),
(5, 2860.5, -1833, 10.8054, 10, 0, 0, NULL, 0),
(6, 2861, -1823, 10.7909, 10, 0, 0, NULL, 0),
(7, 2861.5, -1813, 10.7897, 10, 0, 0, NULL, 0),
(8, 2862, -1803, 10.7972, 10, 0, 0, NULL, 0),
(9, 2862.5, -1793, 10.8101, 10, 0, 0, NULL, 0),
(10, 2863, -1783, 10.8141, 10, 0, 0, NULL, 0);

-- --------------------------------------------------------

--
-- Table structure for table `pacate`
--

CREATE TABLE `pacate` (
  `id` int(11) NOT NULL,
  `pID` int(11) NOT NULL,
  `weekNo` int(11) NOT NULL,
  `prayedTimes` int(11) DEFAULT 1,
  `pacat1` tinyint(1) DEFAULT 0,
  `pacat2` tinyint(1) DEFAULT 0,
  `pacat3` tinyint(1) DEFAULT 0,
  `pacat4` tinyint(1) DEFAULT 1,
  `pacat5` tinyint(1) DEFAULT 0,
  `pacat6` tinyint(1) DEFAULT 0,
  `pacat7` tinyint(1) DEFAULT 0,
  `pacat8` tinyint(1) DEFAULT 0,
  `pacat9` tinyint(1) DEFAULT 0,
  `pacat10` tinyint(1) DEFAULT 0,
  `pacat11` tinyint(1) DEFAULT 0,
  `pacat12` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `pacate`
--

INSERT INTO `pacate` (`id`, `pID`, `weekNo`, `prayedTimes`, `pacat1`, `pacat2`, `pacat3`, `pacat4`, `pacat5`, `pacat6`, `pacat7`, `pacat8`, `pacat9`, `pacat10`, `pacat11`, `pacat12`) VALUES
(1, 1, 34, 3, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0),
(4, 1, 36, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1);

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
  `faction_rank` int(11) DEFAULT 0,
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
  `vip` tinyint(4) DEFAULT 0,
  `gamble_wagered` int(11) DEFAULT 0,
  `fishing_rod` tinyint(1) NOT NULL DEFAULT 0,
  `forest_key` int(11) NOT NULL DEFAULT 0,
  `bb_key` int(11) DEFAULT 0,
  `has_gps` tinyint(4) DEFAULT 0,
  `phone_book` tinyint(4) DEFAULT 0,
  `coffee` tinyint(1) DEFAULT 0,
  `register_date` datetime DEFAULT NULL,
  `lastPrayDate` date DEFAULT NULL,
  `religion` tinyint(1) DEFAULT 0,
  `language` varchar(2) DEFAULT 'en',
  `gov_role` tinyint(4) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `players`
--

INSERT INTO `players` (`id`, `username`, `password`, `email`, `level`, `money`, `bank`, `rp`, `admin_level`, `faction`, `house`, `spawn_type`, `faction_rank`, `key1`, `key2`, `key3`, `faction_join`, `business`, `driving_lic_a_exp`, `driving_lic_b_exp`, `driving_lic_c_exp`, `driving_lic_d_exp`, `diseased`, `disease_paydays`, `caravan_key`, `is_president`, `voted`, `was_president`, `job`, `phone_model`, `phone_number`, `medkits`, `extinguishers`, `mute_expire`, `airplane_lic_a_exp`, `airplane_lic_h_exp`, `wanted_level`, `jail_seconds`, `rob_points`, `skin`, `gas_can`, `watch_model`, `phone_expire`, `tired`, `hotel`, `rent_house`, `rent_hotel`, `warns`, `watch_expire`, `weapon_lic_w_exp`, `vip`, `gamble_wagered`, `fishing_rod`, `forest_key`, `bb_key`, `has_gps`, `phone_book`, `coffee`, `register_date`, `lastPrayDate`, `religion`, `language`, `gov_role`) VALUES
(1, 'Punctulet', '112', '', 2, 1954443, 28620853, 201, 6, 9, 43, 2, 5, 1, 2, 4, NULL, 0, '2026-12-30', '2026-12-30', '2026-12-30', '2026-12-30', 0, 0, 1, 0, 0, 1, 16, 3, 79640, 0, 0, 0, '2026-12-30', '2026-12-30', 0, 0, 10, 7, 0, 3, 0, 100, 1, 0, 0, 0, NULL, '0000-00-00', 1, 0, 1, 0, 0, 1, 1, 0, '2026-08-10 11:08:19', '2026-08-25', 3, 'ro', 0),
(2, 'Punctulet6', '', '', 2, 10000, 15000, 0, 0, 0, 0, 1, 0, 0, 0, 0, NULL, 0, '2026-08-14', '2026-08-14', '0000-00-00', '0000-00-00', 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, '0000-00-00', '0000-00-00', 0, 0, 10, 7, -1, -1, 0, 2, 0, 0, 0, 0, NULL, '0000-00-00', 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, 0, 'en', 0);

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
(2, 1, 302, 1),
(3, 2, 7, 1);

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
-- Table structure for table `quests`
--

CREATE TABLE `quests` (
  `id` int(11) NOT NULL,
  `pID` int(11) NOT NULL,
  `weekNo` int(11) NOT NULL,
  `slot` tinyint(1) NOT NULL,
  `progress` int(11) DEFAULT 0,
  `claimed` tinyint(1) DEFAULT 0
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
  `ssValue` varchar(24) DEFAULT NULL,
  `ssText` varchar(128) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `server_setup`
--

INSERT INTO `server_setup` (`ssId`, `ssSetare`, `ssValue`, `ssText`) VALUES
(1, 'min_salary', '2500', NULL),
(2, 'tax', '10', NULL),
(3, 'cass', '10', NULL),
(4, 'bank_interest', '0.05', NULL),
(5, 'insurance_price', '500', NULL),
(6, 'medkit_price', '500', NULL),
(7, 'extinguisher_price', '500', NULL),
(8, 'gascan_price', '500', NULL),
(9, 'itp_price', '750', NULL),
(10, 'plate_price', '250', NULL),
(11, 'rent_bike_price', '15', NULL),
(12, 'exam_a_price', '1000', NULL),
(13, 'exam_b_price', '1500', NULL),
(14, 'exam_c_price', '2000', NULL),
(15, 'exam_d_price', '2250', NULL),
(16, 'exam_p_price', '800', NULL),
(17, 'exam_h_price', '900', NULL),
(18, 'pizza_price', '50', NULL),
(19, 'burger_price', '55', NULL),
(20, 'meal_price', '60', NULL),
(21, 'desert_price', '30', NULL),
(22, 'farm_tractor_price', '10000', NULL),
(23, 'farm_dozer_price', '15000', NULL),
(24, 'farm_combine_price', '20000', NULL),
(25, 'farm_truck_price', '12500', NULL),
(26, 'farm_trailer_price', '10000', NULL),
(27, 'shovel_price', '2500', NULL),
(28, 'phone_sim_price', '250', NULL),
(29, 'phone_price_1', '1000', NULL),
(30, 'phone_price_2', '2000', NULL),
(31, 'phone_price_3', '1600', NULL),
(32, 'phone_price_4', '2200', NULL),
(33, 'phone_price_5', '500', NULL),
(34, 'watch_price_1', '300', NULL),
(35, 'watch_price_2', '700', NULL),
(36, 'watch_price_3', '1000', NULL),
(37, 'watch_price_4', '10000', NULL),
(64, 'weapon_colt45_price', '5000', NULL),
(65, 'weapon_deagle_price', '7500', NULL),
(66, 'weapon_shotgun_price', '50000', NULL),
(67, 'weapon_mp5_price', '10000', NULL),
(68, 'weapon_ak47_price', '25000', NULL),
(69, 'weapon_m4_price', '20000', NULL),
(70, 'weapon_uzi_price', '9000', NULL),
(2183, 'phonebook_price', '2000', NULL),
(2184, 'gps_price', '200', NULL),
(2185, 'sapling_price', '10', NULL),
(2186, 'fishingrod_price', '300', NULL),
(2187, 'chainsaw_price', '1500', NULL),
(2188, 'bag_price_small', '10', NULL),
(2189, 'bag_price_medium', '30', NULL),
(2190, 'bag_price_large', '70', NULL),
(6559, 'treasury', '26938', NULL),
(6560, 'charity_fund', '10', NULL),
(6561, 'charity_cause', NULL, 'No cause set'),
(7780, 'temperature', '22', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `shops`
--

CREATE TABLE `shops` (
  `shopID` int(11) NOT NULL,
  `shopLocX` float DEFAULT 0,
  `shopLocY` float DEFAULT 0,
  `shopLocZ` float DEFAULT 0,
  `shopName` varchar(32) NOT NULL DEFAULT '24/7 Shop',
  `type` tinyint(1) NOT NULL DEFAULT 1,
  `stock_max` int(11) DEFAULT 100,
  `stock_curr` int(11) DEFAULT 100
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `shops`
--

INSERT INTO `shops` (`shopID`, `shopLocX`, `shopLocY`, `shopLocZ`, `shopName`, `type`, `stock_max`, `stock_curr`) VALUES
(1, 1142.99, -1520.15, 15.7969, 'Carifura 24/7', 1, 100, 100),
(2, 822.054, -1758.33, 13.6484, 'Alex Nostalgia', 2, 100, 100),
(3, 1352.3, -1758.31, 13.5078, 'BilaMare', 1, 100, 100),
(4, 2163.22, -1744.15, 13.5469, 'evlogMag', 2, 100, 100),
(5, 2423.07, -1742.42, 13.5469, 'Carifura Center', 1, 100, 100),
(6, 2362.68, -1339.17, 24.0078, 'At 2 steps', 1, 100, 100),
(7, 1315.33, -899.083, 39.5781, 'LaUnealta SRL', 3, 100, 100),
(8, 2002.84, -1282.41, 23.9733, 'Didi-Man', 3, 100, 100),
(9, 994.824, -1297.04, 13.5469, 'IniMini Market', 1, 100, 100),
(10, 841.601, -2047.8, 12.8672, 'Ca-nau-fland', 1, 100, 100),
(11, 975.431, -1335.86, 13.5318, 'Leroi Gicuta', 3, 100, 100),
(12, 2101.14, -1360.92, 23.9844, 'eMagazinul', 2, 100, 100),
(13, 2246.37, 49.5054, 26.4844, 'Horny Bach', 3, 100, 100),
(14, 1832.5, -1842.55, 13.5781, 'Universal Market', 1, 100, 100),
(15, 1099.83, -1474.35, 15.7969, 'ElectronicSRL', 2, 100, 100),
(16, 332.847, -1338.54, 14.5078, '24/7 Shop', 4, 100, 100),
(17, 673.309, -646.66, 16.3359, '24/7 Shop', 4, 100, 100),
(18, 2714.19, -1120.82, 69.5781, '24/7 Shop', 4, 100, 100);

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
(1, 4, '#1', 1853, -1462, 2068, -1257, 1, '3366CC88', 1),
(2, 5, '#2', 2074, -1386, 2274, -1218, 1, 'AA44AA88', 2),
(3, 6, '#3', 2409, -1091, 2614, -926, 1, '44AA4488', 3),
(4, 7, '#4', 2451, -1442, 2644, -1254, 1, 'FFCC0088', 4),
(5, 4, '#5', 2731, -1489, 2881, -1258, 1, '3366CC88', 5),
(6, 5, '#6', 2214, -1830, 2414, -1731, 1, 'AA44AA88', 6),
(7, 6, '#7', 1656, -2166, 1830, -2052, 1, '44AA4488', 7),
(8, 7, '#8', 2216, -1972, 2413, -1873, 1, 'FFCC0088', 8),
(9, 4, '#9', 2720, -2050, 2834, -1891, 1, '3366CC88', 0),
(10, 5, '#10', 2184, -2657, 2275, -2483, 1, 'AA44AA88', 0);

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
  `fuel` float DEFAULT 100,
  `wheels` int(11) DEFAULT 0,
  `wheels_exp` date DEFAULT NULL,
  `km` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `vehicles_faction`
--

INSERT INTO `vehicles_faction` (`id`, `faction_id`, `model_id`, `loc_x`, `loc_y`, `loc_z`, `rotation`, `color1`, `color2`, `fuel`, `wheels`, `wheels_exp`, `km`) VALUES
(1, 3, 560, 1189.21, -1347, 13.2719, 0, 175, 1, 100, 0, NULL, 0),
(2, 3, 560, 1189.3, -1302.52, 13.2601, 180, 175, 1, 100, 0, NULL, 0),
(3, 3, 489, 1212.19, -1308.16, 13.6996, 180, 175, 1, 100, 0, NULL, 0),
(4, 3, 489, 1212.43, -1334.59, 13.7107, 0, 175, 1, 100, 0, NULL, 0),
(5, 3, 407, 1177.47, -1309.14, 14.0944, 270, 175, 1, 100, 0, NULL, 0),
(6, 3, 407, 1212.37, -1300.47, 13.7882, 0, 175, 1, 100, 0, NULL, 0),
(7, 3, 407, 1212.62, -1342.93, 13.807, 180, 175, 1, 100, 0, NULL, 0),
(8, 3, 407, 1178.87, -1339.81, 14.1021, 270, 175, 1, 100, 0, NULL, 0),
(9, 3, 416, 1184.63, -1329.13, 13.7163, 270, 175, 1, 100, 0, NULL, 0),
(10, 3, 416, 1184.49, -1334.09, 13.7204, 270, 175, 1, 100, 0, NULL, 0),
(11, 3, 416, 1184.5, -1317.24, 13.7193, 270, 175, 1, 100, 0, NULL, 0),
(12, 3, 416, 1184.58, -1313.15, 13.7142, 270, 175, 1, 100, 0, NULL, 0),
(13, 1, 523, 1542, -1685, 13.1224, 90, 1, 0, 100, 0, NULL, 0),
(14, 1, 523, 1542, -1689, 13.1232, 90, 1, 0, 100, 0, NULL, 0),
(15, 1, 523, 1542, -1693, 13.1185, 90, 1, 0, 100, 0, NULL, 0),
(16, 1, 523, 1542, -1665, 13.1255, 90, 1, 0, 100, 0, NULL, 0),
(17, 1, 523, 1542, -1661, 13.2355, 90, 1, 0, 100, 0, NULL, 0),
(18, 1, 523, 1542, -1657, 13.1082, 90, 1, 0, 100, 0, NULL, 0),
(19, 1, 596, 1536.07, -1677.92, 13.1305, 180, 1, 0, 100, 0, NULL, 0),
(20, 1, 596, 1536.01, -1666.99, 13.1303, 0, 1, 0, 99.87, 0, NULL, 0),
(21, 1, 596, 1546.44, -1676.17, 5.6366, 90, 1, 0, 100, 0, NULL, 0),
(22, 1, 596, 1546.59, -1684.52, 5.6356, 90, 1, 0, 100, 0, NULL, 0),
(23, 1, 596, 1528.01, -1684.03, 5.6344, 270, 1, 0, 100, 0, NULL, 0),
(24, 1, 427, 1538.66, -1644.44, 6.0275, 180, 1, 0, 100, 0, NULL, 0),
(25, 1, 427, 1530.75, -1644.61, 6.0176, 180, 1, 0, 100, 0, NULL, 0),
(26, 1, 599, 1546.38, -1667.78, 6.079, 90, 1, 0, 100, 0, NULL, 0),
(27, 1, 599, 1546.19, -1659, 6.0808, 90, 1, 0, 100, 0, NULL, 0),
(28, 2, 552, 886.718, -1270.78, 14.4037, 0, 155, 155, 100, 0, NULL, 0),
(29, 2, 552, 891.255, -1270.74, 14.411, 0, 155, 155, 100, 0, NULL, 0),
(30, 2, 552, 896.771, -1270.4, 14.4154, 0, 155, 155, 100, 0, NULL, 0),
(31, 2, 498, 905.663, -1237.73, 16.3328, 0, 155, 155, 100, 0, NULL, 0),
(32, 2, 525, 904.499, -1254.15, 14.9391, 90, 155, 155, 76.63, 0, NULL, 0),
(33, 2, 525, 904.514, -1247.1, 15.3917, 90, 155, 155, 96.22, 0, NULL, 0),
(34, 2, 525, 904.181, -1260.35, 14.738, 90, 155, 155, 100, 0, NULL, 0),
(35, 2, 443, 871.136, -1235.11, 15.9534, 270, 155, 155, 100, 0, NULL, 0),
(36, 2, 568, 862.295, -1245.45, 14.6699, 270, 155, 155, 100, 0, NULL, 0),
(37, 2, 568, 862.299, -1255.67, 14.6595, 270, 155, 155, 100, 0, NULL, 0),
(38, 4, 579, 1871.56, -2039.62, 13.4834, 250, 135, 6, 40.24, 0, NULL, 0),
(39, 4, 579, 1896.09, -2037.47, 13.4816, 120, 135, 6, 99.65, 0, NULL, 0),
(40, 4, 429, 1892.17, -2029.11, 13.2266, 150, 135, 6, 99.86, 0, NULL, 0),
(41, 4, 429, 1892.31, -2023.48, 13.2246, 150, 135, 6, 99.7, 0, NULL, 0),
(42, 4, 560, 1891.07, -2015.08, 13.2475, 150, 135, 6, 99.64, 0, NULL, 0),
(43, 4, 560, 1874.77, -2015.44, 13.2504, 220, 135, 6, 99.63, 0, NULL, 0),
(44, 4, 468, 1880.76, -2008, 13.216, 180, 135, 6, 99.49, 0, NULL, 0),
(45, 4, 468, 1878.94, -2008.05, 13.2154, 180, 135, 6, 99.82, 0, NULL, 0),
(46, 4, 468, 1877.12, -2008.01, 13.2161, 180, 135, 6, 99.78, 0, NULL, 0),
(47, 4, 521, 1885.4, -2008.23, 13.1173, 180, 135, 6, 99.78, 0, NULL, 0),
(48, 4, 521, 1887.36, -2008.1, 13.1178, 180, 135, 6, 99.83, 0, NULL, 0),
(49, 4, 521, 1889.29, -2008.09, 13.1197, 180, 135, 6, 99.81, 0, NULL, 0),
(50, 5, 468, 1894.84, -1115.77, 25.0939, 165.128, 147, 162, 99.85, 0, NULL, 0),
(51, 5, 468, 1892.4, -1114.81, 24.9426, 179.583, 147, 162, 99.76, 0, NULL, 0),
(52, 5, 468, 1895.05, -1119.77, 25.1616, 159.539, 147, 162, 99.85, 0, NULL, 0),
(53, 5, 521, 1908.38, -1114.43, 25.2329, 182.577, 147, 162, 99.65, 0, NULL, 0),
(54, 5, 521, 1910.36, -1114.13, 25.2353, 185.166, 147, 162, 99.79, 0, NULL, 0),
(55, 5, 521, 1912.38, -1114.14, 25.2372, 178.101, 147, 162, 99.86, 0, NULL, 0),
(56, 5, 579, 1899.4, -1118.83, 25.6155, 180.219, 147, 162, 99.28, 0, NULL, 0),
(57, 5, 579, 1902.92, -1118.91, 25.6529, 179.628, 147, 162, 99.63, 0, NULL, 0),
(58, 5, 560, 1917.94, -1129.2, 24.6339, 89.9113, 147, 162, 99.75, 0, NULL, 0),
(59, 5, 560, 1896.45, -1142.44, 24.0939, 270.36, 147, 162, 99.49, 0, NULL, 0),
(60, 5, 429, 1905.13, -1142.07, 24.29, 271.027, 147, 162, 99.72, 0, NULL, 0),
(61, 5, 429, 1918.15, -1142.27, 24.6144, 89.467, 147, 162, 99.67, 0, NULL, 0),
(62, 6, 468, 2497.26, -1687, 13.1508, 10.9462, 235, 235, 99.8, 0, NULL, 0),
(63, 6, 468, 2498.89, -1686.94, 13.1617, 13.4526, 235, 235, 99.75, 0, NULL, 0),
(64, 6, 468, 2500.73, -1686.72, 13.1727, 20.2733, 235, 235, 99.77, 0, NULL, 0),
(65, 6, 521, 2491.69, -1686.59, 13.0829, 5.2384, 235, 235, 76.62, 0, NULL, 0),
(66, 6, 521, 2489.48, -1686.59, 13.0821, 6.9277, 235, 235, 99.76, 0, NULL, 0),
(67, 6, 521, 2487.13, -1686.8, 13.0802, 2.2202, 235, 235, 99.69, 0, NULL, 0),
(68, 6, 579, 2507.45, -1678.25, 13.3983, 143.299, 235, 235, 99.82, 0, NULL, 0),
(69, 6, 579, 2516.83, -1672.81, 13.9253, 68.521, 235, 235, 99.69, 0, NULL, 0),
(70, 6, 429, 2476.58, -1693.17, 13.1947, 22.5667, 235, 235, 99.56, 0, NULL, 0),
(71, 6, 429, 2467.53, -1689.21, 13.193, 272.105, 235, 235, 99.74, 0, NULL, 0),
(72, 6, 560, 2499.47, -1655.96, 13.1076, 83.1457, 235, 235, 99.62, 0, NULL, 0),
(73, 6, 560, 2470.15, -1671.37, 13.0699, 9.1035, 235, 235, 99.55, 0, NULL, 0),
(74, 7, 429, 2217.2, -1171.3, 25.4062, 268.704, 228, 228, 99.77, 0, NULL, 0),
(75, 7, 429, 2205.49, -1173.07, 25.4076, 268.816, 228, 228, 99.84, 0, NULL, 0),
(76, 7, 521, 2204.26, -1152.22, 25.3195, 272.581, 228, 228, 99.23, 0, NULL, 0),
(77, 7, 521, 2204.25, -1155.08, 25.3111, 270.594, 228, 228, 99.71, 0, NULL, 0),
(78, 7, 521, 2204.27, -1157.8, 25.3125, 270.504, 228, 228, 99.79, 0, NULL, 0),
(79, 7, 468, 2231.95, -1155.12, 25.5448, 57.8942, 228, 228, 99.76, 0, NULL, 0),
(80, 7, 468, 2232.13, -1162.55, 25.5253, 70.3296, 228, 228, 99.74, 0, NULL, 0),
(81, 7, 468, 2232.35, -1164.54, 25.5421, 68.7971, 228, 228, 95.31, 0, NULL, 0),
(82, 7, 579, 2205.05, -1160.91, 25.6686, 271.836, 228, 228, 99.3, 0, NULL, 0),
(83, 7, 579, 2229.25, -1177.68, 25.6579, 89.4945, 228, 228, 99.63, 0, NULL, 0),
(84, 7, 560, 2216.38, -1166.99, 25.4318, 270.607, 228, 228, 99.83, 0, NULL, 0),
(85, 7, 560, 2229.59, -1169.94, 25.4557, 89.7645, 228, 228, 99.4, 0, NULL, 0),
(86, 8, 582, 736.195, -1345.41, 13.7, 270, 232, 232, 85.58, 0, NULL, 0),
(87, 8, 582, 735.926, -1337.21, 13.7, 270, 232, 232, 100, 0, NULL, 0),
(88, 8, 582, 743.625, -1333.87, 13.7, 220, 232, 232, 100, 0, NULL, 0),
(89, 8, 582, 752.155, -1333.65, 13.7, 220, 232, 232, 100, 0, NULL, 0),
(90, 8, 582, 760.693, -1333.82, 13.7, 220, 232, 232, 100, 0, NULL, 0),
(91, 8, 461, 749.066, -1358.03, 13.1, 0, 232, 232, 100, 0, NULL, 0),
(92, 8, 461, 751.331, -1358.28, 13.1, 0, 232, 232, 100, 0, NULL, 0),
(93, 8, 461, 753.932, -1358.23, 13.1, 0, 232, 232, 100, 0, NULL, 0),
(94, 1, 411, 1534.8, -1643.92, 5.6177, 179.226, 1, -1, 100, 0, NULL, 0),
(95, 1, 411, 1546.53, -1650.93, 5.6177, 90.4683, 1, -1, 100, 0, NULL, 0),
(96, 1, 411, 1527.59, -1688.73, 5.6177, 269.266, 1, -1, 100, 0, NULL, 0),
(97, 1, 411, 1546.92, -1680.32, 5.6471, 90.6085, 1, -1, 100, 0, NULL, 0),
(98, 8, 488, 774.192, -1371.66, 16.0085, 1.0298, 232, 232, 100, 0, NULL, 0),
(100, 4, 595, 0, -2480.75, 0.02, 180, 135, 6, 100, 0, NULL, 0),
(101, 5, 595, 2628.45, -2480.83, 0.05, 180, 135, 6, 100, 0, NULL, 0),
(102, 6, 595, 2619.47, -2480.44, 0.05, 180, 235, 235, 100, 0, NULL, 0),
(103, 7, 595, 2609.99, -2480.8, 0.05, 180, 228, 228, 100, 0, NULL, 0),
(104, 9, 463, 690.648, -470.938, 16.0761, 212.747, 249, 249, 99.92, 0, NULL, 0.02),
(105, 9, 581, 690.651, -468.422, 16.133, 216.283, 249, 249, 100, 0, NULL, 0),
(106, 9, 521, 690.66, -465.611, 16.1029, 221.733, 249, 249, 100, 0, NULL, 0),
(107, 9, 536, 695.071, -463.949, 16.0734, 270.345, 249, 249, 93.24, 1085, '2026-09-02', 0),
(108, 9, 536, 668.109, -470.879, 16.0733, 89.8877, 249, 249, 100, 0, NULL, 0),
(109, 9, 534, 668.167, -464.601, 16.0589, 90.9675, 249, 249, 100, 0, NULL, 0),
(110, 9, 575, 696.089, -472.395, 15.9399, 183.023, 249, 249, 99.13, 0, NULL, 0),
(111, 9, 567, 694.446, -459.471, 16.2083, 271.183, 249, 249, 100, 0, NULL, 0),
(112, 9, 535, 708.369, -458.131, 16.0994, 90.1919, 249, 249, 100, 0, NULL, 0),
(113, 9, 562, 674.334, -446.955, 15.9954, 89.8129, 249, 249, 100, 0, NULL, 0),
(114, 9, 560, 688.943, -444.249, 16.0425, 269.602, 249, 249, 100, 0, NULL, 0),
(115, 9, 561, 694.169, -450.795, 16.1501, 180.148, 249, 249, 90.36, 0, NULL, 0),
(116, 9, 455, 657.747, -498.192, 16.7726, 0.1948, 249, 249, 100, 0, NULL, 0),
(117, 0, 409, 1246, -2042.77, 60, 270, 0, 0, 100, 0, NULL, 0),
(118, 0, 490, 1246, -2030.52, 60, 270, 0, 0, 99.98, 0, NULL, 0.01),
(119, 0, 490, 1245.99, -2024.43, 60, 270, 0, 0, 99.78, 0, NULL, 0.16),
(120, 0, 457, 1167, -2042.42, 69, 225, 0, 0, 100, 0, NULL, 0),
(121, 0, 457, 1167, -2032.38, 69, 345, 0, 0, 99.81, 0, NULL, 0.14),
(122, 0, 487, 1153.15, -2019.52, 69.5, 270, 0, 0, 97.03, 0, NULL, 0),
(123, 0, 477, 1246, -2018.63, 60, 270, 0, 0, 96.5, 0, NULL, 2.59),
(124, 0, 477, 1246, -2012.68, 60, 270, 0, 0, 100, 0, NULL, 0);

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
  `count_owners` int(11) DEFAULT 0,
  `vip` tinyint(4) DEFAULT 0,
  `retro_veh` tinyint(4) DEFAULT 0,
  `wheels` int(11) DEFAULT 0,
  `last_start_engine` date DEFAULT NULL,
  `unused_veh` tinyint(4) DEFAULT 0,
  `wheels_exp` date DEFAULT NULL,
  `km` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `vehicles_personal`
--

INSERT INTO `vehicles_personal` (`id`, `owner_id`, `model_id`, `color1`, `color2`, `plate`, `price`, `loc_x`, `loc_y`, `loc_z`, `rotation`, `insurance_exp`, `medkit_exp`, `extinguisher_exp`, `itp_exp`, `locked`, `first_registration`, `from_biz`, `fuel`, `is_confiscated`, `is_for_sale`, `dirty`, `count_owners`, `vip`, `retro_veh`, `wheels`, `last_start_engine`, `unused_veh`, `wheels_exp`, `km`) VALUES
(1, 1, 411, 223, 1, '{AA2700}LS 03 XXX', 1, 2859, -1863, 10.8532, 275, '2026-06-18', '2026-06-17', '2026-06-18', '2026-08-15', 0, '2026-07-01', 0, 91.98, 0, 1, 29, 1, 1, 0, 0, '2026-08-28', 0, NULL, 3.14),
(2, 1, 541, 222, 128, '{0027FF}LS 02 XXX', 5000000, 2074.14, -1707.65, 13.1739, 358.204, '2026-06-22', '2026-06-19', '2026-07-31', '2026-06-01', 0, '2026-06-01', 0, 95.58, 0, 0, 98, 1, 1, 0, 1074, '2026-08-25', 0, NULL, 0.01),
(4, 1, 411, 222, 1, '{FF2700}LS 01 XXX', 1000000, 2072.78, -1688.91, 13.2798, 181.438, '2026-08-05', '2026-08-05', '2026-08-05', '2026-08-06', 0, '2026-07-29', 8, 74.32, 0, 0, 21, 1, 1, 1, 1076, '2026-08-25', 0, NULL, 0.04),
(5, 0, 411, 1, 1, 'LV 5', 1000000, 2147.41, -1143.31, 24.6911, 268.529, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.81, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(6, 0, 411, 1, 1, 'LV 6', 1000000, 2147.05, -1148.32, 24.1413, 269.025, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.77, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(7, 0, 541, 1, 1, 'LV 7', 900000, 2162.88, -1143.71, 24.4721, 91.1427, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.71, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(8, 0, 541, 1, 1, 'LV 8', 900000, 2162.9, -1148.22, 24.0128, 90.718, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.77, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(9, 0, 541, 0, 1, 'LV 9', 900000, 2163.02, -1153.01, 23.5528, 90.5515, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.74, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(10, 0, 560, 1, 1, 'LV 10', 750000, 2146.89, -1152.98, 23.6386, 267.32, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.7, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(11, 0, 560, 1, 1, 'LV 11', 750000, 2146.9, -1157.21, 23.551, 269.889, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.8, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(12, 0, 562, 1, 1, 'LV 12', 600000, 2162.94, -1157.96, 23.4997, 89.844, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.74, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(13, 0, 562, 1, 1, 'LV 13', 600000, 2162.88, -1163.12, 23.4766, 89.0513, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.77, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(14, 0, 451, 1, 1, 'LV 14', 650000, 2146.93, -1161.68, 23.5292, 268.965, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.72, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(15, 0, 451, 1, 1, 'LV 15', 650000, 2147.01, -1166.31, 23.5267, 269.909, NULL, NULL, NULL, NULL, 0, NULL, 8, 99.78, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(16, 0, 522, 1, 1, 'LV 16', 1100000, 2474.79, -1954.59, 12.9858, 359.262, NULL, NULL, NULL, NULL, 0, NULL, 17, 95.26, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(17, 0, 522, 1, 1, 'LV 17', 1100000, 2477.97, -1954.74, 12.9844, 0.3759, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.82, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(18, 0, 522, 1, 1, 'LV 18', 1100000, 2476.42, -1954.83, 12.9819, 359.379, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.77, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(19, 0, 522, 1, 1, 'LV 19', 1100000, 2479.68, -1954.7, 12.986, 0.7223, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.8, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(20, 0, 581, 1, 1, 'LV 20', 700000, 2482.71, -1954.88, 13.0079, 0.427, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.77, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(21, 0, 581, 1, 1, 'LV 21', 700000, 2484.38, -1954.83, 13.0099, 1.1779, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.79, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(22, 0, 581, 1, 1, 'LV 22', 700000, 2486.14, -1954.9, 13.0087, 359.565, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.81, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(23, 0, 461, 1, 1, 'LV 23', 850000, 2489.17, -1954.84, 12.9971, 3.3526, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.77, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(24, 0, 461, 1, 1, 'LV 24', 850000, 2490.77, -1954.86, 12.9968, 356.616, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.73, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(25, 0, 461, 1, 1, 'LV 25', 850000, 2492.28, -1954.8, 12.9954, 3.0746, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.79, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(26, 0, 463, 1, 1, 'LV 26', 900000, 2495.4, -1954.72, 12.9542, 0.6371, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.69, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(27, 0, 463, 1, 1, 'LV 27', 900000, 2497.21, -1954.76, 12.954, 359.312, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.82, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(28, 0, 468, 1, 1, 'LV 28', 550000, 2500.38, -1954.98, 13.0808, 359.916, NULL, NULL, '0000-00-00', NULL, 0, NULL, 17, 99.69, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(29, 0, 468, 1, 1, 'LV 29', 550000, 2503.73, -1954.95, 13.0815, 358.399, NULL, NULL, NULL, NULL, 0, NULL, 17, 99.73, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(30, 0, 489, 1, 1, 'LV 30', 600000, 2052.48, -1903.2, 13.6899, 179.254, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.58, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(31, 0, 489, 1, 1, 'LV 31', 600000, 2058.89, -1903.22, 13.6904, 179.418, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.69, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(32, 0, 579, 1, 1, 'LV 32', 500000, 2069.17, -1903.09, 13.4774, 181.767, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.7, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(33, 0, 579, 1, 1, 'LV 33', 500000, 2064.99, -1903.13, 13.4762, 179.539, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.74, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(34, 0, 400, 1, 1, 'LV 34', 350000, 2064.7, -1940.84, 13.4477, 90.1334, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.79, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(35, 0, 400, 1, 1, 'LV 35', 350000, 2056.66, -1941.04, 13.4516, 270.59, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.65, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(36, 0, 422, 1, 1, 'LV 36', 200000, 2038.12, -1941.11, 13.3505, 270.408, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.6, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0),
(37, 0, 554, 1, 1, 'LV 37', 275000, 2048.47, -1940.82, 13.4383, 89.9542, NULL, NULL, NULL, NULL, 0, NULL, 18, 99.65, 0, 1, 100, 0, 0, 0, 0, NULL, 0, NULL, 0);

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
-- Indexes for table `bars`
--
ALTER TABLE `bars`
  ADD PRIMARY KEY (`id`);

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
-- Indexes for table `billboards`
--
ALTER TABLE `billboards`
  ADD PRIMARY KEY (`bbID`);

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
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cs_locations`
--
ALTER TABLE `cs_locations`
  ADD PRIMARY KEY (`csID`);

--
-- Indexes for table `event_attachments`
--
ALTER TABLE `event_attachments`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_event_attach` (`quest_key`,`slot`);

--
-- Indexes for table `event_checkpoints`
--
ALTER TABLE `event_checkpoints`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_event_cp` (`quest_key`,`cp_index`);

--
-- Indexes for table `event_config`
--
ALTER TABLE `event_config`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `event_facts`
--
ALTER TABLE `event_facts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_event_fact` (`holiday`);

--
-- Indexes for table `event_npcs`
--
ALTER TABLE `event_npcs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_event_npcs` (`quest_key`);

--
-- Indexes for table `event_npc_talks`
--
ALTER TABLE `event_npc_talks`
  ADD PRIMARY KEY (`pID`,`npc_id`);

--
-- Indexes for table `event_objects`
--
ALTER TABLE `event_objects`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_event_objects` (`quest_key`);

--
-- Indexes for table `event_pickups`
--
ALTER TABLE `event_pickups`
  ADD PRIMARY KEY (`pID`,`object_id`);

--
-- Indexes for table `event_progress`
--
ALTER TABLE `event_progress`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_event_progress` (`pID`,`quest_key`);

--
-- Indexes for table `event_quests`
--
ALTER TABLE `event_quests`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_event_quest` (`quest_key`);

--
-- Indexes for table `event_skins`
--
ALTER TABLE `event_skins`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_event_skin` (`skin`);

--
-- Indexes for table `event_zones`
--
ALTER TABLE `event_zones`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_event_zones` (`quest_key`);

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
-- Indexes for table `forests`
--
ALTER TABLE `forests`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `fuelstations`
--
ALTER TABLE `fuelstations`
  ADD PRIMARY KEY (`id`);

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
-- Indexes for table `ips`
--
ALTER TABLE `ips`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_ip_player` (`ip`,`playerName`);

--
-- Indexes for table `locations_admin`
--
ALTER TABLE `locations_admin`
  ADD PRIMARY KEY (`locID`),
  ADD UNIQUE KEY `uq_location_name` (`locName`);

--
-- Indexes for table `market`
--
ALTER TABLE `market`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `pacate`
--
ALTER TABLE `pacate`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `player_week` (`pID`,`weekNo`);

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
-- Indexes for table `quests`
--
ALTER TABLE `quests`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `player_week_slot` (`pID`,`weekNo`,`slot`);

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
  MODIFY `amoID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `arm_equipment`
--
ALTER TABLE `arm_equipment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `atms`
--
ALTER TABLE `atms`
  MODIFY `atmID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `bans`
--
ALTER TABLE `bans`
  MODIFY `banID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `bars`
--
ALTER TABLE `bars`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `basket_spawns`
--
ALTER TABLE `basket_spawns`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT for table `billboards`
--
ALTER TABLE `billboards`
  MODIFY `bbID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `bin`
--
ALTER TABLE `bin`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `businesses`
--
ALTER TABLE `businesses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `clothstores`
--
ALTER TABLE `clothstores`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `cs_locations`
--
ALTER TABLE `cs_locations`
  MODIFY `csID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `event_attachments`
--
ALTER TABLE `event_attachments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `event_checkpoints`
--
ALTER TABLE `event_checkpoints`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `event_facts`
--
ALTER TABLE `event_facts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT for table `event_npcs`
--
ALTER TABLE `event_npcs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `event_objects`
--
ALTER TABLE `event_objects`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `event_progress`
--
ALTER TABLE `event_progress`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `event_quests`
--
ALTER TABLE `event_quests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `event_skins`
--
ALTER TABLE `event_skins`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `event_zones`
--
ALTER TABLE `event_zones`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

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
  MODIFY `ffID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `forests`
--
ALTER TABLE `forests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `fuelstations`
--
ALTER TABLE `fuelstations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

--
-- AUTO_INCREMENT for table `houses_animals`
--
ALTER TABLE `houses_animals`
  MODIFY `aID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `houses_tree`
--
ALTER TABLE `houses_tree`
  MODIFY `treeId` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `ips`
--
ALTER TABLE `ips`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=68;

--
-- AUTO_INCREMENT for table `locations_admin`
--
ALTER TABLE `locations_admin`
  MODIFY `locID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=914;

--
-- AUTO_INCREMENT for table `market`
--
ALTER TABLE `market`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `pacate`
--
ALTER TABLE `pacate`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `players`
--
ALTER TABLE `players`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `player_skins`
--
ALTER TABLE `player_skins`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `president_votes`
--
ALTER TABLE `president_votes`
  MODIFY `vID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `quests`
--
ALTER TABLE `quests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `races`
--
ALTER TABLE `races`
  MODIFY `rID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `reports`
--
ALTER TABLE `reports`
  MODIFY `repID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `rulote_personale`
--
ALTER TABLE `rulote_personale`
  MODIFY `rID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `server_setup`
--
ALTER TABLE `server_setup`
  MODIFY `ssId` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9181;

--
-- AUTO_INCREMENT for table `shops`
--
ALTER TABLE `shops`
  MODIFY `shopID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `turfs`
--
ALTER TABLE `turfs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `ucp_factapplications`
--
ALTER TABLE `ucp_factapplications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `vehicles_faction`
--
ALTER TABLE `vehicles_faction`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=125;

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
