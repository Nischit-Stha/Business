-- Auto-generated from Current file.xlsx
-- Generated at: 2026-04-19 05:01:54 UTC
-- This script imports weekly collection data and syncs vehicles/customers.

BEGIN;

CREATE TABLE IF NOT EXISTS public.weekly_collection_ledger (
  id BIGSERIAL PRIMARY KEY,
  plate TEXT NOT NULL,
  make TEXT,
  model TEXT,
  color TEXT,
  customer_name TEXT NOT NULL,
  expected_weekly_credits NUMERIC NOT NULL DEFAULT 0,
  pending_amount NUMERIC NOT NULL DEFAULT 0,
  received_amount NUMERIC NOT NULL DEFAULT 0,
  due_day TEXT,
  source_file TEXT NOT NULL DEFAULT 'Current file.xlsx',
  imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS weekly_collection_ledger_plate_idx ON public.weekly_collection_ledger (plate);
CREATE INDEX IF NOT EXISTS weekly_collection_ledger_customer_idx ON public.weekly_collection_ledger (customer_name);
CREATE INDEX IF NOT EXISTS weekly_collection_ledger_imported_at_idx ON public.weekly_collection_ledger (imported_at DESC);

ALTER TABLE public.weekly_collection_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS weekly_collection_ledger_admin_only ON public.weekly_collection_ledger;
CREATE POLICY weekly_collection_ledger_admin_only
ON public.weekly_collection_ledger
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE TEMP TABLE tmp_weekly_import (
  plate TEXT,
  make TEXT,
  model TEXT,
  color TEXT,
  customer_name TEXT,
  expected_weekly_credits NUMERIC,
  pending_amount NUMERIC,
  received_amount NUMERIC,
  due_day TEXT
);

INSERT INTO tmp_weekly_import (plate, make, model, color, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day)
VALUES
  ('1CJ2FX', 'MITSUB', 'MIRAGE', 'SIL', '', 0.0, 0.0, 0.0, 'NIL'),
  ('1EJ6SC', 'SUZUKI', 'ALTO', 'WHI', 'Balraj S Gill', 150.0, 150.0, 0.0, 'Thursday'),
  ('1GS7IB', 'TOYOTA', 'YARIS', 'BLK', 'Naga V S Eranki', 150.0, 0.0, 300.0, 'Sunday'),
  ('1HH9AL', 'TOYOTA', 'COROLL', 'RED', 'Amogh Kale', 180.0, 360.0, 0.0, 'Friday'),
  ('1PU1ZG', 'HYNDAI', 'I20', 'RED', 'Celine', 160.0, 160.0, 0.0, 'Wednesday'),
  ('1PY5TL', 'HYNDAI', 'ELANTR', 'WHI', 'Hemang Jain', 240.0, 720.0, 0.0, 'Tuesday'),
  ('1QI3UK', 'KIA', 'CARNIV', '', 'Arslan Ahmed', 450.0, 0.0, 950.0, 'NIL'),
  ('1RI1XL', 'MITSUB', 'OUTLAN', 'WHI', 'Achieng D Gurec', 300.0, 3800.0, 0.0, 'Wednesday'),
  ('1TL4YZ', 'NISSAN', 'XTRAIL', 'WHI', 'Deng Muor Muor', 250.0, 250.0, 0.0, 'Friday'),
  ('1UO5AW', 'NISSAN', 'MICRA', 'SIL', 'Gurjit Kaur', 150.0, 0.0, 150.0, 'Sunday'),
  ('1VZ4RP', 'LDV', 'VAN', 'WHI', 'Prashant Chawla', 80.0, 1040.0, 0.0, 'NIL'),
  ('1WQ8LV', 'KIA', 'CARNIV', 'WHI', 'Divyang N Sorathiya', 450.0, 450.0, 0.0, 'NIL'),
  ('1WR9VY', 'TOYOTA', 'YARIS', 'GREY', 'Harshavardhan R Rikkala', 160.0, 0.0, 320.0, 'Sunday'),
  ('1WT5CK', 'TOYOTA', 'COROLL', 'WHI', 'Ajit Rattu Des Raj', 150.0, 0.0, 150.0, 'Tuesday'),
  ('1WW4JG', 'TOYOTA', 'YARIS', 'ORG', 'Rahul Kamboj', 180.0, 0.0, 180.0, 'Monday'),
  ('1XE9WN', 'SUZUKI', 'SWIFT', 'WHI', 'Aukuso Doris Susan', 200.0, 200.0, 0.0, 'NIL'),
  ('1XE9WO', 'CHERY', 'OMODA5', 'GRN', '', 0.0, 0.0, 0.0, 'NIL'),
  ('1XE9WP', 'CHERY', 'OMODA5', 'WHI', '', 0.0, 0.0, 0.0, 'NIL'),
  ('1XE9XA', 'KIA', 'CARNIV', 'GRY', 'Gurjinder Singh', 400.0, 1600.0, 400.0, 'Monday'),
  ('1XG4NG', 'LDV', 'D90', 'WHI', 'Agnes Ale', 400.0, 2800.0, 0.0, 'Thursday'),
  ('1XG5AU', 'LDV', 'D90', 'WHI', '', 0.0, 0.0, 0.0, 'NIL'),
  ('1XJ1WD', 'CHERY', 'OMODA5', 'SIL', 'Maria K Faamita', 300.0, 2300.0, 0.0, 'Saturday'),
  ('1XJ1WL', 'KIA', 'RIO', 'WHI', 'Shweta Armani', 220.0, 0.0, 1000.0, 'Sunday'),
  ('1XJ2AO', 'HAVAL', 'JOLION', 'GRN', 'Rink Raja', 300.0, 900.0, 0.0, 'Thursday'),
  ('1XM4FN', 'HYNDAI', 'I20', 'SIL', 'Sukhraj Sahi', 140.0, 0.0, 140.0, 'Tuesday'),
  ('1XS9BJ', 'LDV', 'VAN', 'DELIVE', 'Ali Mansuri', 300.0, 0.0, 0.0, 'Thursday'),
  ('1XS9BW', 'LDV', 'DC UTE/T60', 'BLK', 'Lino M Tanuvasa', 360.0, 720.0, 0.0, 'Monday'),
  ('1XW4IV', 'KIA', 'SELTOS', 'BLU', 'Nikhil', 0.0, 500.0, 0.0, 'NIL'),
  ('1XX9BX', 'TOYOTA', 'CAMRY', 'WHI', 'Rajat Tulani', 200.0, 4000.0, 0.0, 'NIL'),
  ('1YD1UJ', 'HAVAL', 'JOLION', 'WHI', 'Maria K Faamita', 250.0, 4400.0, 0.0, 'Wednesday'),
  ('1YJ6XJ', 'HAVAL', 'JOLION', 'WHI', 'Khatija Possum', 340.0, 10918.0, 0.0, 'NIL'),
  ('1YT4OQ', 'TOYOTA', 'CAMRY', 'WHI', 'Laat Mathiang', 320.0, 0.0, 320.0, 'Monday'),
  ('1ZP4DJ', 'L ROV', 'DISCOV', 'GRY', 'Agnes Ale', 270.0, 0.0, 0.0, 'Wednesday'),
  ('2AI9XE', 'VOLKS', 'POLO', 'WHI', 'Jaswant Singh', 210.0, 1260.0, 210.0, 'Monday'),
  ('2AN7RR', 'TOYOTA', 'COROLL', 'SIL', '', 240.0, 0.0, 480.0, 'Sunday'),
  ('2AU6PS', 'TOYOTA', 'CAMRY', 'SIL', 'Tong G Deng', 275.0, 0.0, 275.0, 'Monday'),
  ('2BA8JF', 'KIA', 'STONIC', 'YLW', 'Rohan Taneja', 200.0, 0.0, 200.0, 'Monday'),
  ('2BB9GZ', 'NISSAN', 'SERENA', 'BLU', '', 0.0, 0.0, 150.0, 'NIL'),
  ('2BH3JE', 'TOYOTA', 'KLUGER', 'WHI', 'Kamaledeen Haron', 400.0, 1830.0, 700.0, 'Monday'),
  ('2BH3KZ', 'TOYOTA', 'FORTUN', 'BLK', 'Rajvansh Singh', 400.0, 0.0, 400.0, 'Monday'),
  ('2BK9GY', 'KIA', 'CARNIV', 'WHI', 'Dominic Y Giel', 420.0, 2130.0, 420.0, 'Tuesday'),
  ('2BK9GZ', 'KIA', 'CARNIV', 'BLU', 'Balraj S Gill', 430.0, 0.0, 430.0, 'Wednesday'),
  ('2BL9BQ', 'MITSUB', 'TRITON', 'WHI', 'Luke Charles', 425.0, 0.0, 425.0, 'Thursday'),
  ('2BL9DS', 'HAVAL', 'JOLION', 'WHI', 'Bagic M Majoak', 330.0, 330.0, 0.0, 'Tuesday'),
  ('2BL9DT', 'HAVAL', 'H6', 'WHI', 'Iqbal Singh', 300.0, 0.0, 300.0, 'Wednesday'),
  ('2BO5VU', 'HAVAL', 'JOLION', 'WHI', 'Akoi M Mabing - Abuk Daughter', 240.0, 0.0, 240.0, 'Friday'),
  ('2BQ4ZY', 'NISSAN', 'SERENA', 'WHI', 'Aukuso Doris Susan', 250.0, 0.0, 0.0, 'Thursday'),
  ('2BQ5FB', 'NISSAN', 'SERENA', 'WHI', '', 0.0, 0.0, 0.0, 'Tuesday'),
  ('2BR5PP', 'HAVAL', 'JOLION', 'WHI', 'Michelle K Ndunda', 300.0, 0.0, 300.0, 'Monday'),
  ('2BV6GU', 'G WALL', 'CANNON', 'WHI', '', 0.0, 0.0, 0.0, 'NIL'),
  ('2BV6GV', 'HAVAL', 'H6', 'WHI', 'Raj K Leel', 280.0, 0.0, 280.0, 'Friday'),
  ('2BV6GW', 'HAVAL', 'JOLION', 'WHI', 'Manyok M Lual', 270.0, 0.0, 270.0, 'Wednesday'),
  ('2BV6HL', 'HAVAL', 'JOLION', 'WHI', 'Nor-eldin M Yassin', 275.0, 1100.0, 0.0, 'Thursday'),
  ('2BV6HM', 'HAVAL', 'JOLION', 'WHI', 'Jaspreet Singh', 300.0, 0.0, 300.0, 'Wednesday'),
  ('2BV6HN', 'HAVAL', 'JOLION', 'WHI', 'Dadafo A Wariyo', 290.0, 580.0, 290.0, 'Tuesday'),
  ('2BV6HO', 'HAVAL', 'JOLION', 'WHI', 'Osman Ibrahim', 270.0, 0.0, 270.0, 'Wednesday'),
  ('2BV6HP', 'HAVAL', 'JOLION', 'WHI', 'Baharudin Ahmad Ibrahim', 280.0, 840.0, 0.0, 'Saturday'),
  ('2BV6HQ', 'HAVAL', 'JOLION', 'WHI', 'Fahad D Jelle', 275.0, 1375.0, 0.0, 'Tuesday'),
  ('2BV6HR', 'HAVAL', 'JOLION', 'WHI', 'Khalida Aduk', 310.0, 0.0, 310.0, 'Tuesday'),
  ('2BV6HS', 'HAVAL', 'JOLION', 'WHI', 'Deng D Meen', 290.0, 2950.0, 1280.0, 'Thursday'),
  ('2BW3WN', 'KIA', 'CARNIV', 'WHI', 'Thanh T Nguyen', 0.0, 0.0, 0.0, 'NIL'),
  ('2BW3WO', 'KIA', 'CARNIV', 'GRY', 'Anon A D Maywin', 430.0, 0.0, 430.0, 'Saturday'),
  ('2BW3WP', 'KIA', 'CARNIV', 'GRY', 'Divyang N Sorathiya', 450.0, 450.0, 0.0, 'Wednesday'),
  ('2BW8CU', 'KIA', 'CARNIV', 'WHI', 'Duc Anh Le', 490.0, 980.0, 0.0, 'Monday'),
  ('2BX7SK', 'HAVAL', 'H6', 'WHI', 'Joseph D Makaram', 275.0, 275.0, 0.0, 'Friday'),
  ('2BX7SL', 'HAVAL', 'H6', 'WHI', 'Akash S Swardekar', 280.0, 1030.0, 0.0, 'Sunday'),
  ('2BX7SM', 'HAVAL', 'H6', 'WHI', 'Ahmed Hajole', 290.0, 1450.0, 290.0, 'Monday'),
  ('2BX7SN', 'HAVAL', 'H6', 'WHI', 'Makol M Mukuei', 300.0, 300.0, 300.0, 'Monday'),
  ('2BX8CW', 'KIA', 'CARNIV', 'WHI', 'Salih I Iyay', 430.0, 0.0, 430.0, 'Monday'),
  ('2BZ1ZA', 'KIA', 'CARNIV', 'GRY', 'Madit M Thomas', 440.0, 440.0, 440.0, 'Tuesday'),
  ('2BZ1ZB', 'KIA', 'CARNIV', 'GRY', 'Divyang N Sorathiya', 450.0, 450.0, 0.0, 'Friday'),
  ('2CA3YN', 'TOYOTA', 'RAV', 'WHI', 'Liban Hassan', 330.0, 1320.0, 0.0, 'Tuesday'),
  ('2CB6KP', 'KIA', 'CARNIV', 'WHI', 'Panchol G Ayuol', 450.0, 4300.0, 450.0, 'Tuesday'),
  ('2CB6KQ', 'KIA', 'CARNIV', 'GRY', '', 0.0, 0.0, 0.0, 'NIL'),
  ('2CB6KR', 'MAHIND', 'XUV700', 'SIL', 'Sandeep Kumar', 150.0, 300.0, 0.0, 'NIL'),
  ('2CE8VE', 'HAVAL', 'JOLION', 'WHI', 'Chetan Paruchuri', 280.0, 0.0, 280.0, 'Monday'),
  ('2CH1MD', 'HONDA', 'CITY', 'SIL', 'Pavan Kaudare', 200.0, 0.0, 200.0, 'Monday'),
  ('2CJ5ZH', 'TOYOTA', 'RAV', 'WHI', 'Harpreet Singh', 400.0, 400.0, 400.0, 'Friday'),
  ('2CO4RZ', 'TOYOTA', 'CAMRY', 'WHI', 'Abdirahman Sheikh Mohamed', 300.0, 620.0, 0.0, 'Friday'),
  ('2CO6PT', 'HONDA', '', 'MAR', '', 0.0, 0.0, 0.0, 'NIL'),
  ('2CO7US', 'KIA', 'CARNIV', 'SIL', '', 0.0, 1840.0, 0.0, 'Thursday'),
  ('2CO7UT', 'KIA', 'CARNIV', 'BLU', 'Mayen D V Upardit', 430.0, 920.0, 0.0, 'Thursday'),
  ('2CO7UU', 'KIA', 'CARNIV', 'WHI', '', 0.0, 0.0, 0.0, 'NIL'),
  ('2CO7UV', 'KIA', 'CARNIV', 'WHI', 'Makot A Wol', 400.0, 800.0, 400.0, 'Tuesday'),
  ('2CR7RD', 'TOYOTA', 'CAMRY', 'WHI', 'Mehfil Singh', 400.0, 400.0, 0.0, 'Friday'),
  ('2CR7RE', 'TOYOTA', 'CAMRY', 'WHI', 'Manyher Majok Derder', 320.0, 4780.0, 0.0, 'Friday'),
  ('2CR7RF', 'TOYOTA', 'CAMRY', 'WHI', 'Adbi G Dekebo', 300.0, 0.0, 300.0, 'Wednesday'),
  ('2CR7RG', 'TOYOTA', 'CAMRY', 'WHI', 'Mohammad Namani', 300.0, 0.0, 300.0, 'Tuesday'),
  ('2CR7RH', 'TOYOTA', 'CAMRY', 'WHI', 'Haong H Nyugen', 350.0, 1050.0, 0.0, 'Friday'),
  ('2DG5UY', 'KIA', 'CARNIV', 'GREY', 'Meriyem A Hussein', 500.0, 300.0, 0.0, 'Thursday'),
  ('2DG5UZ', 'KIA', 'CARNIV', 'GREY', 'Angelo M M Kamiic', 440.0, 2200.0, 0.0, 'Tuesday'),
  ('2DG5VA', 'KIA', 'CARNIV', 'GREY', 'Divyang N Sorathiya', 450.0, 450.0, 0.0, 'Monday'),
  ('2DG5VD', 'KIA', 'CARNIV', 'GREY', '', 0.0, 0.0, 0.0, 'Friday'),
  ('2DH6DL', 'KIA', 'CARNIV', 'GREY', 'John M Manyang', 460.0, 0.0, 460.0, 'Thursday'),
  ('2DH6DM', 'KIA', 'CARNIV', 'WHI', 'Hekma A Amiyo/nuradin Osman', 400.0, 0.0, 0.0, 'Friday'),
  ('2DH6DN', 'CHERY', 'TIGGO 8', 'WHI', 'Koshin R Hassan', 410.0, 1640.0, 2800.0, 'Wednesday'),
  ('2DI2PZ', 'CHERY', 'TIGGO 4', 'RED', 'Madol C D', 250.0, 2210.0, 0.0, 'Wednesday'),
  ('2DI2QA', 'CHERY', 'TIGGO 4', 'RED', 'Mary A Abraham Wech', 250.0, 500.0, 800.0, 'Wednesday'),
  ('2DI2QB', 'CHERY', 'TIGGO 4', 'RED', 'Dimpho Mony Amane', 270.0, 680.0, 400.0, 'Saturday'),
  ('2DI8CE', 'GREAT WALL', 'UTIL', 'GREY', 'Clifton A Schuster', 420.0, 220.0, 1020.0, 'Thursday'),
  ('2DI8CF', 'GREAT WALL', 'UTIL', 'BLK', 'Jacques S Fender', 375.0, 1525.0, 1200.0, 'Friday'),
  ('2DI8CG', 'GREAT WALL/HAVAL', 'WAGON', 'GREY', 'Yousif Mohamed', 310.0, 0.0, 310.0, 'Wednesday'),
  ('2DI8FI', 'GREAT WALL', 'WAGON', 'BLK', 'Amir Y Adem', 310.0, 310.0, 310.0, 'Monday'),
  ('2DJ7KV', 'HONDA', 'CITY', 'SIL', 'Yolanda Franklin/bill', 0.0, 0.0, 1100.0, 'NIL'),
  ('2DK6TD', 'KIA', 'CARNIV', 'WHI', 'Khalid Ashac', 440.0, 880.0, 0.0, 'Monday'),
  ('2DK6TP', 'CHERY', 'TIGGO 8', 'WHI', 'Malok M Mayuom', 430.0, 3525.0, 430.0, 'Wednesday'),
  ('2DK6TQ', 'CHERY', 'TIGGO 8', 'WHI', 'Nicolas Marker', 430.0, 4168.57, 0.0, 'Wednesday'),
  ('2DM8FM', 'SUBARU', 'XV', 'SIL', 'Kristina M Isaia', 190.0, 440.0, 0.0, 'Saturday'),
  ('2DN2IL', 'KIA', 'CARNIV', 'WHI', 'Mayen M Mayen', 420.0, 420.0, 840.0, 'Monday'),
  ('2DN2IQ', 'KIA', 'CARNIV', 'WHI', 'Divyang N Sorathiya', 450.0, 450.0, 0.0, 'Friday'),
  ('2DN2IR', 'KIA', 'CARNIV', 'WHI', 'Manyang Koch', 0.0, 780.0, 0.0, 'Saturday'),
  ('2DN2IS', 'KIA', 'CARNIV', 'WHI', 'Matoch Gak', 430.0, 430.0, 0.0, 'Friday'),
  ('2DN7YS', 'CHERY', 'TIGGO 8', 'GRN', 'Maytham M Kareem', 400.0, 0.0, 400.0, 'Wednesday'),
  ('2DN7YT', 'KIA', 'CARNIV', 'GREY', 'Angelo M Anyang', 440.0, 0.0, 440.0, 'Thursday'),
  ('2DN7YU', 'KIA', 'CARNIV', 'WHI', '', 0.0, 0.0, 0.0, 'NIL'),
  ('2DS7BG', 'HONDA', 'WAGON', 'SIL', 'Hekma A Amiyo/nuradin Osman', 165.0, 1650.0, 0.0, 'Tuesday'),
  ('2DT5PT', 'MERCEDES', 'E350', 'SIL', 'Kaan Ozongan', 285.0, 0.0, 285.0, 'Friday'),
  ('2DW8BS', 'TOYOTA', 'CAMRY', 'WHI', 'John Madheng', 310.0, 0.0, 310.0, 'Wednesday'),
  ('2DX8UR', 'KIA', 'CARNIV', 'WHI', '', 0.0, 0.0, 0.0, 'NIL'),
  ('2DX8US', 'CHERY', 'TIGGO 4', 'GREY', 'Malual Malok', 270.0, 0.0, 0.0, 'Sunday'),
  ('2EG5NU', 'SUBARU', '', 'WHI', 'Piara Singh', 0.0, 4000.0, 0.0, 'NIL'),
  ('2EI2EH', 'TOYOTA', 'CAMRY', 'WHI', 'Abdiwali Ibrahim Ali', 320.0, 0.0, 320.0, 'Wednesday'),
  ('2EI2EI', 'TOYOTA', 'CAMRY', 'WHI', 'Bashir Mohamed Mohamud', 325.0, 0.0, 325.0, 'Wednesday'),
  ('2EK5QK', 'TOYOTA', '', 'BLU', 'Aukuso Doris Susan', 0.0, 0.0, 0.0, 'NIL'),
  ('2EM2JB', 'KIA', 'CARNIV', 'WHI', 'Bakhit Abaker Hussain Asad', 450.0, 0.0, 450.0, 'Friday'),
  ('2EM2JC', 'KIA', 'CARNIV', 'GREY', 'Ater M M Zorgang', 450.0, 450.0, 900.0, 'Friday'),
  ('2EM2JI', 'CHERY', 'TIGGO 7', 'GREY', 'Joseph F B Bulabek', 340.0, 0.0, 840.0, 'Monday'),
  ('2EM2JJ', 'KIA', 'CARNIV', 'GREY', 'Abdurehim O Ibris Tluk', 430.0, 450.0, 0.0, 'Wednesday'),
  ('2EM2JM', 'KIA', 'CARNIV', 'GREY', 'Divyang N Sorathiya', 450.0, 430.0, 0.0, 'Friday'),
  ('2EM2JN', 'KIA', 'CARNIV', 'GREY', 'Ahmed Yousif Mohamed', 450.0, 0.0, 450.0, 'Tuesday'),
  ('2EM2JO', 'KIA', 'CARNIV', 'BLUE', 'Abraham Mawut', 430.0, 430.0, 430.0, 'Thursday'),
  ('2EO3CQ', 'GREAT WALL', 'H6', 'CREAM', 'Nabil Adam', 330.0, 0.0, 330.0, 'Thursday'),
  ('2EO3CR', 'GREAT WALL', 'H6', 'BLK', 'Nouman Ikram', 330.0, 810.0, 0.0, 'Sunday'),
  ('2EO3CS', 'GREAT WALL', 'H6', 'CREAM', 'Eliza Magol', 330.0, 4410.0, 0.0, 'Tuesday'),
  ('2EO3CT', 'GREAT WALL', 'H6', 'BLK', 'Nyok A A Alor', 330.0, 0.0, 330.0, 'Tuesday'),
  ('2ER7FC', 'CHERY', 'TIGGO 4', 'SIL', 'Luc V Thai', 260.0, 0.0, 0.0, 'Sunday'),
  ('2ER7FD', 'KIA', 'CARNIV', 'WHI', 'Abuk M A Atem', 450.0, 450.0, 0.0, 'Monday'),
  ('2ER7FE', 'KIA', 'CARNIV', 'WHI', 'Ajak Keer', 430.0, 0.0, 430.0, 'Friday'),
  ('BBO590', 'LEXUS', 'ES300H', 'SIL', 'Anastacia Gouros/bill', 0.0, 900.0, 1800.0, 'Monday'),
  ('CCF931', 'TOYOTA', 'CAMRY', 'WHI', '', 0.0, 0.0, 0.0, 'NIL'),
  ('CDH145', 'MERCEDES', '', 'WHI', 'Ishvinder Singh', 500.0, 0.0, 500.0, 'Friday'),
  ('CWA104', 'G WALL', 'CANNON', 'WHI', 'Steven Wilson/alysha M Kapac', 355.0, 0.0, 0.0, 'Friday'),
  ('CXN779', 'HAVAL', 'JOLION', 'WHI', 'David K Poundak', 270.0, 270.0, 270.0, 'Wednesday'),
  ('DHC138', 'LEXUS', 'ES300H', 'BLK', 'Manroop Singh', 475.0, 0.0, 950.0, 'Wednesday'),
  ('DHZ480', 'LEXUS', 'ES300H', 'BLK', 'Rachit Dhiman', 480.0, 0.0, 480.0, 'Monday'),
  ('DIT729', 'BMW', 'M SERIES', 'WHI', 'Chol J Majok Pach', 480.0, 480.0, 0.0, 'Friday'),
  ('DTQ530', 'BMW', '', 'WHI', 'Aman Bhasin', 0.0, 0.0, 0.0, 'NIL'),
  ('DZK262', 'LEXUS', 'ES300H', 'BLK', 'Mandeep Tanda', 500.0, 0.0, 500.0, 'Sunday'),
  ('WFW527', 'NISSAN', 'MICRA', 'GRN', 'Asha Rani', 150.0, 150.0, 0.0, 'Monday'),
  ('YZW904', 'NISSAN', 'MICRA', 'BLU', 'Aukuso Doris Susan', 0.0, 0.0, 0.0, 'NIL'),
  ('ZHU773', 'NISSAN', '', 'ORG', 'Aukuso Taulaga', 170.0, 170.0, 0.0, 'Tuesday');

INSERT INTO public.weekly_collection_ledger (
  plate, make, model, color, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day
)
SELECT
  plate, make, model, color, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day
FROM tmp_weekly_import
ORDER BY plate, customer_name;

-- Sync vehicles table from latest import
UPDATE public.vehicles v
SET
  make = COALESCE(NULLIF(t.make, ''), v.make),
  model = COALESCE(NULLIF(t.model, ''), v.model),
  color = COALESCE(NULLIF(t.color, ''), v.color),
  name = COALESCE(NULLIF(v.name, ''), CONCAT_WS(' ', NULLIF(t.make, ''), NULLIF(t.model, ''))),
  updated_at = NOW()
FROM tmp_weekly_import t
WHERE UPPER(COALESCE(v.plate, '')) = UPPER(COALESCE(t.plate, ''));

INSERT INTO public.vehicles (name, make, model, plate, color, status, created_at, updated_at)
SELECT
  CONCAT_WS(' ', NULLIF(t.make, ''), NULLIF(t.model, '')) AS name,
  NULLIF(t.make, ''),
  NULLIF(t.model, ''),
  NULLIF(t.plate, ''),
  NULLIF(t.color, ''),
  'rented',
  NOW(),
  NOW()
FROM tmp_weekly_import t
WHERE NULLIF(t.plate, '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.vehicles v
    WHERE UPPER(COALESCE(v.plate, '')) = UPPER(COALESCE(t.plate, ''))
  );

-- Sync customers table (best effort without phone/email)
UPDATE public.customers c
SET
  current_vehicle = COALESCE(NULLIF(t.plate, ''), c.current_vehicle),
  notes = CONCAT_WS(' | ', NULLIF(c.notes, ''), CONCAT('Weekly due: ', COALESCE(NULLIF(t.due_day, ''), 'NIL'))),
  last_booking_at = COALESCE(c.last_booking_at, NOW()),
  updated_at = NOW()
FROM tmp_weekly_import t
WHERE LOWER(COALESCE(c.full_name, '')) = LOWER(COALESCE(t.customer_name, ''))
  AND c.full_name IS NOT NULL;

INSERT INTO public.customers (full_name, current_vehicle, notes, last_booking_at, created_at, updated_at)
SELECT
  t.customer_name,
  NULLIF(t.plate, ''),
  CONCAT('Weekly due: ', COALESCE(NULLIF(t.due_day, ''), 'NIL')),
  NOW(),
  NOW(),
  NOW()
FROM tmp_weekly_import t
WHERE NULLIF(t.customer_name, '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.customers c
    WHERE LOWER(COALESCE(c.full_name, '')) = LOWER(COALESCE(t.customer_name, ''))
  );

DROP TABLE IF EXISTS tmp_weekly_import;

COMMIT;

-- Verification
-- SELECT COUNT(*) AS imported_rows FROM public.weekly_collection_ledger WHERE source_file = 'Current file.xlsx';
-- SELECT plate, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day FROM public.weekly_collection_ledger ORDER BY plate, customer_name LIMIT 50;